/**
 * MESSAGE ROUTES
 *
 * Messages are always in the context of a channel:
 *
 * GET    /api/channels/:channelId/messages              — Fetch messages (paginated)
 * POST   /api/channels/:channelId/messages              — Send a text message
 * GET    /api/channels/:channelId/messages/:id/thread   — Get thread replies
 * POST   /api/channels/:channelId/messages/:id/reply    — Reply in thread
 * PUT    /api/channels/:channelId/messages/:id          — Edit a message
 * DELETE /api/channels/:channelId/messages/:id          — Soft-delete a message
 * POST   /api/channels/:channelId/messages/:id/react    — Toggle a reaction
 * POST   /api/channels/:channelId/messages/read         — Mark messages as read
 *
 * Why channel-scoped routes?
 * Every message belongs to a channel. Channel-scoped URLs make access control
 * natural: "is this user allowed in this channel?" is checked once per request.
 * It also means the client always knows which channel a message belongs to.
 *
 * Note: Media upload is a separate route in media.routes.js
 * The flow for sending an image:
 * 1. POST /api/media/upload → returns { url, thumbnailUrl }
 * 2. POST /api/channels/:id/messages with type: "image" and content.mediaUrl
 * Why split? The upload can start before the user finishes typing the caption.
 */

const express = require('express');
// mergeParams: true allows access to :channelId from the parent router
const router = express.Router({ mergeParams: true });

const { protect, requireOnboarding } = require('../../middleware/auth');
const {
  validateSendMessage,
  validateMongoId,
  validatePagination,
} = require('../../middleware/validate');
const { body } = require('express-validator');
const { handleValidationErrors } = require('../../middleware/validate');

// Placeholder controller
const messageController = require('./message.controller');

router.use(protect, requireOnboarding);

/**
 * @route   GET /api/channels/:channelId/messages
 * @desc    Fetch messages in a channel (cursor-based, newest first)
 * @access  Protected + Channel member
 * @query   { before: "<messageId>", limit: 30 }
 *
 * Cursor pagination:
 * - First load: no `before` param → returns the 30 most recent messages
 * - Load older: pass `before=<oldest message id in current view>`
 * - Returns: { messages: [...], hasMore: true/false }
 *
 * Messages are returned in ASCENDING order (oldest→newest) for rendering.
 * The query fetches in descending order then reverses — so the client
 * renders them naturally top-to-bottom.
 */
router.get('/', validatePagination, messageController.getMessages);

/**
 * @route   POST /api/channels/:channelId/messages
 * @desc    Send a message to a channel
 * @access  Protected + Channel member
 * @body    {
 *            type: "text",
 *            content: { text: "ECG looks normal" },
 *            priority: "normal",
 *            threadId: null,  // Set if replying in a thread
 *            mentions: ["userId1", "userId2"]
 *          }
 *
 * For media messages (image/document/ecg):
 * @body    {
 *            type: "image",
 *            content: {
 *              mediaUrl: "https://res.cloudinary.com/...",
 *              thumbnailUrl: "https://res.cloudinary.com/.../thumb",
 *              fileName: "ecg-strip.jpg",
 *              fileSize: 245000,
 *              mimeType: "image/jpeg"
 *            }
 *          }
 *
 * After saving, the controller:
 * 1. Emits `new_message` socket event to the channel room
 * 2. Updates Channel.lastMessage (for sidebar preview)
 * 3. Sends FCM push to offline channel members
 * 4. Creates Notification documents for @mentioned users
 */
router.post('/', validateSendMessage, messageController.sendMessage);

/**
 * @route   GET /api/channels/:channelId/messages/:id/thread
 * @desc    Fetch all replies in a message thread
 * @access  Protected + Channel member
 * @query   { limit: 30, before: "<messageId>" }
 *
 * Returns the root message + all replies (chronological order).
 */
router.get(
  '/:id/thread',
  validateMongoId('id'),
  validatePagination,
  messageController.getThread
);

/**
 * @route   POST /api/channels/:channelId/messages/:id/reply
 * @desc    Reply to a message thread
 * @access  Protected + Channel member
 * @body    Same as send message, but threadId is set automatically from :id
 *
 * After saving:
 * 1. Increment root message's replyCount
 * 2. Update root message's lastReply snapshot
 * 3. Emit `new_message` socket event to channel room (with threadId set)
 * 4. Notify the original message author + thread participants
 */
router.post(
  '/:id/reply',
  validateMongoId('id'),
  validateSendMessage,
  messageController.replyToThread
);

/**
 * @route   PUT /api/channels/:channelId/messages/:id
 * @desc    Edit a message's text content
 * @access  Protected + Must be the message sender
 * @body    { content: { text: "corrected message" } }
 *
 * Rules enforced in controller:
 * - Only the sender can edit their own message
 * - Cannot edit media messages (only text)
 * - Sets isEdited: true, editedAt: now
 * - Emits `message_updated` socket event
 */
router.put(
  '/:id',
  validateMongoId('id'),
  [
    body('content.text')
      .trim()
      .notEmpty().withMessage('Edited message cannot be empty')
      .isLength({ max: 4000 }).withMessage('Message cannot exceed 4000 characters'),
    handleValidationErrors,
  ],
  messageController.editMessage
);

/**
 * @route   DELETE /api/channels/:channelId/messages/:id
 * @desc    Soft-delete a message
 * @access  Protected + Sender (own messages) OR Space Admin (any message)
 *
 * Does NOT remove the document from MongoDB.
 * Sets isDeleted: true, blanks content, emits `message_deleted` socket event.
 * Client shows "This message was deleted" placeholder.
 */
router.delete('/:id', validateMongoId('id'), messageController.deleteMessage);

/**
 * @route   POST /api/channels/:channelId/messages/:id/react
 * @desc    Toggle an emoji reaction on a message
 * @access  Protected + Channel member
 * @body    { emoji: "👍" }
 *
 * Toggle behaviour:
 * - If user hasn't reacted with this emoji: add their userId
 * - If user already reacted with this emoji: remove their userId
 * - If removing leaves the emoji with 0 users: remove the reaction entirely
 */
router.post(
  '/:id/react',
  validateMongoId('id'),
  [
    body('emoji').notEmpty().withMessage('Emoji is required'),
    handleValidationErrors,
  ],
  messageController.toggleReaction
);

/**
 * @route   POST /api/channels/:channelId/messages/read
 * @desc    Mark messages as read (for DMs — updates read receipts)
 * @access  Protected + Channel member
 * @body    { messageIds: ["id1", "id2"] }
 *
 * Only meaningful for DM channels.
 * For group channels, we track reads at the channel level (lastReadAt),
 * not per-message.
 */
router.post(
  '/read',
  [
    body('messageIds').isArray().withMessage('messageIds must be an array'),
    handleValidationErrors,
  ],
  messageController.markAsRead
);

module.exports = router;
