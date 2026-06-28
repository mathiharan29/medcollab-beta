/**
 * VALIDATION MIDDLEWARE
 *
 * All input validation rules live here.
 * We use express-validator — it provides a clean, chainable API
 * and integrates naturally with Express middleware.
 *
 * Pattern:
 * 1. Define a validation chain (array of check() rules)
 * 2. Call handleValidationErrors at the end to collect + respond
 *
 * Why validate at the route layer (not the model layer)?
 * Mongoose validation fires at save() time — meaning we've already
 * hit the database before knowing the input is bad.
 * Route-level validation rejects bad requests before any DB work.
 * Mongoose validation is a safety net — both layers protect us.
 */

const { body, param, query, validationResult } = require('express-validator');
const { respond } = require('../utils/apiResponse');
const { USER_ROLES, SPACE_TYPES, SHIFT_TYPES, AVAILABILITY_STATUS } = require('../constants');

/**
 * Checks the result of validation chains and returns 400 if any fail
 * Always put this as the LAST item in a route's middleware array
 */
const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return respond.badRequest(
      res,
      'Validation failed',
      errors.array().map((e) => ({ field: e.path, message: e.msg }))
    );
  }
  next();
};

// ── Auth Validations ──────────────────────────────────────────────────────────

const validateRequestOtp = [
  body('phone')
    .trim()
    .notEmpty().withMessage('Phone number is required')
    .matches(/^\+[1-9]\d{6,14}$/).withMessage('Phone must include country code (e.g. +919876543210)'),
  handleValidationErrors,
];

const validateVerifyOtp = [
  body('phone')
    .trim()
    .notEmpty().withMessage('Phone number is required')
    .matches(/^\+[1-9]\d{6,14}$/).withMessage('Invalid phone number format'),
  body('otp')
    .trim()
    .notEmpty().withMessage('OTP is required')
    .isLength({ min: 6, max: 6 }).withMessage('OTP must be 6 digits')
    .isNumeric().withMessage('OTP must contain only digits'),
  handleValidationErrors,
];

const validateVerifyMsg91Token = [
  body('phone')
    .trim()
    .notEmpty().withMessage('Phone number is required')
    .matches(/^\+[1-9]\d{6,14}$/).withMessage('Invalid phone number format'),
  body('accessToken')
    .trim()
    .notEmpty().withMessage('Access token is required'),
  handleValidationErrors,
];

const validateUpdateProfile = [
  body('name')
    .optional()
    .trim()
    .isLength({ min: 2, max: 100 }).withMessage('Name must be 2–100 characters'),
  body('role')
    .optional()
    .isIn(Object.values(USER_ROLES)).withMessage('Invalid role'),
  body('speciality')
    .optional()
    .trim()
    .isLength({ max: 100 }).withMessage('Speciality cannot exceed 100 characters'),
  body('pgYear')
    .optional()
    .isInt({ min: 1, max: 6 }).withMessage('PG year must be between 1 and 6'),
  body('institution')
    .optional()
    .trim()
    .isLength({ max: 200 }).withMessage('Institution name too long'),
  body('bio')
    .optional()
    .trim()
    .isLength({ max: 300 }).withMessage('Bio cannot exceed 300 characters'),
  handleValidationErrors,
];

// ── Space Validations ─────────────────────────────────────────────────────────

const validateCreateSpace = [
  body('name')
    .trim()
    .notEmpty().withMessage('Space name is required')
    .isLength({ min: 2, max: 100 }).withMessage('Name must be 2–100 characters'),
  body('type')
    .notEmpty().withMessage('Space type is required')
    .isIn(Object.values(SPACE_TYPES)).withMessage('Invalid space type'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 300 }).withMessage('Description cannot exceed 300 characters'),
  handleValidationErrors,
];

const validateJoinSpace = [
  body('inviteCode')
    .trim()
    .notEmpty().withMessage('Invite code is required')
    .isLength({ min: 6, max: 6 }).withMessage('Invite code must be 6 characters')
    .isAlphanumeric().withMessage('Invite code must be alphanumeric'),
  handleValidationErrors,
];

// ── Channel Validations ───────────────────────────────────────────────────────

const validateCreateChannel = [
  body('name')
    .trim()
    .notEmpty().withMessage('Channel name is required')
    .isLength({ min: 1, max: 80 }).withMessage('Name must be 1–80 characters')
    .matches(/^[a-z0-9-]+$/).withMessage('Channel name must be lowercase letters, numbers, or hyphens'),
  body('description')
    .optional()
    .trim()
    .isLength({ max: 200 }).withMessage('Description cannot exceed 200 characters'),
  handleValidationErrors,
];

// ── Message Validations ───────────────────────────────────────────────────────

const validateSendMessage = [
  body('type')
    .optional()
    .isIn(['text', 'image', 'document', 'ecg']).withMessage('Invalid message type'),
  body('content.text')
    .if(body('type').equals('text'))
    .trim()
    .notEmpty().withMessage('Message text cannot be empty')
    .isLength({ max: 4000 }).withMessage('Message cannot exceed 4000 characters'),
  body('priority')
    .optional()
    .isIn(['normal', 'urgent', 'emergency']).withMessage('Invalid priority level'),
  body('threadId')
    .optional()
    .isMongoId().withMessage('Invalid thread ID'),
  handleValidationErrors,
];

// ── Handoff Validations ───────────────────────────────────────────────────────

const validateCreateHandoff = [
  body('toUserId')
    .notEmpty().withMessage('Recipient is required')
    .isMongoId().withMessage('Invalid recipient ID'),
  body('shiftDate')
    .notEmpty().withMessage('Shift date is required')
    .isISO8601().withMessage('Invalid date format'),
  body('shiftType')
    .notEmpty().withMessage('Shift type is required')
    .isIn(Object.values(SHIFT_TYPES)).withMessage('Invalid shift type'),
  body('patients')
    .optional()
    .isArray().withMessage('Patients must be an array'),
  body('patients.*.bedNumber')
    .if(body('patients').exists())
    .notEmpty().withMessage('Bed number is required for each patient'),
  body('patients.*.clinicalAlias')
    .if(body('patients').exists())
    .notEmpty().withMessage('Clinical alias is required for each patient'),
  handleValidationErrors,
];

// ── Common Validations ────────────────────────────────────────────────────────

const validateMongoId = (paramName = 'id') => [
  param(paramName)
    .isMongoId().withMessage(`Invalid ${paramName}`),
  handleValidationErrors,
];

const validatePagination = [
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 }).withMessage('Limit must be between 1 and 100'),
  query('before')
    .optional()
    .isMongoId().withMessage('Invalid cursor'),
  handleValidationErrors,
];

const validateAvailability = [
  body('status')
    .notEmpty().withMessage('Status is required')
    .isIn(Object.values(AVAILABILITY_STATUS)).withMessage('Invalid availability status'),
  body('note')
    .optional()
    .trim()
    .isLength({ max: 100 }).withMessage('Note cannot exceed 100 characters'),
  handleValidationErrors,
];

module.exports = {
  handleValidationErrors,
  validateRequestOtp,
  validateVerifyOtp,
  validateVerifyMsg91Token,
  validateUpdateProfile,
  validateCreateSpace,
  validateJoinSpace,
  validateCreateChannel,
  validateSendMessage,
  validateCreateHandoff,
  validateMongoId,
  validatePagination,
  validateAvailability,
};
