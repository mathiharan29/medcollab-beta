/**
 * APP.JS — Express Application
 *
 * This file creates and configures the Express app.
 * It does NOT start the server (that's server.js).
 *
 * Separation of app and server exists because:
 * 1. Testing: import app without starting a real server
 * 2. Clarity: middleware config vs server startup are different concerns
 *
 * Middleware order matters in Express.
 * The stack executes top-to-bottom for every request:
 *
 * 1. helmet       — Sets security HTTP headers (first, always)
 * 2. cors         — Handles cross-origin requests
 * 3. globalLimiter— Rate limiting before anything expensive runs
 * 4. morgan       — HTTP request logging
 * 5. json parser  — Parse request body
 * 6. routes       — Feature route handlers
 * 7. 404 handler  — Catches unmatched routes
 * 8. error handler— Global error catch-all (must be last)
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const { globalLimiter } = require('./middleware/rateLimiter');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');
const logger = require('./utils/logger');

// ── Feature Routes ────────────────────────────────────────────────────────────
const authRoutes = require('./features/auth/auth.routes');
const userRoutes = require('./features/users/user.routes');
const spaceRoutes = require('./features/spaces/space.routes');
const { spaceChannelRouter, channelRouter } = require('./features/channels/channel.routes');
const messageRoutes = require('./features/messages/message.routes');
const { handoffRouter, spaceHandoffRouter } = require('./features/handoffs/handoff.routes');
const mediaRoutes = require('./features/media/media.routes');
const notificationRoutes = require('./features/notifications/notification.routes');

const app = express();

// ── Security Middleware ───────────────────────────────────────────────────────
/**
 * Helmet sets ~14 security-related HTTP headers automatically.
 * Protects against common web vulnerabilities:
 * - XSS (Cross-Site Scripting)
 * - Clickjacking
 * - MIME type sniffing
 * - Information leakage (removes X-Powered-By: Express)
 */
app.use(helmet());

/**
 * CORS — Cross-Origin Resource Sharing
 * For the mobile app, CORS is not strictly necessary (apps don't have origins).
 * But when we add the web dashboard later, this will matter.
 */
const corsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, Postman)
    if (!origin) return callback(null, true);

    const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',') || [];
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error(`CORS policy: origin ${origin} not allowed`));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
};
app.use(cors(corsOptions));

// ── Rate Limiting ─────────────────────────────────────────────────────────────
app.use('/api/', globalLimiter);

// ── Request Logging ───────────────────────────────────────────────────────────
/**
 * Morgan logs every HTTP request: method, path, status, response time.
 * 'dev' format in development: colourised, concise
 * 'combined' format in production: Apache-style, good for log aggregation
 */
app.use(
  morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev', {
    // Skip logging health checks (Railway pings /health every 30s — noise)
    skip: (req) => req.path === '/health',
    stream: {
      write: (message) => logger.info(message.trim()),
    },
  })
);

// ── Body Parsing ──────────────────────────────────────────────────────────────
// Parse JSON bodies (application/json)
app.use(express.json({ limit: '10mb' }));

// Parse URL-encoded bodies (for any form submissions)
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ── Health Check ──────────────────────────────────────────────────────────────
/**
 * Railway and Render use this endpoint to verify the service is alive.
 * Must be unauthenticated and return 200 quickly.
 * Returns DB connection state for monitoring.
 */
app.get('/health', (req, res) => {
  const mongoose = require('mongoose');
  const dbState = ['disconnected', 'connected', 'connecting', 'disconnecting'];

  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV,
    database: dbState[mongoose.connection.readyState] || 'unknown',
    uptime: Math.floor(process.uptime()) + 's',
  });
});

// ── API Routes ────────────────────────────────────────────────────────────────
/**
 * Route mounting — URL prefix maps to feature router.
 *
 * Nested routes explained:
 *
 * /api/spaces/:spaceId/channels
 *   → spaceChannelRouter (with mergeParams: true to access :spaceId)
 *   → Handles channel creation and listing within a space
 *
 * /api/spaces/:spaceId/handoffs
 *   → spaceHandoffRouter (admin/history view of handoffs in a space)
 *
 * /api/channels/:channelId/messages
 *   → messageRoutes (with mergeParams: true to access :channelId)
 *   → All message operations within a channel
 */
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/spaces', spaceRoutes);
app.use('/api/spaces/:spaceId/channels', spaceChannelRouter);
app.use('/api/handoffs', handoffRouter);
app.use('/api/spaces/:spaceId/handoffs', spaceHandoffRouter);
app.use('/api/channels', channelRouter);
app.use('/api/channels/:channelId/messages', messageRoutes);
app.use('/api/media', mediaRoutes);
app.use('/api/notifications', notificationRoutes);

// ── API Info Route ────────────────────────────────────────────────────────────
app.get('/api', (req, res) => {
  res.json({
    name: 'MedCollab API',
    version: '1.0.0',
    status: 'Day 1 — Architecture complete. Controllers pending.',
    endpoints: {
      auth: '/api/auth',
      users: '/api/users',
      spaces: '/api/spaces',
      channels: '/api/channels',
      media: '/api/media',
      notifications: '/api/notifications',
    },
  });
});

// ── Error Handling ────────────────────────────────────────────────────────────
// These MUST be last — after all routes

// Catch unmatched routes (404)
app.use(notFoundHandler);

// Global error handler (catches errors passed via next(err) or thrown in asyncHandler)
app.use(errorHandler);

module.exports = app;
