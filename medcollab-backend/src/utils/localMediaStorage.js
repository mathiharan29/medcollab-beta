/**
 * Local file storage fallback when Cloudinary is not configured.
 * Used for dev/beta before cloud media is wired up.
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const logger = require('./logger');

const UPLOAD_ROOT = path.join(process.cwd(), 'uploads');

const ensureDir = (dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
};

const getApiBaseUrl = () => {
  if (process.env.API_BASE_URL) {
    return process.env.API_BASE_URL.replace(/\/+$/, '');
  }
  const port = process.env.PORT || 5000;
  return `http://localhost:${port}`;
};

/**
 * Save an uploaded buffer to disk and return a public URL.
 */
const saveLocalUpload = ({ buffer, mimeType, originalName, userId, context = 'message' }) => {
  const folderMap = {
    message: `medcollab/messages/${userId}`,
    avatar: `medcollab/avatars/${userId}`,
    handoff: 'medcollab/handoffs',
  };
  const folder = folderMap[context] || folderMap.message;
  const ext = path.extname(originalName || '') || _extFromMime(mimeType);
  const safeName = `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`;
  const relativePath = path.posix.join(folder, safeName);
  const absoluteDir = path.join(UPLOAD_ROOT, folder);
  const absolutePath = path.join(UPLOAD_ROOT, relativePath);

  ensureDir(absoluteDir);
  fs.writeFileSync(absolutePath, buffer);

  const publicId = relativePath.replace(/\\/g, '/');
  const url = `${getApiBaseUrl()}/uploads/${publicId}`;

  logger.info(`Local media saved: ${publicId}`);

  return {
    url,
    thumbnailUrl: mimeType.startsWith('image/') ? url : null,
    publicId,
  };
};

const deleteLocalUpload = (publicId) => {
  const absolutePath = path.join(UPLOAD_ROOT, publicId);
  if (!fs.existsSync(absolutePath)) return false;
  fs.unlinkSync(absolutePath);
  return true;
};

const _extFromMime = (mimeType) => {
  const map = {
    'image/jpeg': '.jpg',
    'image/png': '.png',
    'image/webp': '.webp',
    'application/pdf': '.pdf',
  };
  return map[mimeType] || '.bin';
};

module.exports = {
  UPLOAD_ROOT,
  saveLocalUpload,
  deleteLocalUpload,
  getApiBaseUrl,
};
