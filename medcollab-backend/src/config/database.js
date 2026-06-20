/**
 * DATABASE CONFIG
 *
 * Production: requires MONGODB_URI (MongoDB Atlas).
 * Development: auto-starts in-memory MongoDB when MONGODB_URI is unset.
 */

const mongoose = require('mongoose');
const logger = require('../utils/logger');

let memoryServer;

const stopMemoryServer = async () => {
  if (memoryServer) {
    await memoryServer.stop();
    memoryServer = null;
  }
};

const connectDB = async () => {
  let uri = process.env.MONGODB_URI;
  const isProd = process.env.NODE_ENV === 'production';

  if (!uri && !isProd) {
    try {
      const { MongoMemoryServer } = require('mongodb-memory-server');
      memoryServer = await MongoMemoryServer.create();
      uri = memoryServer.getUri('medcollab');
      logger.warn('DEV: In-memory MongoDB — no Atlas needed (data resets on restart)');
    } catch (err) {
      logger.error(`In-memory MongoDB failed: ${err.message}`);
      logger.error('Run: cd medcollab-backend && npm install');
      process.exit(1);
    }
  }

  if (!uri) {
    logger.error('MONGODB_URI is required in production');
    process.exit(1);
  }

  try {
    const conn = await mongoose.connect(uri, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 10000,
      socketTimeoutMS: 45000,
    });

    logger.info(`MongoDB connected: ${conn.connection.host}`);

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
    process.exit(1);
  }
};

connectDB.stopMemoryServer = stopMemoryServer;

module.exports = connectDB;
