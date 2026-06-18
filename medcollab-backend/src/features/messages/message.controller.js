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
const { emitNewMessage, emitMessageUpdated, emitMessageDeleted } = require('../../socket');
const { notifyNewMessage, notifyMention } = require('../../services/notification.service');
const { MESSAGE_TYPES, MESSAGE_PRIORITY, PAGINATION, CHANNEL_TYPES } = require('../../constants');
const logger = require('../../utils/logger');

/**
 * Verify the requesting user can access a channel.
 * Returns { channel, space } or sends an error response and returns null.
 */
const resolveChannelAccess = async (req, res) => {
  const channel = await Channel.findById(req.params.channelId);
  if (!channel) { respond.notFound(res, 'Channel not found'); return null; }

  if (channel.type === CHANNEL_TYPES.DIRECT) {
    const isMember = channel.members.some(
      (id) => id.toString() === req.user._id.toString()
    );
    if (!isMember) { respond.forbidden(res, 'Not a channel member'); return null; }
    return { channel, space: null };
  }

  const space = await Space.findById(channel.spaceId);
  if (!space?.isMember(req.user._id)) {
    respond.forbidden(res, 'Not a space member'); return null;
  }
  return { channel, space };
};

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

  const messages = await Message.find(query)
    .sort({ _id: -1 })          // Newest first from DB
    .limit(limit + 1)           // Fetch one extra to know if there's more
    .populate('senderId', 'name displayTitle role avatarUrl')
    .lean();

  const hasMore = messages.length > limit;
  if (hasMore) messages.pop();  // Remove the extra

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

  const { type = MESSAGE_TYPES.TEXT, content, priority = MESSAGE_PRIORITY.NORMAL, threadId, mentions } = req.body;

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
    mentions: mentions || [],
  });

  // Populate sender for the socket broadcast
  await message.populate('senderId', 'name displayTitle role avatarUrl');

  // ── HTTP response first ─────────────────────────────────────────────────────
  respond.created(res, 'Message sent', { message });

  // ── Async side-effects (fire and forget after response) ────────────────────
  setImmediate(async () => {
    try {
      // 1. Socket broadcast to channel room
      emitNewMessage(channel._id.toString(), message.toObject());

      // 2. If it's a thread reply: update parent's replyCount + lastReply snapshot
      if (threadId) {
        await Message.findByIdAndUpdate(threadId, {
          $inc: { replyCount: 1 },
          lastReply: {
            senderId: req.user._id,
            senderName: req.user.name,
            text: content?.text?.slice(0, 100) || null,
            sentAt: message.createdAt,
          },
        });
      }

      // 3. Update channel.lastMessage for sidebar preview
      await Channel.findByIdAndUpdate(channel._id, {
        lastMessage: {
          messageId: message._id,
          text: content?.text?.slice(0, 200) || null,
          senderName: req.user.name,
          type,
          sentAt: message.createdAt,
        },
      });

      // 4. Notifications — get channel members to notify
      let recipientIds = [];
      if (channel.type === CHANNEL_TYPES.DIRECT) {
        recipientIds = channel.members;
      } else if (space) {
        recipientIds = space.members.map((m) => m.userId);
      }

      await notifyNewMessage({
        recipientIds,
        message: message.toObject(),
        sender: req.user,
        channel,
      });

      // 5. Extra notification for @mentions
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

  const limit = Math.min(parseInt(req.query.limit) || 50, 100);
  const before = req.query.before;

  const threadQuery = {
    threadId: rootMessage._id,
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
const replyToThread = asyncHandler(async (req, res) => {
  // Inject threadId from the URL param, then re-use sendMessage logic
  req.body.threadId = req.params.id;
  return sendMessage(req, res);
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
  if (message.senderId.toString() !== req.user._id.toString()) {
    return respond.forbidden(res, 'You can only edit your own messages');
  }
  if (message.type !== MESSAGE_TYPES.TEXT) {
    return respond.badRequest(res, 'Only text messages can be edited');
  }

  message.content.text = req.body.content.text;
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

  const isSender = message.senderId.toString() === req.user._id.toString();
  const isAdmin  = access.space?.isAdmin(req.user._id);

  if (!isSender && !isAdmin) {
    return respond.forbidden(res, 'Cannot delete this message');
  }

  message.isDeleted = true; // Pre-save hook blanks content
  await message.save();

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
