const express = require('express');
const { protect, requireOnboarding } = require('../../middleware/auth');
const controller = require('./assistant.controller');

const router = express.Router();
router.use(protect, requireOnboarding);

/** @route GET /api/assistant/capabilities — is the AI (Claude) half configured? */
router.get('/capabilities', controller.capabilities);

/** @route POST /api/assistant/interpret — sentence → PROPOSED actions (never executed here) */
router.post('/interpret', controller.interpret);

module.exports = router;
