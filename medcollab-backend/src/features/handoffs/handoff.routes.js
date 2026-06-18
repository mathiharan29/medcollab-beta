/**
 * HANDOFF ROUTES
 *
 * POST   /api/handoffs                        — Create a draft handoff
 * GET    /api/handoffs                        — Get handoffs for me (sent + received)
 * GET    /api/handoffs/:id                    — Get a specific handoff in full detail
 * PUT    /api/handoffs/:id                    — Update a draft handoff
 * POST   /api/handoffs/:id/submit             — Submit draft → makes it visible to receiver
 * POST   /api/handoffs/:id/acknowledge        — Receiver confirms they have read it
 * DELETE /api/handoffs/:id                    — Delete a draft (cannot delete submitted)
 * GET    /api/spaces/:spaceId/handoffs        — List handoffs for a space (by date/shift)
 *
 * Two routers exported:
 * - handoffRouter:      mounted at /api/handoffs
 * - spaceHandoffRouter: mounted at /api/spaces/:spaceId/handoffs
 */

const express = require('express');
const handoffRouter = express.Router();
const spaceHandoffRouter = express.Router({ mergeParams: true });

const { protect, requireOnboarding } = require('../../middleware/auth');
const {
  validateCreateHandoff,
  validateMongoId,
} = require('../../middleware/validate');
const { body, query } = require('express-validator');
const { handleValidationErrors } = require('../../middleware/validate');

// Placeholder controller
const handoffController = require('./handoff.controller');

handoffRouter.use(protect, requireOnboarding);
spaceHandoffRouter.use(protect, requireOnboarding);

// ── /api/handoffs ─────────────────────────────────────────────────────────────

/**
 * @route   POST /api/handoffs
 * @desc    Create a new handoff (starts as DRAFT — not visible to receiver yet)
 * @access  Protected + Onboarded
 * @body    {
 *   spaceId: "...",
 *   channelId: "...",
 *   toUserId: "...",
 *   shiftDate: "2024-07-15",
 *   shiftType: "night",
 *   shiftSummary: "Quiet night overall...",
 *   patients: [
 *     {
 *       bedNumber: "7",
 *       ward: "CICU",
 *       clinicalAlias: "65M with ACS",
 *       diagnosis: "Acute Coronary Syndrome",
 *       status: "monitoring",
 *       notes: "On heparin infusion 18u/kg/hr. Repeat ECG at 2am.",
 *       pendingTasks: ["Check 2am ECG", "Review K+ at 4am"],
 *       isFlagged: true
 *     }
 *   ]
 * }
 *
 * The creator is automatically set as fromUserId.
 * Draft handoffs are only visible to the creator.
 */
handoffRouter.post('/', validateCreateHandoff, handoffController.createHandoff);

/**
 * @route   GET /api/handoffs
 * @desc    Get handoffs relevant to me
 * @access  Protected + Onboarded
 * @query   {
 *   type: "sent" | "received" | "all",  (default: "all")
 *   status: "draft" | "submitted" | "acknowledged",
 *   spaceId: "<optional filter>",
 *   date: "2024-07-15"  (ISO date, optional)
 * }
 *
 * "received" tab: handoffs where toUserId === me AND status = submitted/acknowledged
 * "sent" tab: handoffs where fromUserId === me (all statuses)
 * This powers the Handoffs screen — the inbox view for incoming handoffs.
 */
handoffRouter.get('/', handoffController.getMyHandoffs);

/**
 * @route   GET /api/handoffs/:id
 * @desc    Get full handoff detail
 * @access  Protected + Must be sender OR receiver
 *
 * Returns the full handoff with all patients expanded.
 * The controller enforces that only fromUser or toUser can view.
 */
handoffRouter.get('/:id', validateMongoId('id'), handoffController.getHandoffById);

/**
 * @route   PUT /api/handoffs/:id
 * @desc    Update a DRAFT handoff (add/edit/remove patients, update summary)
 * @access  Protected + Must be the sender + handoff must be in DRAFT status
 *
 * Once submitted, a handoff CANNOT be edited.
 * This is intentional — the acknowledgement creates a point-in-time record.
 * If correction is needed, create a new handoff.
 */
handoffRouter.put('/:id', validateMongoId('id'), handoffController.updateHandoff);

/**
 * @route   POST /api/handoffs/:id/submit
 * @desc    Submit a draft handoff — makes it visible to the receiver
 * @access  Protected + Must be the sender + must be in DRAFT status
 *
 * After submission:
 * 1. Status changes: DRAFT → SUBMITTED
 * 2. submittedAt is set
 * 3. Push notification sent to toUser: "Dr. Priya has sent you a handoff"
 * 4. In-app notification created for toUser
 * 5. System message posted in the linked channel:
 *    "Dr. Priya submitted a handoff to Dr. Arjun for Night shift [View →]"
 */
handoffRouter.post('/:id/submit', validateMongoId('id'), handoffController.submitHandoff);

/**
 * @route   POST /api/handoffs/:id/acknowledge
 * @desc    Receiver acknowledges they have read the handoff
 * @access  Protected + Must be the receiver + handoff must be SUBMITTED
 * @body    { note: "Noted. Will check on CICU Bed 7 immediately." }
 *
 * After acknowledgement:
 * 1. Status changes: SUBMITTED → ACKNOWLEDGED
 * 2. acknowledgedAt is set
 * 3. acknowledgementNote saved
 * 4. Notification sent back to the sender: "Dr. Arjun acknowledged your handoff"
 * 5. System message updated in channel to show "✓ Acknowledged"
 *
 * This is the legally significant moment — a digital record that
 * patient responsibility was formally transferred.
 */
handoffRouter.post(
  '/:id/acknowledge',
  validateMongoId('id'),
  [
    body('note').optional().trim().isLength({ max: 500 })
      .withMessage('Acknowledgement note cannot exceed 500 characters'),
    handleValidationErrors,
  ],
  handoffController.acknowledgeHandoff
);

/**
 * @route   DELETE /api/handoffs/:id
 * @desc    Delete a DRAFT handoff
 * @access  Protected + Must be the sender + must be in DRAFT status
 *
 * Cannot delete submitted or acknowledged handoffs — medical audit trail.
 */
handoffRouter.delete('/:id', validateMongoId('id'), handoffController.deleteHandoff);

// ── /api/spaces/:spaceId/handoffs ─────────────────────────────────────────────

/**
 * @route   GET /api/spaces/:spaceId/handoffs
 * @desc    List handoffs for a space (admin/historical view)
 * @access  Protected + Must be space member
 * @query   {
 *   date: "2024-07-15",           (filter by specific date)
 *   shiftType: "night",           (filter by shift)
 *   fromUserId: "...",            (filter by sender)
 *   status: "acknowledged",       (filter by status)
 *   limit: 20,
 *   before: "<handoffId>"         (cursor pagination)
 * }
 *
 * Use case: An HOD wants to review all handoffs from last week.
 * Or a resident wants to see what was handed off on their last night shift.
 * This is the "audit trail" view — the killer feature that no other tool offers.
 */
spaceHandoffRouter.get('/', handoffController.getSpaceHandoffs);

module.exports = { handoffRouter, spaceHandoffRouter };
