/**
 * MESSAGE SOCKET HANDLER
 *
 * Handles real-time message events over Socket.io.
 *
 * IMPORTANT ARCHITECTURE DECISION:
 * We do NOT send messages via socket alone.
 * Messages are always persisted via the REST API first (POST /api/channels/:id/messages).
 * The REST controller then emits the socket event to broadcast to other clients.
 *
 * Why this separation?
 * - If the socket connection drops mid-send, the message is still saved
 * - The REST API enforces auth, validation, and rate limiting
 * - Socket is for BROADCASTING (server → all clients), not for initial persistence
 *
 * What this handler DOES manage via socket:
 * - join_channel / leave_channel (room management)
 * - typing_start / typing_stop (pure realtime, not persisted)
 *
 * The `new_message` event is EMITTED by the message REST controller,
 * not received from clients here. Clients listen for it.
 */

const { SOCKET_EVENTS } = require('../../constants');
const { canAccessChannel } = require('../../utils/channelAccess');
const logger = require('../../utils/logger');

/**
 * Register message-related socket event handlers for a connected socket
 * @param {Object} io     - The Socket.io server instance
 * @param {Object} socket - The individual socket connection
 */
const registerMessageHandlers = (io, socket) => {
  const userId = socket.userId;
  const userName = socket.userName;

  /**
   * join_channel
   * Client emits this when they open a channel (navigate to it).
   * Server adds the socket to a room named after the channelId.
   * All subsequent broadcasts for that channel target this room.
   *
   * Room naming convention:
   *   channel:<channelId>
   *   e.g. channel:64a1b2c3d4e5f6789012345
   */
  socket.on(SOCKET_EVENTS.JOIN_CHANNEL, async ({ channelId }) => {
    if (!channelId) return;

    try {
      const allowed = await canAccessChannel(userId, channelId);
      if (!allowed) {
        socket.emit(SOCKET_EVENTS.ERROR, { message: 'Access denied to channel' });
        return;
      }

      const room = `channel:${channelId}`;
      socket.join(room);

      logger.socket(`${userName} joined room ${room}`);

      socket.emit(SOCKET_EVENTS.JOIN_CHANNEL, {
        success: true,
        channelId,
      });
    } catch (err) {
      logger.error(`join_channel failed: ${err.message}`);
      socket.emit(SOCKET_EVENTS.ERROR, { message: 'Could not join channel' });
    }
  });

  /**
   * leave_channel
   * Client emits this when they navigate away from a channel.
   * Removes socket from that channel room — no more broadcasts received.
   */
  socket.on(SOCKET_EVENTS.LEAVE_CHANNEL, ({ channelId }) => {
    if (!channelId) return;

    const room = `channel:${channelId}`;
    socket.leave(room);

    logger.socket(`${userName} left room ${room}`);
  });

  /**
   * typing_start
   * Client emits when user starts typing in a channel.
   * Server broadcasts to all OTHER members in that channel room.
   *
   * NOT persisted. Pure realtime signal.
   * Client shows "Dr. Priya is typing..." indicator.
   *
   * We broadcast to the ROOM excluding the sender (socket.to, not io.to).
   */
  socket.on(SOCKET_EVENTS.TYPING_START, ({ channelId }) => {
    if (!channelId) return;

    const room = `channel:${channelId}`;
    socket.to(room).emit(SOCKET_EVENTS.USER_TYPING, {
      channelId,
      userId,
      userName,
    });
  });

  /**
   * typing_stop
   * Client emits when user stops typing (on blur or after a debounce timeout).
   * Server broadcasts to all OTHER members in that channel room.
   */
  socket.on(SOCKET_EVENTS.TYPING_STOP, ({ channelId }) => {
    if (!channelId) return;

    const room = `channel:${channelId}`;
    socket.to(room).emit(SOCKET_EVENTS.USER_STOPPED_TYPING, {
      channelId,
      userId,
    });
  });
};

module.exports = { registerMessageHandlers };
