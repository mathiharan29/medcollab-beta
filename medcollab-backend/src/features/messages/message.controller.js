/**
 * MESSAGE CONTROLLER
 *
 * Critical flow for sendMessage:
 * 1. Validate channel access
 * 2. Save message to MongoDB (persistence first)
 * 3. Emit socket event (broadcast to channel room)
 * 4. Update channel.lastMessage (sidebar preview)
 * 5. Send notifications (FCM + in-app inbox)
 *
 * Steps 3-5 happen AFTER the HTTP response is sent using res.json() +
 * fire-and-forget. This keeps message send latency under 100ms even
 * when FCM is slow.
 */

const Message = require('./message.model');
const Channel = require('../channels/channel.model');
const Space = require('../spaces/space.model');
const User = require('../users/user.model');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const {
  resolveChannelAccess,
  assertMessageInChannel,
} = require('../../utils/channelAccess');
const { emitNewMessage, emitMessageUpdated, emitMessageDeleted } = require('../../socket');
const { notifyNewMessage, notifyMention } = require('../../services/notification.service');
const { MESSAGE_TYPES, MESSAGE_PRIORITY, PAGINATION, CHANNEL_TYPES } = require('../../constants');
const logger = require('../../utils/logger');

const messagePreviewText = (message) =>
  message.content?.text?.slice(0, 200) ||
  (message.type === MESSAGE_TYPES.IMAGE || message.type === MESSAGE_TYPES.ECG
    ? '📷 Photo'
    : message.type === MESSAGE_TYPES.VIDEO
      ? '🎥 Video'
      : message.type === MESSAGE_TYPES.DOCUMENT
        ? '📎 Document'
        : message.type === MESSAGE_TYPES.HANDOFF
          ? '🔄 Handoff'
          : message.type === MESSAGE_TYPES.ALERT
            ? '⚠️ Alert'
            : null);

/**
 * GET /api/channels/:channelId/messages
 * Cursor-based paginated message fetch — newest first, returned ascending
 */
const getMessages = asyncHandler(async (req, res) => {
  const access = await resolveChannelAccess(req, res);
  if (!access) return;

  const limit = Math.min(parseInt(req.query.limit) || PAGINATION.MESSAGES_LIMIT, 100);
  const before = req.query.before;

  const query = {
    channelId: req.params.channelId,
    threadId: null,          // Root messages only — threads fetched separately
    isDeleted: false,
  };

  // Cursor: fetch messages older than the given messageId
  if (before) query._id = { $lt: before };

  let messages = await Message.find(query)
    .sort({ _id: -1 })          // Newest first from DB
    .limit(limit + 1)           // Fetch one extra to know if there's more
    .populate('senderId', 'name displayTitle role avatarUrl')
    .lean();

  const hasMore = messages.length > limit;
  if (hasMore) messages.pop();  // Remove the extra

  // Populate DM read-receipt names so clients don't show "Colleague"
  if (access.channel.type === CHANNEL_TYPES.DIRECT && messages.length > 0) {
    messages = await Message.populate(messages, {
      path: 'readBy.userId',
      select: 'name displayTitle role avatarUrl',
    });
  }

  // Return in ascending order (oldest → newest) for natural chat rendering
  messages.reverse();

  return respond.ok(res, 'Messages fetched', { messages, hasMore });
});

/**
 * POST /api/channels/:channelId/messages
 * Send a message to a channel
 */
