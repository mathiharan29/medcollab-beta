/**
 * CLOUDINARY CONFIG
 *
 * Why Cloudinary for beta:
 * - Free tier: 25GB storage, 25GB bandwidth/month — plenty for 15 doctors
 * - Auto-generates thumbnails (critical for X-ray previews in chat)
 * - Handles PDF preview generation
 * - CDN included — media loads fast on mobile networks
 * - If we outgrow it, swap the service layer; routes don't change
 *
 * We configure it once here and import the instance everywhere.
 */

const cloudinary = require('cloudinary').v2;
const logger = require('../utils/logger');

const connectCloudinary = () => {
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
    secure: true, // Always use HTTPS
  });

  logger.info('Cloudinary configured');
};

module.exports = { connectCloudinary, cloudinary };
