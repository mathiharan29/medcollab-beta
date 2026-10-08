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

const uploadBufferToCloudinary = (buffer, options) =>
  new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(options, (error, result) => {
      if (error) reject(error);
      else resolve(result);
    });
    stream.end(buffer);
  });

/**
 * POST /api/media/upload
 */
const uploadFile = asyncHandler(async (req, res) => {
  if (!req.file) {
    return respond.badRequest(res, 'No file provided');
  }

  const { context = 'message' } = req.body;
  const mime = (req.file.mimetype || '').toLowerCase();
  const original = (req.file.originalname || '').toLowerCase();
  const isOctet = mime === 'application/octet-stream' || mime === 'binary/octet-stream';
  const isPDF =
    mime === 'application/pdf' || (isOctet && original.endsWith('.pdf'));
  const isVideo =
    mime.startsWith('video/') ||
    (isOctet &&
      ['.mp4', '.mov', '.webm', '.mkv', '.m4v'].some((ext) =>
        original.endsWith(ext)
      ));
  const isImage =
    !isPDF &&
    !isVideo &&
    (mime.startsWith('image/') ||
      (isOctet &&
        ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic'].some((ext) =>
          original.endsWith(ext)
        )));
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
      format: isPDF ? 'pdf' : isVideo ? 'video' : isImage ? 'image' : null,
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

  try {
    // Keep original name (sanitized) so downloads aren't random public_ids.
    const rawName = (req.file.originalname || 'file').replace(/[^\w.\-() ]+/g, '_');
    const baseName = rawName.replace(/\.[^.]+$/, '') || 'file';

    const uploadOptions = {
      folder,
      resource_type: isPDF ? 'raw' : isVideo ? 'video' : 'image',
      use_filename: true,
      unique_filename: true,
      filename_override: baseName.slice(0, 100),
    };

    const result = await uploadBufferToCloudinary(req.file.buffer, uploadOptions);

    let thumbnailUrl = null;
    let deliveryUrl = result.secure_url;
    if (isImage) {
      thumbnailUrl = cloudinary.url(result.public_id, {
        width: 400,
        height: 400,
        crop: 'limit',
        quality: 'auto',
        format: 'webp',
      });
    } else if (isVideo) {
      thumbnailUrl = cloudinary.url(result.public_id, {
        resource_type: 'video',
        format: 'jpg',
        start_offset: '0',
        width: 400,
        crop: 'limit',
        secure: true,
      });
    } else if (isPDF) {
      // Raw secure_url downloads reliably; fl_attachment:name often breaks clients
      // into the Cloudinary error portal (VR-CLOUDINARY-PDF-ATTACHMENT).
      deliveryUrl = result.secure_url;
      thumbnailUrl = null;
    }

    return respond.ok(res, 'File uploaded', {
      url: deliveryUrl,
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
