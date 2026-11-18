/**
 * Per-viewer views of shared chat data. "Delete for me" (`hiddenFor`) and
 * "Clear chat" (`ChatClear.clearedAt`) are personal, but several places
 * expose denormalised copies of messages:
 *   - channel.lastMessage   → chat-list / group-list / Home previews
 *   - root.replyCount/lastReply → "N replies · last reply" under a message
 *   - channel.pinnedMessages → pinned bar
 * Each helper rewrites those copies for one viewer so a message they removed
 * never reappears there. Other members keep the shared values.
 */
const Message = require('../features/messages/message.model');
const ChatClear = require('../features/messages/chatClear.model');

const previewText = (m) =>
  m.content?.text?.slice(0, 200) ||
  ({ image: '📷 Photo', ecg: '📷 Photo', video: '🎥 Video', document: '📎 Document', audio: '🎤 Voice message', handoff: '🔄 Handoff', alert: '⚠️ Alert' }[m.type] || null);

const sameId = (a, b) => String(a) === String(b);

/** Map channelId → clearedAt for this viewer. */
const clearCutoffs = async (userId, channelIds) => {
  if (!channelIds.length) return new Map();
  const clears = await ChatClear.find({ userId, channelId: { $in: channelIds } })
    .select('channelId clearedAt')
    .lean();
  return new Map(clears.map((c) => [String(c.channelId), c.clearedAt]));
};

/** True when [m] (lean, with hiddenFor + createdAt) is gone for the viewer. */
const isGoneFor = (m, userId, cutoff) =>
  !m ||
  m.isDeleted === true ||
  (m.hiddenFor || []).some((id) => sameId(id, userId)) ||
  (cutoff && m.createdAt && new Date(m.createdAt) <= cutoff);

/**
 * Chat-list previews. A preview is replaced when its message is hidden for
 * the viewer, is older than their Clear chat, or is a thread reply whose
 * root they hid / cleared (that thread is unreachable for them). The
 * replacement is the newest root message they can still see, or "empty".
 */
const personalizeLastMessages = async (channels, userId) => {
  const withLast = channels.filter((c) => c.lastMessage?.messageId);
  if (withLast.length === 0) return channels;

  const [cutoffs, lastDocs] = await Promise.all([
    clearCutoffs(userId, withLast.map((c) => c._id)),
    Message.find({ _id: { $in: withLast.map((c) => c.lastMessage.messageId) } })
      .select('_id threadId createdAt isDeleted hiddenFor')
      .lean(),
  ]);
  const lastById = new Map(lastDocs.map((m) => [String(m._id), m]));

  const rootIds = lastDocs.filter((m) => m.threadId).map((m) => m.threadId);
  const roots = rootIds.length
    ? await Message.find({ _id: { $in: rootIds } })
        .select('_id createdAt isDeleted hiddenFor')
        .lean()
    : [];
  const rootById = new Map(roots.map((m) => [String(m._id), m]));

  const needsFallback = (c) => {
    const last = c.lastMessage;
    const cutoff = cutoffs.get(String(c._id));
    if (cutoff && last.sentAt && new Date(last.sentAt) <= cutoff) return true;
    const doc = lastById.get(String(last.messageId));
    // Row gone (hard delete raced the list) → recompute from what exists.
    if (!doc) return true;
    if (isGoneFor(doc, userId, cutoff)) return true;
    if (doc.threadId) {
      return isGoneFor(rootById.get(String(doc.threadId)), userId, cutoff);
    }
    return false;
  };

  return Promise.all(
    channels.map(async (c) => {
      if (!c.lastMessage?.messageId || !needsFallback(c)) return c;
      const last = c.lastMessage;
      const cutoff = cutoffs.get(String(c._id));
      const visible = await Message.findOne({
        channelId: c._id,
        threadId: null,
        isDeleted: { $ne: true },
        hiddenFor: { $ne: userId },
        // Needl Voice clips are not chat messages (separate voice space).
        'content.voiceMode': { $ne: true },
        ...(cutoff ? { createdAt: { $gt: cutoff } } : {}),
      })
        .sort({ createdAt: -1, _id: -1 })
        .populate('senderId', 'name')
        .lean();
      return {
        ...c,
        lastMessage: visible
          ? {
              messageId: visible._id,
              text: previewText(visible),
              senderName: visible.senderId?.name || 'Doctor',
              type: visible.type,
              // Keep the list order stable: the chat still had activity.
              sentAt: last.sentAt,
            }
          : { messageId: null, text: null, senderName: null, type: null, sentAt: last.sentAt },
      };
    })
  );
};

