/**
 * SPACE ROUTES
 *
 * POST   /api/spaces                     — Create a new space
 * GET    /api/spaces                     — Get all spaces I'm a member of
 * GET    /api/spaces/:id                 — Get space detail + channels
 * POST   /api/spaces/join                — Join space via invite code
 * POST   /api/spaces/:id/invite          — Regenerate invite code (admin only)
 * PUT    /api/spaces/:id                 — Update space info (admin only)
 * GET    /api/spaces/:id/members         — List members with availability
 * DELETE /api/spaces/:id/members/:userId — Remove a member (admin only)
 * POST   /api/spaces/:id/leave           — Leave a space
 */

const express = require('express');
const router = express.Router();
const { protect, requireOnboarding } = require('../../middleware/auth');
const {
  validateCreateSpace,
  validateJoinSpace,
  validateMongoId,
} = require('../../middleware/validate');

// Placeholder controller
const spaceController = require('./space.controller');

// All space routes require auth + onboarding
router.use(protect, requireOnboarding);

/**
 * @route   POST /api/spaces
 * @desc    Create a new space (department/college/community)
 * @access  Protected + Onboarded
 * @body    { name, type, description }
 *
 * On creation, the controller will:
 * 1. Generate a unique 6-char invite code
 * 2. Add creator as OWNER
 * 3. Seed 3 default channels: #general, #emergency, #academics
 * 4. Return the full space object + channels
 */
router.post('/', validateCreateSpace, spaceController.createSpace);

/**
 * @route   GET /api/spaces
 * @desc    List all spaces the current user is a member of
 * @access  Protected + Onboarded
 *
 * Returns: array of spaces, each with:
 * - Space info
 * - Channel list (with lastMessage for preview)
 * - Unread counts per channel
 * This is the data needed to render the home screen / sidebar.
 */
router.get('/', spaceController.getMySpaces);

/**
 * @route   POST /api/spaces/join
 * @desc    Join a space using a 6-character invite code
 * @access  Protected + Onboarded
 * @body    { inviteCode: "A3K7BX" }
 *
 * This is the primary onboarding flow for new users.
 * Sr. resident shares code → junior pastes it → joins the department space.
 *
 * NOTE: Must be before /:id routes to avoid 'join' being matched as a MongoDB ID
 */
router.post('/join', validateJoinSpace, spaceController.joinSpace);

/**
 * @route   GET /api/spaces/:id
 * @desc    Get full space detail with channels
 * @access  Protected + Must be a space member
 *
 * Returns:
 * - Space metadata
 * - All channels (sorted by position)
 * - Member count
 * - Caller's role in this space (member/admin/owner)
 */
router.get('/:id', validateMongoId('id'), spaceController.getSpaceById);

/**
 * @route   PUT /api/spaces/:id
 * @desc    Update space name, description, or settings
 * @access  Protected + Space Admin/Owner only
 * @body    { name?, description?, settings? }
 */
router.put('/:id', validateMongoId('id'), spaceController.updateSpace);

/**
 * @route   POST /api/spaces/:id/invite
 * @desc    Regenerate the invite code for this space
 * @access  Protected + Space Admin/Owner only
 *
 * Use case: Code was shared publicly by mistake.
 * Old code becomes invalid immediately.
 */
router.post('/:id/invite', validateMongoId('id'), spaceController.regenerateInviteCode);

/**
 * @route   GET /api/spaces/:id/members
 * @desc    List all members of a space with their availability status
 * @access  Protected + Must be a space member
 *
 * This powers the "Who's on call right now?" view.
 * Returns members sorted by: on_call → in_ot → available → off_duty
 */
router.get('/:id/members', validateMongoId('id'), spaceController.getMembers);

/**
 * @route   DELETE /api/spaces/:id/members/:userId
 * @desc    Remove a member from the space
 * @access  Protected + Space Admin/Owner only
 *
 * Admins can remove members. Owners cannot be removed (only by themselves).
 */
router.delete(
  '/:id/members/:userId',
  validateMongoId('id'),
  validateMongoId('userId'),
  spaceController.removeMember
);

/**
 * @route   POST /api/spaces/:id/leave
 * @desc    Current user leaves the space
 * @access  Protected + Must be a space member
 *
 * If the owner leaves, they must first transfer ownership or the space is archived.
 */
router.post('/:id/leave', validateMongoId('id'), spaceController.leaveSpace);

module.exports = router;
