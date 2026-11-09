/**
 * WhatsApp-style activity lines in a chat (REQ 2):
 *   "Dr Asha Rao added Dr Vikram Shah", "… left", "… removed …",
 *   "… changed the group name to "Ward 5"".
 *
 * Stored as normal messages with type `system` so they keep their place in
 * the timeline, page with history and arrive live. Clients render them as a
 * centred chip, never as a bubble. Clients cannot send this type themselves
 * (message validation allows only user content types).
 */

const Message = require('../features/messages/message.model');
const Channel = require('../features/channels/channel.model');
const { MESSAGE_TYPES, CHANNEL_TYPES } = require('../constants');
const logger = require('./logger');

const SYSTEM_EVENTS = {
  GROUP_CREATED: 'group_created',
  MEMBER_JOINED: 'member_joined',
  MEMBER_ADDED: 'member_added',
  MEMBER_REMOVED: 'member_removed',
  MEMBER_LEFT: 'member_left',
  GROUP_RENAMED: 'group_renamed',
  CHANNEL_RENAMED: 'channel_renamed',
};

/** "Dr Asha Rao" — title + name, never empty. */
function personName(user) {
  if (!user) return 'A doctor';
  const name = (user.name || '').trim();
  const title = (user.displayTitle || '').trim();
  if (!name) return 'A doctor';
  if (title && !name.toLowerCase().startsWith(title.toLowerCase())) {
    return `${title} ${name}`;
  }
  return name;
}

/** "A", "A and B", "A, B and 2 others" */
function joinNames(names) {
  if (names.length <= 1) return names[0] || '';
  if (names.length === 2) return `${names[0]} and ${names[1]}`;
  if (names.length === 3) return `${names[0]}, ${names[1]} and ${names[2]}`;
  return `${names[0]}, ${names[1]} and ${names.length - 2} others`;
}

/**
 * The group's main chat (#general), where membership activity is posted.
 */
async function mainChannelForSpace(spaceId) {
  return (
    (await Channel.findOne({
      spaceId,
      type: CHANNEL_TYPES.GENERAL,
      isArchived: false,
    }).sort({ position: 1 })) ||
    Channel.findOne({ spaceId, isArchived: false }).sort({ position: 1 })
  );
}

/**
 * Persist + broadcast one system line. Never throws: activity lines must
 * not break the membership change that caused them.
 *
 * @param {object} opts
 * @param {object} opts.channel  Channel doc (or { _id, spaceId })
 * @param {object} opts.actor    User doc who caused it
 * @param {string} opts.event    SYSTEM_EVENTS value
 * @param {string} opts.text     Human line
 * @param {string[]} [opts.targetUserIds]
 * @param {string[]} [opts.notifyUserIds]  extra socket fan-out
 */
async function postSystemMessage({
  channel,
  actor,
  event,
  text,
  targetUserIds = [],
  notifyUserIds = [],
}) {
  if (!channel || !actor) return null;
  try {
    const message = await Message.create({
      channelId: channel._id,
      spaceId: channel.spaceId || null,
      senderId: actor._id,
      type: MESSAGE_TYPES.SYSTEM,
      content: {
        text: text.slice(0, 4000),
        systemEvent: event,
        targetUserIds,
      },
    });
    await message.populate('senderId', 'name displayTitle role avatarUrl');

    await Channel.findByIdAndUpdate(channel._id, {
      lastMessage: {
        messageId: message._id,
        text: text.slice(0, 200),
        senderName: null,
        type: MESSAGE_TYPES.SYSTEM,
        sentAt: message.createdAt,
      },
    });

    try {
      const { emitNewMessage } = require('../socket');
      emitNewMessage(channel._id.toString(), message.toObject(), notifyUserIds);
    } catch (err) {
      logger.debug(`System message broadcast skipped: ${err.message}`);
    }
    return message;
  } catch (err) {
    logger.error(`System message failed (${event}): ${err.message}`);
    return null;
  }
}

/** Convenience: post into a group's main chat. */
async function postSpaceSystemMessage(space, opts) {
  const channel = await mainChannelForSpace(space._id);
  const memberIds = (space.members || []).map((m) => m.userId.toString());
  return postSystemMessage({
    ...opts,
    channel,
    notifyUserIds: [...new Set([...memberIds, ...(opts.notifyUserIds || [])])],
  });
}

module.exports = {
  SYSTEM_EVENTS,
  personName,
  joinNames,
  mainChannelForSpace,
  postSystemMessage,
  postSpaceSystemMessage,
};
