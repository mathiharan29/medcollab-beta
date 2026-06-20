/**
 * SOCKET.IO SERVER SETUP
 *
 * This is the central nervous system for real-time features.
 *
 * Connection lifecycle:
 * 1. Client connects with JWT in handshake auth
 * 2. We verify the JWT (same logic as HTTP auth middleware)
 * 3. We fetch the user's space memberships and join them to space rooms
 * 4. We register all event handlers (message, presence, etc.)
 * 5. On disconnect, presence handler cleans up
 *
 * Room architecture:
 *   user:<userId>          — Personal room (targeted notifications, DMs)
 *   space:<spaceId>        — Space room (presence updates, space-level events)
 *   channel:<channelId>    — Channel room (messages, typing indicators)
 *
 * Why three levels of rooms?
 * - user room: push a notification to ONE specific doctor
 * - space room: broadcast "Dr. Priya is now on call" to the whole department
 * - channel room: broadcast new messages only to people in that channel view
 *
 * This mirrors Slack's architecture: workspace events vs channel events.
 *
 * Socket auth:
 * JWT is passed in the handshake, not in every message.
 * This is the standard pattern. The token is verified once on connect.
 * If the token expires during a session, the client reconnects with a new token.
 *
 * Flutter implementation note:
 * socket_io_client package — connect with:
 *   IO.socket('wss://api.medcollab.com', OptionBuilder()
 *     .setTransports(['websocket'])
 *     .setAuth({'token': accessToken})
 *     .build())
 */

const { Server } = require('socket.io');
const { authenticateSocket } = require('../middleware/auth');
const { registerMessageHandlers } = require('./handlers/message.handler');
const { registerPresenceHandlers } = require('./handlers/presence.handler');
const Space = require('../features/spaces/space.model');
const { SOCKET_EVENTS } = require('../constants');
const logger = require('../utils/logger');

let io; // Singleton — exported for use in controllers to emit events

/**
 * Initialise the Socket.io server
 * Called once from server.js, passed the HTTP server instance
 */
const initSocket = (httpServer) => {
  const isDev = process.env.NODE_ENV !== 'production';
  const allowedOrigins =
    process.env.ALLOWED_ORIGINS?.split(',').map((o) => o.trim()) || [];

  io = new Server(httpServer, {
    cors: {
      origin: (origin, callback) => {
        if (!origin) return callback(null, true);

        if (isDev) {
          const isLocalDev = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(
            origin
          );
          if (isLocalDev) return callback(null, true);
        }

        if (allowedOrigins.includes(origin)) {
          return callback(null, true);
        }

        callback(new Error(`Socket CORS: origin ${origin} not allowed`));
      },
      methods: ['GET', 'POST'],
      credentials: true,
    },
    // Connection state recovery:
    // If a client briefly disconnects and reconnects within 2 minutes,
    // Socket.io will restore their rooms and replay missed events.
    connectionStateRecovery: {
      maxDisconnectionDuration: 2 * 60 * 1000, // 2 minutes
      skipMiddlewares: true,
    },
    pingTimeout: 60000,   // Disconnect after 60s of no pong
    pingInterval: 25000,  // Send ping every 25s
  });

  // ── Authentication Middleware ──────────────────────────────────────────────
  // Runs before every connection is established
  io.use(async (socket, next) => {
    try {
      // JWT is passed in handshake.auth.token from the Flutter client
      const token = socket.handshake.auth?.token;

      const user = await authenticateSocket(token);

      // Attach user info to the socket object — available in all handlers
      socket.userId = user._id;
      socket.userName = user.name || 'Doctor';

      next(); // Allow connection
    } catch (err) {
      logger.warn(`Socket auth rejected: ${err.message}`);
      next(new Error('Authentication failed')); // Reject connection
    }
  });

  // ── Connection Handler ─────────────────────────────────────────────────────
  io.on('connection', async (socket) => {
    logger.socket(`Connected: ${socket.userName} (${socket.id})`);

    try {
      // ── Join Space Rooms ───────────────────────────────────────────────────
      // Fetch all spaces this user belongs to and join their rooms.
      // This allows space-level broadcasts (presence updates, announcements).
      const spaces = await Space.find(
        { 'members.userId': socket.userId, isActive: true },
        { _id: 1 } // Only need IDs
      ).lean();

      const spaceIds = spaces.map((s) => s._id.toString());
      socket.spaceIds = spaceIds; // Attach for use in presence handler

      // Join each space room
      spaceIds.forEach((spaceId) => {
        socket.join(`space:${spaceId}`);
      });

      logger.socket(`${socket.userName} joined ${spaceIds.length} space rooms`);

      // ── Register Event Handlers ────────────────────────────────────────────
      registerMessageHandlers(io, socket);
      registerPresenceHandlers(io, socket);
      // Future: registerHandoffHandlers(io, socket);

      // ── Acknowledge Successful Connection ──────────────────────────────────
      socket.emit(SOCKET_EVENTS.AUTHENTICATED, {
        userId: socket.userId,
        connectedAt: new Date().toISOString(),
        spaceCount: spaceIds.length,
      });

    } catch (err) {
      logger.error(`Socket setup error for ${socket.userName}: ${err.message}`);
      socket.emit(SOCKET_EVENTS.ERROR, { message: 'Connection setup failed' });
      socket.disconnect(true);
    }
  });

  logger.info('Socket.io initialised');
  return io;
};

