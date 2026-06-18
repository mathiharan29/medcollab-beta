/**
 * MEDIA CONTROLLER
 *
 * Handles file upload to Cloudinary and deletion.
 * Files arrive via multer (memory storage) as req.file.buffer.
 * We stream the buffer to Cloudinary — no temp files on disk.
 */

const { cloudinary } = require('../../config/cloudinary');
const { respond } = require('../../utils/apiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const { MEDIA } = require('../../constants');
const logger = require('../../utils/logger');

/**
 * POST /api/media/upload
 * Upload a file and return the Cloudinary URLs
 */
const uploadFile = asyncHandler(async (req, res) => {
  if (!req.file) {
    return respond.badRequest(res, 'No file provided');
  }

  const { context = 'message' } = req.body;
  const isImage = req.file.mimetype.startsWith('image/');
  const isPDF   = req.file.mimetype === 'application/pdf';

  // Build the Cloudinary folder path
  // Keeps media organised and makes bulk cleanup possible
  const folderMap = {
    message: `medcollab/messages/${req.user._id}`,
    avatar:  `medcollab/avatars/${req.user._id}`,
    handoff: `medcollab/handoffs`,
  };
  const folder = folderMap[context] || folderMap.message;

  // Convert buffer to base64 data URI for Cloudinary upload
  const dataURI = `data:${req.file.mimetype};base64,${req.file.buffer.toString('base64')}`;

  try {
    const uploadOptions = {
      folder,
      resource_type: isPDF ? 'raw' : 'image',
      // For images: generate a thumbnail transformation
      // Cloudinary applies these on-the-fly — no storage cost for variants
      eager: isImage
        ? [{ width: 400, height: 400, crop: 'limit', quality: 'auto' }]
        : [],
      eager_async: true,
      // Tag for cleanup queries (e.g. delete all media from a user)
      tags: [`user_${req.user._id}`, context],
      // Auto-format and auto-quality for images (saves ~30% bandwidth)
      format: isImage ? 'auto' : undefined,
      quality: isImage ? 'auto' : undefined,
    };

    const result = await cloudinary.uploader.upload(dataURI, uploadOptions);

    // Build thumbnail URL
    // For images: use Cloudinary's URL transformation
    // For PDFs: use a generated preview image
    let thumbnailUrl = null;
    if (isImage) {
      thumbnailUrl = cloudinary.url(result.public_id, {
        width: 400,
        height: 400,
        crop: 'limit',
        quality: 'auto',
        format: 'webp',  // WebP is 25-35% smaller than JPEG
      });
    } else if (isPDF) {
      // Cloudinary can generate a PNG preview of the first PDF page
      thumbnailUrl = cloudinary.url(result.public_id, {
        resource_type: 'image',  // Auto-convert PDF page to image
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
    });

  } catch (err) {
    logger.error(`Cloudinary upload failed: ${err.message}`);
    return respond.serverError(res, 'File upload failed. Please try again.');
  }
});

/**
 * DELETE /api/media/:publicId
 * Delete a file from Cloudinary
 * publicId is URL-encoded by the client
 */
const deleteFile = asyncHandler(async (req, res) => {
  const publicId = decodeURIComponent(req.params.publicId);

  // Security: only allow deletion of files owned by this user
  // publicId format: medcollab/messages/<userId>/filename
  // OR:              medcollab/avatars/<userId>/filename
  const userId = req.user._id.toString();
  const ownsFile =
    publicId.includes(`/messages/${userId}/`) ||
    publicId.includes(`/avatars/${userId}/`);

  if (!ownsFile) {
    return respond.forbidden(res, 'You can only delete your own files');
  }

  try {
    // Try image first, then raw (for PDFs)
    let result = await cloudinary.uploader.destroy(publicId, { resource_type: 'image' });
    if (result.result === 'not found') {
      result = await cloudinary.uploader.destroy(publicId, { resource_type: 'raw' });
    }

    if (result.result === 'ok') {
      return respond.ok(res, 'File deleted');
    } else {
      return respond.notFound(res, 'File not found');
    }
  } catch (err) {
    logger.error(`Cloudinary delete failed: ${err.message}`);
    return respond.serverError(res, 'File deletion failed');
  }
});

module.exports = { uploadFile, deleteFile };
