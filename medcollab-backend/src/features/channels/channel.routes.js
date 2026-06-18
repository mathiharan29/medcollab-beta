/**
 * CHANNEL ROUTES
 *
 * Routes are nested under spaces for group channels:
 * POST   /api/spaces/:spaceId/channels            — Create channel in a space
 * GET    /api/spaces/:spaceId/channels            — List channels in a space
 *
 * And standalone for channel-level operations:
 * GET    /api/channels/:id                        — Get channel detail
 * PUT    /api/channels/:id                        — Update channel
 * DELETE /api/channels/:id                        — Archive channel
 * POST   /api/channels/:id/messages               — (See messages.routes.js)
 * POST   /api/channels/dm                         — Create or get a DM channel
 * GET    /api/channels/:id/members                — Channel member list
 * POST   /api/channels/:id/pin/:messageId         — Pin a message
 * DELETE /api/channels/:id/pin/:messageId         — Unpin a message
 *
 * Two router files are exported:
 * - spaceChannelRouter: mounted at /api/spaces/:spaceId/channels
 * - channelRouter: mounted at /api/channels
 */

const express = require('express');
const spaceChannelRouter = express.Router({ mergeParams: true }); // Access :spaceId
const channelRouter = express.Router();

const { protect, requireOnboarding } = require('../../middleware/auth');
const { validateCreateChannel, validateMongoId } = require('../../middleware/validate');
const { body } = require('express-validator');
const { handleValidationErrors } = require('../../middleware/validate');

// Placeholder controller
const channelController = require('./channel.controller');

// ── Space-nested Channel Routes (/api/spaces/:spaceId/channels) ───────────────
spaceChannelRouter.use(protect, requireOnboarding);

/**
 * @route   POST /api/spaces/:spaceId/channels
 * @desc    Create a new channel in a space
 * @access  Protected + Space Member (or Admin depending on settings)
 * @body    { name: "radiology-rounds", description?: "...", isPrivate?: false }
 *
 * Name convention: lowercase, hyphens only (enforced by validator)
 * The controller checks if the caller is a space member before creating.
 */
spaceChannelRouter.post('/', validateCreateChannel, channelController.createChannel);

/**
 * @route   GET /api/spaces/:spaceId/channels
 * @desc    Get all channels in a space (sorted by position)
 * @access  Protected + Must be space member
 *
 * Returns channels with lastMessage preview embedded.
 * This is the primary data for rendering the channel sidebar.
 * Private channels are only returned if the caller is a member of that channel.
 */
spaceChannelRouter.get('/', channelController.getSpaceChannels);

// ── Standalone Channel Routes (/api/channels) ─────────────────────────────────
channelRouter.use(protect, requireOnboarding);

/**
 * @route   POST /api/channels/dm
 * @desc    Create a DM channel with another user, or return existing one
 * @access  Protected + Onboarded
 * @body    { userId: "recipient-user-id" }
 *
 * Idempotent: calling this twice with the same userId always returns
 * the same DM channel. No duplicate DMs ever created.
 */
channelRouter.post(
  '/dm',
  [
    body('userId').isMongoId().withMessage('Invalid user ID'),
    handleValidationErrors,
  ],
  channelController.createOrGetDM
);

/**
 * @route   GET /api/channels/:id
 * @desc    Get channel info + pinned messages
 * @access  Protected + Must be channel member (or space member for public channels)
 */
channelRouter.get('/:id', validateMongoId('id'), channelController.getChannelById);

/**
 * @route   PUT /api/channels/:id
 * @desc    Update channel name or description
 * @access  Protected + Space Admin
 */
channelRouter.put('/:id', validateMongoId('id'), channelController.updateChannel);

/**
 * @route   DELETE /api/channels/:id
 * @desc    Archive a channel (soft delete — messages are preserved)
 * @access  Protected + Space Admin
 *
 * Default channels (#general, #emergency) cannot be archived.
 * The controller enforces this.
 */
channelRouter.delete('/:id', validateMongoId('id'), channelController.archiveChannel);

/**
 * @route   GET /api/channels/:id/members
 * @desc    List members of a channel (for private channels and DMs)
 * @access  Protected + Must be channel member
 */
channelRouter.get('/:id/members', validateMongoId('id'), channelController.getChannelMembers);

/**
 * @route   POST /api/channels/:id/pin/:messageId
 * @desc    Pin a message to this channel (max 5 per channel)
 * @access  Protected + Space Admin
 */
channelRouter.post(
  '/:id/pin/:messageId',
  validateMongoId('id'),
  validateMongoId('messageId'),
  channelController.pinMessage
);

/**
 * @route   DELETE /api/channels/:id/pin/:messageId
 * @desc    Unpin a message from this channel
 * @access  Protected + Space Admin
 */
channelRouter.delete(
  '/:id/pin/:messageId',
  validateMongoId('id'),
  validateMongoId('messageId'),
  channelController.unpinMessage
);

module.exports = { spaceChannelRouter, channelRouter };