const sendMessage = asyncHandler(async (req, res) => {
  const access = await resolveChannelAccess(req, res);
  if (!access) return;
  const { channel, space } = access;

  // Enforce announcements-only restriction
  if (channel.onlyAdminsCanPost && space && !space.isAdmin(req.user._id)) {
    return respond.forbidden(res, 'Only admins can post in this channel');
  }

  const {
    type = MESSAGE_TYPES.TEXT,
    content: rawContent,
    priority = MESSAGE_PRIORITY.NORMAL,
    threadId,
    mentions,
    replyToId,
  } = req.body;

  // Persist trimmed text so route length checks match Mongo maxlength.
  const content =
    rawContent && typeof rawContent.text === 'string'
      ? { ...rawContent, text: rawContent.text.trim() }
      : rawContent;

  // Validate media URLs point to trusted domains or this server's uploads.
  if (content?.mediaUrl) {
    const allowedHosts = ['res.cloudinary.com', 'cloudinary.com'];
    const rawMediaUrl = String(content.mediaUrl);
    if (!rawMediaUrl.startsWith('/uploads/')) {
      try {
        const parsed = new URL(rawMediaUrl);
        const host = parsed.hostname.toLowerCase();
        const ownHosts = new Set(
          [req.hostname, req.get('host')?.split(':')[0]]
            .filter(Boolean)
            .map((value) => value.toLowerCase())
        );
        if (process.env.API_BASE_URL) {
          try {
            ownHosts.add(new URL(process.env.API_BASE_URL).hostname.toLowerCase());
          } catch {
            // Invalid configuration is handled by startup validation.
          }
        }
        const isCloudinary =
          parsed.protocol === 'https:' &&
          allowedHosts.some((allowed) => host === allowed || host.endsWith('.' + allowed));
        const isLocalUpload =
          (parsed.protocol === 'http:' || parsed.protocol === 'https:') &&
          parsed.pathname.startsWith('/uploads/') &&
          (host === 'localhost' || host === '127.0.0.1' || ownHosts.has(host));
        if (!isCloudinary && !isLocalUpload) {
          return respond.badRequest(res, 'Media URL must point to a trusted host');
        }
      } catch {
        return respond.badRequest(res, 'Invalid media URL');
      }
    }
  }

  // Thread parent must live in this same channel (VR-S1).
  if (threadId) {
    const threadParent = await Message.findOne({
      _id: threadId,
      channelId: channel._id,
      isDeleted: { $ne: true },
    }).select('_id');
    if (!threadParent) {
      return respond.badRequest(res, 'Thread parent not found in this chat');
    }
  }

  // WhatsApp-style quote: parent must be in this channel (root or any).
  let replyTo = undefined;
  if (replyToId) {
    const parent = await Message.findOne({
      _id: replyToId,
      channelId: channel._id,
    })
      .populate('senderId', 'name displayTitle')
      .lean();
    if (!parent) {
      return respond.badRequest(res, 'Quoted message not found in this chat');
    }
    const parentSender = parent.senderId;
    const senderName =
      (parentSender && typeof parentSender === 'object'
        ? [parentSender.displayTitle, parentSender.name].filter(Boolean).join(' ').trim() ||
          parentSender.name
        : null) || 'Doctor';
    const preview =
      parent.content?.text?.slice(0, 120) ||
      (parent.type === MESSAGE_TYPES.IMAGE || parent.type === MESSAGE_TYPES.ECG
        ? 'Photo'
        : parent.type === MESSAGE_TYPES.VIDEO
          ? 'Video'
          : parent.type === MESSAGE_TYPES.DOCUMENT
          ? parent.content?.fileName || 'Document'
          : parent.type === MESSAGE_TYPES.HANDOFF
            ? 'Handoff'
            : 'Message');
    replyTo = {
      messageId: parent._id,
      senderId: parentSender?._id || parentSender || null,
      senderName,
      text: preview,
      type: parent.type,
    };
  }

  // Emergency channel always gets emergency priority
  const effectivePriority = channel.type === CHANNEL_TYPES.EMERGENCY
    ? MESSAGE_PRIORITY.EMERGENCY
    : priority;

  const message = await Message.create({
    channelId: channel._id,
    spaceId: channel.spaceId || null,
    senderId: req.user._id,
    type,
    content,
    priority: effectivePriority,
    threadId: threadId || null,
    ...(replyTo ? { replyTo } : {}),
    mentions: mentions || [],
  });

  // Populate sender for the response + socket broadcast
  await message.populate('senderId', 'name displayTitle role avatarUrl');

  // Sidebar preview must be ready before HTTP response so immediate list
  // reloads don't still show "No messages yet".
  const lastMessageText = messagePreviewText(message);

  await Channel.findByIdAndUpdate(channel._id, {
    lastMessage: {
      messageId: message._id,
      text: lastMessageText,
      senderName: req.user.name,
      type,
      sentAt: message.createdAt,
    },
  });

  // ── HTTP response first ─────────────────────────────────────────────────────
  respond.created(res, 'Message sent', { message });

  // ── Async side-effects (fire and forget after response) ────────────────────
  setImmediate(async () => {
    try {
      const { resolveMessageAudienceIds } = require('../../utils/channelAccess');
      // Private channels must not fan out to the whole space (VR-S8).
      const recipientIds = resolveMessageAudienceIds(channel, space);

      // Socket first so open chats update immediately.
      emitNewMessage(
        channel._id.toString(),
        message.toObject(),
        recipientIds
      );

      // Thread reply bookkeeping — never update a foreign-channel parent (VR-S1).
      if (threadId) {
        await Message.updateOne(
          { _id: threadId, channelId: channel._id },
          {
            $inc: { replyCount: 1 },
            lastReply: {
              senderId: req.user._id,
              senderName: req.user.name,
              text: content?.text?.slice(0, 100) || null,
              sentAt: message.createdAt,
            },
          }
        );
      }

      await notifyNewMessage({
        recipientIds,
        message: message.toObject(),
        sender: req.user,
        channel,
      });

      if (mentions?.length > 0) {
        await notifyMention({
          mentionedUserIds: mentions,
          message: message.toObject(),
          sender: req.user,
          channel,
        });
      }
    } catch (err) {
      logger.error(`Post-send side-effects failed: ${err.message}`);
    }
  });
});

