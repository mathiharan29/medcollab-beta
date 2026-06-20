/**
 * MEDIA CONTROLLER
 *
 * Uploads to Cloudinary when configured; otherwise saves to local disk (dev/beta).
 */

const { cloudinary, isCloudinaryConfigured } = require('../../config/cloudinary');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const { saveLocalUpload, deleteLocalUpload } = require('../../utils/localMediaStorage');
const logger = require('../../utils/logger');

/**
 * POST /api/media/upload
 */
const uploadFile = asyncHandler(async (req, res) => {
  if (!req.file) {
    return respond.badRequest(res, 'No file provided');
  }

  const { context = 'message' } = req.body;
  const isImage = req.file.mimetype.startsWith('image/');
  const isPDF = req.file.mimetype === 'application/pdf';
  const userId = req.user._id.toString();

  // ── Local fallback (no Cloudinary credentials) ─────────────────────────────
  if (!isCloudinaryConfigured()) {
    const local = saveLocalUpload({
      buffer: req.file.buffer,
      mimeType: req.file.mimetype,
      originalName: req.file.originalname,
      userId,
      context,
    });

    return respond.ok(res, 'File uploaded', {
      url: local.url,
      thumbnailUrl: local.thumbnailUrl,
      publicId: local.publicId,
      fileName: req.file.originalname,
      fileSize: req.file.size,
      mimeType: req.file.mimetype,
      width: null,
      height: null,
      format: isPDF ? 'pdf' : isImage ? 'image' : null,
      storage: 'local',
    });
  }

  // ── Cloudinary upload ──────────────────────────────────────────────────────
  const folderMap = {
    message: `medcollab/messages/${userId}`,
    avatar: `medcollab/avatars/${userId}`,
    handoff: 'medcollab/handoffs',
  };
  const folder = folderMap[context] || folderMap.message;
  const dataURI = `data:${req.file.mimetype};base64,${req.file.buffer.toString('base64')}`;

  try {
    const uploadOptions = {
      folder,
      resource_type: isPDF ? 'raw' : 'image',
      eager: isImage
        ? [{ width: 400, height: 400, crop: 'limit', quality: 'auto' }]
        : [],
      eager_async: true,
      tags: [`user_${userId}`, context],
      format: isImage ? 'auto' : undefined,
      quality: isImage ? 'auto' : undefined,
    };

    const result = await cloudinary.uploader.upload(dataURI, uploadOptions);

    let thumbnailUrl = null;
    if (isImage) {
      thumbnailUrl = cloudinary.url(result.public_id, {
        width: 400,
        height: 400,
        crop: 'limit',
        quality: 'auto',
        format: 'webp',
      });
    } else if (isPDF) {
      thumbnailUrl = cloudinary.url(result.public_id, {
        resource_type: 'image',
        format: 'webp',
        width: 400,
        height: 300,
        crop: 'fill',
        page: 1,
      });
    }

    return respond.ok(res, 'File uploaded', {
      url: result.secure_url,
      thumbnailUrl,
      publicId: result.public_id,
      fileName: req.file.originalname,
      fileSize: req.file.size,
      mimeType: req.file.mimetype,
      width: result.width || null,
      height: result.height || null,
      format: result.format || null,
      storage: 'cloudinary',
    });
  } catch (err) {
    logger.error(`Cloudinary upload failed: ${err.message}`);
    return respond.serverError(res, 'File upload failed. Please try again.');
  }
});

/**
 * DELETE /api/media/:publicId
 */
const deleteFile = asyncHandler(async (req, res) => {
  const publicId = decodeURIComponent(req.params.publicId);
  const userId = req.user._id.toString();
  const ownsFile =
    publicId.includes(`/messages/${userId}/`) ||
    publicId.includes(`/avatars/${userId}/`);

  if (!ownsFile) {
    return respond.forbidden(res, 'You can only delete your own files');
  }

  if (!isCloudinaryConfigured()) {
    const deleted = deleteLocalUpload(publicId);
    return deleted
      ? respond.ok(res, 'File deleted')
      : respond.notFound(res, 'File not found');
  }

  try {
    let result = await cloudinary.uploader.destroy(publicId, { resource_type: 'image' });
    if (result.result === 'not found') {
      result = await cloudinary.uploader.destroy(publicId, { resource_type: 'raw' });
    }

    if (result.result === 'ok') {
      return respond.ok(res, 'File deleted');
    }
    return respond.notFound(res, 'File not found');
  } catch (err) {
    logger.error(`Cloudinary delete failed: ${err.message}`);
    return respond.serverError(res, 'File deletion failed');
  }
});

module.exports = { uploadFile, deleteFile };