/** Personalise every channel embedded in a list of spaces (Groups tab). */
const personalizeSpaceChannels = async (spaces, userId) => {
  const all = spaces.flatMap((s) => s.channels || []);
  if (all.length === 0) return spaces;
  const personal = await personalizeLastMessages(all, userId);
  const byId = new Map(personal.map((c) => [String(c._id), c]));
  return spaces.map((s) => ({
    ...s,
    channels: (s.channels || []).map((c) => byId.get(String(c._id)) || c),
  }));
};

/**
 * "N replies · last reply" under root messages, for one viewer. Only roots
 * with a reply this viewer deleted for themselves are recomputed (one query
 * to find them, one per affected root).
 */
const personalizeThreadSummaries = async (messages, userId) => {
  const roots = messages.filter((m) => !m.threadId && (m.replyCount || 0) > 0);
  if (roots.length === 0) return messages;
  const hiddenReplies = await Message.find({
    threadId: { $in: roots.map((m) => m._id) },
    hiddenFor: userId,
  })
    .select('threadId')
    .lean();
  if (hiddenReplies.length === 0) return messages;
  const affected = new Set(hiddenReplies.map((r) => String(r.threadId)));

  const fixed = new Map();
  await Promise.all(
    [...affected].map(async (rootId) => {
      const visible = await Message.find({
        threadId: rootId,
        isDeleted: { $ne: true },
        hiddenFor: { $ne: userId },
      })
        .sort({ createdAt: -1, _id: -1 })
        .populate('senderId', 'name')
        .lean();
      const last = visible[0];
      fixed.set(rootId, {
        replyCount: visible.length,
        lastReply: last
          ? {
              senderId: last.senderId?._id || last.senderId,
              senderName: last.senderId?.name || 'Doctor',
              text: previewText(last)?.slice(0, 100) || null,
              sentAt: last.createdAt,
            }
          : null,
      });
    })
  );
  return messages.map((m) => {
    const f = fixed.get(String(m._id));
    return f ? { ...m, ...f } : m;
  });
};

/** Drop pinned messages the viewer deleted for themselves or cleared. */
const personalizePinned = async (channel, userId) => {
  // Populated pins are lean docs: the model's toJSON (which hides
  // `hiddenFor`, i.e. who deleted what) never runs on them.
  const pins = (channel?.pinnedMessages || []).map((p) => {
    if (p.messageId && typeof p.messageId === 'object' && 'hiddenFor' in p.messageId) {
      const { hiddenFor: _h, ...msg } = p.messageId;
      return { ...p, messageId: msg };
    }
    return p;
  });
  if (pins.length === 0) return channel;
  channel = { ...channel, pinnedMessages: pins };
  const cutoff = (await clearCutoffs(userId, [channel._id])).get(String(channel._id));
  const ids = pins
    .map((p) => p.messageId?._id || p.messageId)
    .filter(Boolean);
  const gone = new Set(
    (
      await Message.find({
        _id: { $in: ids },
        $or: [
          { hiddenFor: userId },
          ...(cutoff ? [{ createdAt: { $lte: cutoff } }] : []),
        ],
      })
        .select('_id')
        .lean()
    ).map((m) => String(m._id))
  );
  if (gone.size === 0) return channel;
  return {
    ...channel,
    pinnedMessages: pins.filter(
      (p) => !gone.has(String(p.messageId?._id || p.messageId))
    ),
  };
};

module.exports = {
  personalizeLastMessages,
  personalizeSpaceChannels,
  personalizeThreadSummaries,
  personalizePinned,
  clearCutoffs,
};
