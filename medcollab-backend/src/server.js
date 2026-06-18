/**
 * SERVER.JS — Entry Point
 *
 * This file:
 * 1. Loads environment variables (.env)
 * 2. Connects to MongoDB
 * 3. Initialises third-party services (Cloudinary, Firebase)
 * 4. Creates the HTTP server from the Express app
 * 5. Attaches Socket.io to the HTTP server
 * 6. Starts listening on the configured port
 * 7. Handles graceful shutdown (SIGTERM, SIGINT)
 *
 * Why Node's http.createServer instead of app.listen()?
 * Socket.io needs to attach to the underlying HTTP server, not Express.
 * app.listen() creates an HTTP server internally but doesn't expose it.
 * http.createServer(app) gives us the server reference for Socket.io.
 *
 * Graceful shutdown:
 * Railway sends SIGTERM before killing a container (e.g. during deploys).
 * We catch SIGTERM, stop accepting new connections, finish in-flight requests,
 * and close the DB connection cleanly. This prevents data corruption.
 */

// Load .env file FIRST — before any other imports that read process.env
require('dotenv').config();

const http = require('http');
const app = require('./app');
const connectDB = require('./config/database');
const { connectCloudinary } = require('./config/cloudinary');
const { connectFirebase } = require('./config/firebase');
const { initSocket } = require('./socket');
const logger = require('./utils/logger');

// ── Validate Required Environment Variables ───────────────────────────────────
const REQUIRED_ENV = ['MONGODB_URI', 'JWT_SECRET', 'JWT_REFRESH_SECRET'];

const missingEnv = REQUIRED_ENV.filter((key) => !process.env[key]);
if (missingEnv.length > 0) {
  logger.error(`Missing required environment variables: ${missingEnv.join(', ')}`);
  logger.error('Copy .env.example to .env and fill in the values');
  process.exit(1);
}

// ── Server Configuration ──────────────────────────────────────────────────────
const PORT = parseInt(process.env.PORT) || 5000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// ── Bootstrap Function ────────────────────────────────────────────────────────
const startServer = async () => {
  try {
    // 1. Connect to MongoDB Atlas
    await connectDB();

    // 2. Initialise Cloudinary (media storage)
    connectCloudinary();

    // 3. Initialise Firebase Admin (push notifications)
    connectFirebase();

    // 4. Create HTTP server from Express app
    const httpServer = http.createServer(app);

    // 5. Attach Socket.io to the HTTP server
    initSocket(httpServer);

    // 6. Start listening
    httpServer.listen(PORT, () => {
      logger.info(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
      logger.info(`  MedCollab API — ${NODE_ENV.toUpperCase()}`);
      logger.info(`  Listening on port ${PORT}`);
      logger.info(`  Health: http://localhost:${PORT}/health`);
      logger.info(`  API:    http://localhost:${PORT}/api`);
      logger.info(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    });

    // ── Graceful Shutdown ────────────────────────────────────────────────────
    /**
     * Handle shutdown signals gracefully.
     *
     * SIGTERM: Railway/Render sends this before stopping the container
     * SIGINT:  Ctrl+C in terminal (development)
     *
     * Graceful shutdown sequence:
     * 1. Stop HTTP server accepting new connections
     * 2. Wait for in-flight requests to complete (30s timeout)
     * 3. Close MongoDB connection
     * 4. Exit process
     */
    const gracefulShutdown = async (signal) => {
      logger.info(`${signal} received — starting graceful shutdown`);

      // Stop accepting new HTTP connections
      httpServer.close(async () => {
        logger.info('HTTP server closed');

        try {
          const mongoose = require('mongoose');
          await mongoose.connection.close();
          logger.info('MongoDB connection closed');
          process.exit(0);
        } catch (err) {
          logger.error('Error during shutdown:', err.message);
          process.exit(1);
        }
      });

      // Force kill if graceful shutdown takes too long (30 seconds)
      setTimeout(() => {
        logger.error('Graceful shutdown timed out — forcing exit');
        process.exit(1);
      }, 30000);
    };

    process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
    process.on('SIGINT', () => gracefulShutdown('SIGINT'));

    // ── Unhandled Promise Rejections ──────────────────────────────────────────
    // Catch any unhandled promise rejections (shouldn't happen with asyncHandler
    // but acts as a safety net)
    process.on('unhandledRejection', (reason, promise) => {
      logger.error('Unhandled Promise Rejection:', reason);
      // In production, crash and let Railway restart the service
      // (better than running in an unknown state)
      if (NODE_ENV === 'production') {
        gracefulShutdown('unhandledRejection');
      }
    });

    process.on('uncaughtException', (err) => {
      logger.error('Uncaught Exception:', err.message);
      // Always crash on uncaught exceptions — state is unknown
      process.exit(1);
    });

  } catch (err) {
    logger.error(`Failed to start server: ${err.message}`);
    process.exit(1);
  }
};

// ── Start ─────────────────────────────────────────────────────────────────────
startServer();