/**
 * Get the Socket.io instance
 * Used by REST controllers to emit events after DB operations:
 *
 *   const { getIO } = require('../socket');
 *   getIO().to(`channel:${channelId}`).emit('new_message', message);
 *
 * This is the critical bridge between REST (persistence) and Socket (broadcast).
 */
const getIO = () => {
  if (!io) {
    throw new Error('Socket.io not initialised. Call initSocket(server) first.');
  }
  return io;
};

/**
 * Emit a new_message event to a channel room
 * Called by the message controller after saving a message to MongoDB
 */
const emitNewMessage = (channelId, message) => {
  const doc =
    typeof message.toObject === 'function' ? message.toObject() : message;

  const sender = doc.senderId;
  const payload = {
    ...doc,
    _id: doc._id?.toString(),
    channelId: channelId.toString(),
    spaceId: doc.spaceId?.toString(),
    threadId: doc.threadId?.toString() || null,
    senderId: sender?._id
      ? {
          _id: sender._id.toString(),
          name: sender.name,
          displayTitle: sender.displayTitle,
          role: sender.role,
          avatarUrl: sender.avatarUrl,
        }
      : sender?.toString(),
    createdAt: doc.createdAt?.toISOString?.() ?? doc.createdAt,
    updatedAt: doc.updatedAt?.toISOString?.() ?? doc.updatedAt,
  };

  getIO()
    .to(`channel:${channelId}`)
    .emit(SOCKET_EVENTS.NEW_MESSAGE, payload);
};

/**
 * Emit a message_updated event (after edit)
 */
const emitMessageUpdated = (channelId, messageId, updates) => {
  getIO()
    .to(`channel:${channelId}`)
    .emit(SOCKET_EVENTS.MESSAGE_UPDATED, { messageId, ...updates });
};

/**
 * Emit a message_deleted event (after soft delete)
 */
const emitMessageDeleted = (channelId, messageId) => {
  getIO()
    .to(`channel:${channelId}`)
    .emit(SOCKET_EVENTS.MESSAGE_DELETED, { messageId, deletedAt: new Date() });
};

/**
 * Emit a notification to a specific user's personal room
 * Called by the notification service
 */
const emitNotification = (userId, notification) => {
  getIO()
    .to(`user:${userId}`)
    .emit(SOCKET_EVENTS.NEW_NOTIFICATION, notification);
};

module.exports = {
  initSocket,
  getIO,
  emitNewMessage,
  emitMessageUpdated,
  emitMessageDeleted,
  emitNotification,
};
