/**
 * MEDIA ROUTES
 *
 * POST   /api/media/upload     — Upload a file, get back a Cloudinary URL
 * DELETE /api/media/:publicId  — Delete a file (when message is deleted)
 *
 * Why a dedicated upload endpoint (not inline with messages)?
 *
 * The two-step flow (upload first, then send message) is superior because:
 * 1. Upload can start while the user is still composing a caption
 * 2. If message send fails, the upload is still complete — retry is cheap
 * 3. Upload progress can be shown independently from message sending
 * 4. Reduces message send latency (no waiting for Cloudinary inside the request)
 *
 * Upload flow:
 * Flutter picks file → POST /api/media/upload → gets { url, thumbnailUrl, publicId }
 *                   → POST /api/channels/:id/messages with those URLs in content
 *
 * Security:
 * - Only authenticated users can upload
 * - File type whitelist enforced (only images + PDFs)
 * - File size limit: 25MB
 * - Rate limited: 30 uploads per hour per user
 * - Files uploaded to a user-specific Cloudinary folder
 */

const express = require('express');
const router = express.Router();
const multer = require('multer');

const { protect, requireOnboarding } = require('../../middleware/auth');
const { uploadLimiter } = require('../../middleware/rateLimiter');
const { respond } = require('../../utils/apiResponse');
const { MEDIA } = require('../../constants');

// ── Multer Configuration ──────────────────────────────────────────────────────
// multer handles multipart/form-data (file uploads)
// We use memory storage — file goes to RAM, we stream it to Cloudinary
// For a 15-user beta with 25MB limit, this is safe
// At scale: switch to disk storage or direct Cloudinary upload

const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
  if (MEDIA.ALLOWED_TYPES.includes(file.mimetype)) {
    cb(null, true); // Accept file
  } else {
    cb(
      new Error(
        `File type not allowed. Accepted: JPEG, PNG, WebP, PDF`
      ),
      false
    );
  }
};

const upload = multer({
  storage,
  limits: {
    fileSize: MEDIA.MAX_FILE_SIZE_BYTES, // 25MB
    files: 1, // One file per request
  },
  fileFilter,
});

// Placeholder controller
const mediaController = require('./media.controller');

router.use(protect, requireOnboarding);

/**
 * @route   POST /api/media/upload
 * @desc    Upload a file and get back a permanent Cloudinary URL
 * @access  Protected + Onboarded
 * @form    multipart/form-data with field 'file'
 * @body    { context: "message" | "avatar" | "handoff" }
 *
 * Returns:
 * {
 *   url: "https://res.cloudinary.com/medcollab/image/upload/v.../filename.jpg",
 *   thumbnailUrl: "https://res.cloudinary.com/.../w_400,h_300,c_fill/.../filename.jpg",
 *   publicId: "medcollab/messages/userId/filename",
 *   fileName: "ecg-strip.jpg",
 *   fileSize: 245000,
 *   mimeType: "image/jpeg",
 *   width: 1920,    (for images only)
 *   height: 1080    (for images only)
 * }
 *
 * Cloudinary folder structure:
 * medcollab/
 *   avatars/<userId>/
 *   messages/<spaceId>/
 *   handoffs/<spaceId>/
 *
 * This keeps media organised and makes bulk cleanup easy if a space is deleted.
 */
router.post(
  '/upload',
  uploadLimiter,
  upload.single('file'), // 'file' must match the field name in the multipart form
  // Multer errors (wrong type, too large) are caught by errorHandler middleware
  mediaController.uploadFile
);

/**
 * @route   DELETE /api/media/:publicId
 * @desc    Delete a file from Cloudinary
 * @access  Protected + Must own the resource
 *
 * Called when:
 * - A message containing media is deleted
 * - A user replaces their avatar
 *
 * publicId must be URL-encoded since it contains slashes:
 * DELETE /api/media/medcollab%2Fmessages%2F123%2Fecg.jpg
 *
 * The controller verifies the publicId belongs to the requesting user
 * before calling Cloudinary delete. Prevents one user deleting another's files.
 */
router.delete('/:publicId', mediaController.deleteFile);
// publicId is URL-encoded by the client (slashes become %2F)

module.exports = router;
