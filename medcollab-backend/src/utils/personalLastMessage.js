/**
 * Chat-list previews per viewer: after "Clear chat" or "Delete for me" the
 * list must not keep showing a message the user removed from their view.
 * Two indexed queries for the whole list, plus one lookup per affected chat.
 */
const Message = require('../features/messages/message.model');
const ChatClear = require('../features/messages/chatClear.model');

const previewText = (m) =>
  m.content?.text?.slice(0, 200) ||
  ({ image: '📷 Photo', ecg: '📷 Photo', video: '🎥 Video', document: '📎 Document', audio: '🎤 Voice message', handoff: '🔄 Handoff', alert: '⚠️ Alert' }[m.type] || null);

const personalizeLastMessages = async (channels, userId) => {
  const withLast = channels.filter((c) => c.lastMessage?.messageId);
  if (withLast.length === 0) return channels;

  const ids = channels.map((c) => c._id);
  const [clears, hidden] = await Promise.all([
    ChatClear.find({ userId, channelId: { $in: ids } }).select('channelId clearedAt').lean(),
    Message.find({
      _id: { $in: withLast.map((c) => c.lastMessage.messageId) },
      hiddenFor: userId,
    }).select('_id').lean(),
  ]);
  if (clears.length === 0 && hidden.length === 0) return channels;

  const clearedAt = new Map(clears.map((c) => [String(c.channelId), c.clearedAt]));
  const hiddenIds = new Set(hidden.map((m) => String(m._id)));

  return Promise.all(
    channels.map(async (c) => {
      const last = c.lastMessage;
      if (!last?.messageId) return c;
      const cutoff = clearedAt.get(String(c._id));
      const cleared = cutoff && last.sentAt && new Date(last.sentAt) <= cutoff;
      if (!cleared && !hiddenIds.has(String(last.messageId))) return c;

      const visible = await Message.findOne({
        channelId: c._id,
        threadId: null,
        isDeleted: { $ne: true },
        hiddenFor: { $ne: userId },
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

module.exports = { personalizeLastMessages };
