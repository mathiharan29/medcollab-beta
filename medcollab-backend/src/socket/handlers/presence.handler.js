/**
 * PRESENCE HANDLER
 *
 * Manages real-time presence (who is online, their availability status).
 *
 * Two types of presence in MedCollab:
 *
 * 1. Online/Offline (derived from socket connection)
 *    - User connects socket → they are "online"
 *    - Socket disconnects → they are "offline"
 *    - We store online user IDs in memory (a Set), not in MongoDB
 *    - Why? Presence changes hundreds of times per day — DB writes would be wasteful
 *
 * 2. Availability Status (doctor-set, persisted in MongoDB)
 *    - On Call / In OT / Available / Off Duty etc.
 *    - Changed explicitly by the doctor (not inferred from socket)
 *    - Persisted in User.availability
 *    - Broadcast in real time via socket when changed
 *
 * Architecture note on the in-memory Set:
 * For a single-server deployment (Railway beta), this works perfectly.
 * When we scale to multiple server instances, this Set must move to Redis
 * using a sorted set or Redis pub/sub. That is a scale-day problem.
 * At 15 users, it is absolutely not a today problem.
 */

const { SOCKET_EVENTS } = require('../../constants');
const User = require('../../features/users/user.model');
const logger = require('../../utils/logger');

// In-memory store of currently connected user IDs
// userId (string) → Set of socketIds (a user can have multiple tabs/devices)
const onlineUsers = new Map();

/**
 * Register presence-related socket event handlers
 */
const registerPresenceHandlers = (io, socket) => {
  const userId = socket.userId.toString();

  // ── User Connected ──────────────────────────────────────────────────────────
  // Add this socket to the online users map
  if (!onlineUsers.has(userId)) {
    onlineUsers.set(userId, new Set());
  }
  onlineUsers.get(userId).add(socket.id);

  logger.socket(`Presence: ${socket.userName} connected (${onlineUsers.get(userId).size} devices)`);

  // Join the user's personal room (for targeted notifications)
  // Room naming: user:<userId>
  // The notification service uses this to push to a specific user
  socket.join(`user:${userId}`);

  // Broadcast this user's online status to all their spaces
  // (We broadcast to space rooms — not globally — to avoid unnecessary traffic)
  broadcastPresenceUpdate(io, socket, { isOnline: true });

  // ── Availability Status Update ──────────────────────────────────────────────
  /**
   * update_availability
   * Client emits when doctor manually changes their status (On Call, In OT, etc.)
   * We persist to DB and broadcast to teammates in real time.
   */
  socket.on(SOCKET_EVENTS.UPDATE_AVAILABILITY, async ({ status, until, note }) => {
    try {
      // Validate status is a known value
      const validStatuses = [
        'available', 'on_call', 'in_ot', 'in_icu',
        'on_rounds', 'off_duty', 'do_not_disturb',
      ];

      if (!validStatuses.includes(status)) {
        socket.emit(SOCKET_EVENTS.ERROR, { message: 'Invalid availability status' });
        return;
      }

      // Persist to database
      await User.findByIdAndUpdate(userId, {
        'availability.status': status,
        'availability.until': until || null,
        'availability.note': note || '',
        'availability.updatedAt': new Date(),
      });

      logger.socket(`Availability update: ${socket.userName} → ${status}`);

      // Broadcast to all spaces this user is in
      broadcastPresenceUpdate(io, socket, { status, isOnline: true });

    } catch (err) {
      logger.error('Availability update failed via socket', err.message);
      socket.emit(SOCKET_EVENTS.ERROR, { message: 'Failed to update availability' });
    }
  });

  // ── User Disconnected ───────────────────────────────────────────────────────
  socket.on('disconnect', (reason) => {
    const userSockets = onlineUsers.get(userId);

    if (userSockets) {
      userSockets.delete(socket.id);

      // Only mark as offline if ALL their devices disconnected
      if (userSockets.size === 0) {
        onlineUsers.delete(userId);
        broadcastPresenceUpdate(io, socket, { isOnline: false });

        // Update lastSeenAt in DB (fire and forget)
        User.findByIdAndUpdate(userId, { lastSeenAt: new Date() }).exec();

        logger.socket(`Presence: ${socket.userName} went offline (reason: ${reason})`);
      } else {
        logger.socket(`Presence: ${socket.userName} disconnected one device (${userSockets.size} remaining)`);
      }
    }
  });
};

/**
 * Broadcast a presence update to all space rooms the user belongs to.
 *
 * We join each user to their space rooms on connection (in socket/index.js).
 * Here we emit to those rooms.
 *
 * The event payload tells clients to update the member's status in their UI.
 */
const broadcastPresenceUpdate = (io, socket, update) => {
  // The socket already has spaceIds attached (set during auth in socket/index.js)
  const spaceIds = socket.spaceIds || [];

  spaceIds.forEach((spaceId) => {
    const room = `space:${spaceId}`;
    io.to(room).emit(SOCKET_EVENTS.PRESENCE_UPDATE, {
      userId: socket.userId,
      userName: socket.userName,
      isOnline: update.isOnline,
      availability: update.status
        ? {
            status: update.status,
            until: update.until || null,
            note: update.note || '',
          }
        : undefined,
      updatedAt: new Date().toISOString(),
    });
  });
};

/**
 * Check if a user is currently online
 * Used by the notification service to decide: socket push or FCM push
 */
const isUserOnline = (userId) => {
  return onlineUsers.has(userId.toString());
};

/**
 * Get all online user IDs (for a space member list)
 */
const getOnlineUsers = () => {
  return Array.from(onlineUsers.keys());
};

module.exports = {
  registerPresenceHandlers,
  isUserOnline,
  getOnlineUsers,
};
