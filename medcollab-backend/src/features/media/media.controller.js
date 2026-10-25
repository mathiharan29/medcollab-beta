/**
 * MEDIA CONTROLLER
 *
 * Uploads to Cloudinary when configured; otherwise saves to local disk (dev/beta).
 */

const { cloudinary, isCloudinaryConfigured } = require('../../config/cloudinary');
const User = require('../users/user.model');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const { saveLocalUpload, deleteLocalUpload } = require('../../utils/localMediaStorage');
const logger = require('../../utils/logger');
const Handoff = require('../handoffs/handoff.model');

const bumpUserStorage = (userId, deltaBytes) => {
  if (!userId || !deltaBytes) return;
  User.findByIdAndUpdate(userId, {
    $inc: { storageUsedBytes: deltaBytes },
  }).exec();
};

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

    bumpUserStorage(userId, req.file.size);

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

    bumpUserStorage(userId, req.file.size);

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
 * Normalize media public IDs and require an exact owner namespace prefix (VR-S6).
 * Rejects traversal / substring spoofing like foreign/.../messages/<me>/...
 */
const normalizeOwnedMediaPublicId = (rawPublicId, userId) => {
  let id = String(rawPublicId || '');
  try {
    id = decodeURIComponent(id);
  } catch {
    return null;
  }
  id = id.replace(/\\/g, '/').replace(/^\/+/, '');
  // Collapse redundant segments without allowing escape.
  const parts = [];
  for (const part of id.split('/')) {
    if (!part || part === '.') continue;
    if (part === '..') return null;
    parts.push(part);
  }
  const normalized = parts.join('/');
  const allowed = [
    `medcollab/messages/${userId}/`,
    `medcollab/avatars/${userId}/`,
    'medcollab/handoffs/',
  ];
  const owns = allowed.some(
    (prefix) =>
      normalized.startsWith(prefix) &&
      normalized.length > prefix.length &&
      !normalized.slice(prefix.length).includes('..')
  );
  return owns ? normalized : null;
};

const deleteStoredMedia = async (publicId) => {
  if (!isCloudinaryConfigured()) {
    return deleteLocalUpload(publicId);
  }

  for (const resourceType of ['image', 'raw', 'video']) {
    const result = await cloudinary.uploader.destroy(publicId, {
      resource_type: resourceType,
    });
    if (result.result === 'ok') return true;
    if (result.result !== 'not found') return false;
  }
  return false;
};

const clearDeletedHandoffAttachments = async (publicId) => {
  const handoffs = await Handoff.find({
    'patients.attachments.url': { $regex: `${publicId.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?:$|[?#])` },
  });

  for (const handoff of handoffs) {
    let changed = false;
    for (const patient of handoff.patients) {
      for (const attachment of patient.attachments) {
        if (!attachment.url || !attachment.url.includes(publicId)) continue;
        attachment.url = null;
        attachment.thumbnailUrl = null;
        attachment.fileName = attachment.mimeType?.startsWith('image/')
          ? 'Image deleted'
          : 'Message deleted';
        changed = true;
      }
    }
    if (changed) await handoff.save();
  }
};

const handoffAttachmentOwnedBy = (publicId, userId) =>
  Handoff.exists({
    fromUserId: userId,
    'patients.attachments.url': {
      $regex: `${publicId.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?:$|[?#])`,
    },
  });

/**
 * DELETE /api/media/:publicId
 */
const deleteFile = asyncHandler(async (req, res) => {
  const userId = req.user._id.toString();
  const publicId = normalizeOwnedMediaPublicId(req.params.publicId, userId);

  if (!publicId) {
    return respond.forbidden(res, 'You can only delete your own files');
  }
  if (
    publicId.startsWith('medcollab/handoffs/') &&
    !(await handoffAttachmentOwnedBy(publicId, req.user._id))
  ) {
    return respond.forbidden(res, 'You can only delete your own handoff files');
  }

  try {
    const deleted = await deleteStoredMedia(publicId);
    if (!deleted) return respond.notFound(res, 'File not found');
    await clearDeletedHandoffAttachments(publicId);
    return respond.ok(res, 'File deleted');
  } catch (err) {
    logger.error(`Cloudinary delete failed: ${err.message}`);
    return respond.serverError(res, 'File deletion failed');
  }
});

module.exports = {
  uploadFile,
  deleteFile,
  normalizeOwnedMediaPublicId,
  deleteStoredMedia,
};