/**
 * GET /api/channels/:channelId/messages/:id/thread
 * Fetch the root message + all its threaded replies
 */
const getThread = asyncHandler(async (req, res) => {
  const access = await resolveChannelAccess(req, res);
  if (!access) return;

  const rootMessage = await Message.findById(req.params.id)
    .populate('senderId', 'name displayTitle role avatarUrl')
    .lean();

  if (!rootMessage) return respond.notFound(res, 'Message not found');
  if (!assertMessageInChannel(rootMessage, req.params.channelId, res)) return;

  const limit = Math.min(parseInt(req.query.limit) || 50, 100);
  const before = req.query.before;

  const threadQuery = {
    channelId: access.channel._id,
    $or: [
      { threadId: rootMessage._id },
      { threadId: rootMessage._id.toString() },
    ],
    isDeleted: false,
  };
  if (before) threadQuery._id = { $lt: before };

  const replies = await Message.find(threadQuery)
    .sort({ _id: -1 })
    .limit(limit + 1)
    .populate('senderId', 'name displayTitle role avatarUrl')
    .lean();

  const hasMore = replies.length > limit;
  if (hasMore) replies.pop();
  replies.reverse();

  return respond.ok(res, 'Thread fetched', { rootMessage, replies, hasMore });
});

/**
 * POST /api/channels/:channelId/messages/:id/reply
 * Reply to a thread (sets threadId automatically)
 */
const replyToThread = asyncHandler(async (req, res, next) => {
  req.body.threadId = req.params.id;
  return sendMessage(req, res, next);
});

/**
 * PUT /api/channels/:channelId/messages/:id
 * Edit a message's text (sender only, text messages only)
 */
const editMessage = asyncHandler(async (req, res) => {
  const access = await resolveChannelAccess(req, res);
  if (!access) return;

  const message = await Message.findById(req.params.id);
  if (!message) return respond.notFound(res, 'Message not found');
  if (!assertMessageInChannel(message, req.params.channelId, res)) return;
  if (message.senderId.toString() !== req.user._id.toString()) {
    return respond.forbidden(res, 'You can only edit your own messages');
  }
  if (message.type !== MESSAGE_TYPES.TEXT) {
    return respond.badRequest(res, 'Only text messages can be edited');
  }

  message.content.text = String(req.body.content?.text ?? '').trim();
  message.isEdited = true;
  message.editedAt = new Date();
  await message.save();

  emitMessageUpdated(req.params.channelId, message._id, {
    content: message.content,
    isEdited: true,
    editedAt: message.editedAt,
  });

  return respond.ok(res, 'Message updated', { message });
});

