/**
 * PLATFORM ADMIN ROUTES
 *
 * Mounted at /api/admin
 * Requires JWT (protect) + ADMIN_USER_IDS allowlist (requirePlatformAdmin).
 */

const express = require('express');
const { body } = require('express-validator');
const { protect, requirePlatformAdmin } = require('../../middleware/auth');
const { handleValidationErrors, validateMongoId } = require('../../middleware/validate');
const adminController = require('./admin.controller');

const router = express.Router();

router.use(protect, requirePlatformAdmin);

router.get('/me', adminController.getAdminMe);
router.get('/overview', adminController.getOverview);
router.get('/users', adminController.listUsers);
router.get('/growth', adminController.getGrowth);
router.get('/retention', adminController.getRetention);
router.get('/infrastructure', adminController.getInfrastructure);

router.get('/users/:id', ...validateMongoId('id'), adminController.getUser);

router.put(
  '/users/:id/verify',
  ...validateMongoId('id'),
  body('verified')
    .optional()
    .isBoolean({ strict: false })
    .withMessage('verified must be boolean'),
  handleValidationErrors,
  adminController.setDoctorVerification
);

router.put(
  '/users/:id/deactivate',
  ...validateMongoId('id'),
  body('active')
    .optional()
    .isBoolean({ strict: false })
    .withMessage('active must be boolean'),
  handleValidationErrors,
  adminController.setUserActive
);

module.exports = router;
