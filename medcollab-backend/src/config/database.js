/**
 * DATABASE CONFIG
 *
 * Why this approach:
 * - Single connection pool shared across the whole app
 * - Mongoose handles reconnection automatically
 * - We log connection events so Railway/Render logs are useful
 * - strictQuery: false — allows querying fields not in schema without throwing
 *   (useful during early dev, tighten later)
 */

const mongoose = require('mongoose');
const logger = require('../utils/logger');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI, {
      // These are the recommended settings for Atlas
      maxPoolSize: 10,        // Max simultaneous connections (fine for 15 users)
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
    });

    logger.info(`MongoDB connected: ${conn.connection.host}`);

    // Log when connection drops — important for debugging on Railway
    mongoose.connection.on('disconnected', () => {
      logger.warn('MongoDB disconnected. Attempting to reconnect...');
    });

    mongoose.connection.on('reconnected', () => {
      logger.info('MongoDB reconnected');
    });

    mongoose.connection.on('error', (err) => {
      logger.error(`MongoDB connection error: ${err.message}`);
    });

  } catch (error) {
    logger.error(`MongoDB connection failed: ${error.message}`);
    // Exit the process — if we can't reach the DB, the app is useless
    process.exit(1);
  }
};

module.exports = connectDB;