/**
 * DELETE /api/channels/:channelId/messages/:id
 * Soft-delete a message (sender or space admin)
 */
const deleteMessage = asyncHandler(async (req, res) => {
  const access = await resolveChannelAccess(req, res);
  if (!access) return;

  const message = await Message.findById(req.params.id);
  if (!message) return respond.notFound(res, 'Message not found');
  if (!assertMessageInChannel(message, req.params.channelId, res)) return;

  const isSender = message.senderId.toString() === req.user._id.toString();
  const isAdmin  = access.space?.isAdmin(req.user._id);

  if (!isSender && !isAdmin) {
    return respond.forbidden(res, 'Cannot delete this message');
  }

  message.isDeleted = true; // Pre-save hook blanks content
  await message.save();

  await Message.updateMany(
    {
      channelId: message.channelId,
      'replyTo.messageId': message._id,
    },
    { $set: { 'replyTo.text': 'This message was deleted' } }
  );

  const channel = await Channel.findById(message.channelId).select('lastMessage');
  if (channel?.lastMessage?.messageId?.toString() === message._id.toString()) {
    const previous = await Message.findOne({
      channelId: message.channelId,
      isDeleted: { $ne: true },
    })
      .sort({ createdAt: -1, _id: -1 })
      .populate('senderId', 'name')
      .lean();

    channel.lastMessage = previous
      ? {
          messageId: previous._id,
          text: messagePreviewText(previous),
          senderName: previous.senderId?.name || 'Doctor',
          type: previous.type,
          sentAt: previous.createdAt,
        }
      : {
          messageId: message._id,
          text: 'This message was deleted',
          senderName: req.user.name,
          type: message.type,
          sentAt: message.createdAt,
        };
    await channel.save();
  }

  emitMessageDeleted(req.params.channelId, message._id);

  return respond.ok(res, 'Message deleted');
});

/**
 * POST /api/channels/:channelId/messages/:id/react
 * Toggle an emoji reaction
 */
const toggleReaction = asyncHandler(async (req, res) => {
  const access = await resolveChannelAccess(req, res);
  if (!access) return;

  const message = await Message.findById(req.params.id);
  if (!message) return respond.notFound(res, 'Message not found');
  if (!assertMessageInChannel(message, req.params.channelId, res)) return;
  if (message.isDeleted) return respond.badRequest(res, 'Cannot react to a deleted message');

  await message.toggleReaction(req.body.emoji, req.user._id);

  // Broadcast updated reactions to channel room
  emitMessageUpdated(req.params.channelId, message._id, {
    reactions: message.reactions,
  });

  return respond.ok(res, 'Reaction updated', { reactions: message.reactions });
});

/**
 * POST /api/channels/:channelId/messages/read
 * Mark messages as read (DMs only — updates readBy array)
 */
const markAsRead = asyncHandler(async (req, res) => {
  const access = await resolveChannelAccess(req, res);
  if (!access) return;

  const { channel } = access;
  if (channel.type !== CHANNEL_TYPES.DIRECT) {
    return respond.badRequest(res, 'Read receipts only apply to direct messages');
  }

  // Honour privacy: user opted out of read receipts
  if (req.user.notifications?.readReceiptsEnabled === false) {
    return respond.ok(res, 'Read receipts disabled — skipped');
  }

  const { messageIds } = req.body;

  await Message.updateMany(
    {
      _id: { $in: messageIds },
      channelId: channel._id,
      'readBy.userId': { $ne: req.user._id }, // Skip already-read
    },
    {
      $push: { readBy: { userId: req.user._id, readAt: new Date() } },
    }
  );

  return respond.ok(res, 'Messages marked as read');
});

module.exports = {
  getMessages, sendMessage, getThread, replyToThread,
  editMessage, deleteMessage, toggleReaction, markAsRead,
};
