/**
 * GLOBAL ERROR HANDLER
 *
 * This is Express's error-handling middleware (4 arguments: err, req, res, next).
 * It catches any error passed to next(err) or thrown inside asyncHandler.
 *
 * Without this, unhandled errors would:
 * - Crash the server in some cases
 * - Send raw stack traces to the client (security risk)
 * - Return inconsistent error shapes
 *
 * Error types we handle:
 * 1. Mongoose ValidationError — bad data sent to a model
 * 2. Mongoose CastError — invalid ObjectId format
 * 3. MongoDB duplicate key (code 11000) — e.g. phone already registered
 * 4. JWT errors — handled in auth middleware, but caught here as fallback
 * 5. Multer errors — file upload issues
 * 6. Generic errors — everything else
 *
 * In production: never send stack traces to the client.
 * In development: include the stack for easier debugging.
 */

const logger = require('../utils/logger');
const { sendError } = require('../utils/apiResponse');

const errorHandler = (err, req, res, next) => {
  // Log every error server-side (always)
  logger.error(`${err.name}: ${err.message}`, {
    path: req.path,
    method: req.method,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
  });

  // Default error values
  let statusCode = err.statusCode || 500;
  let message = err.message || 'Internal server error';
  let errors = [];

  // ── Mongoose Validation Error ───────────────────────────────────────────
  // Triggered when a document fails schema validation (required fields, maxlength, etc.)
  if (err.name === 'ValidationError') {
    statusCode = 400;
    message = 'Validation failed';
    errors = Object.values(err.errors).map((e) => ({
      field: e.path,
      message: e.message,
    }));
  }

  // ── Mongoose Cast Error ────────────────────────────────────────────────
  // Triggered when an invalid ObjectId is passed: e.g. /spaces/not-a-real-id
  else if (err.name === 'CastError') {
    statusCode = 400;
    message = `Invalid ${err.path}: ${err.value}`;
  }

  // ── MongoDB Duplicate Key ──────────────────────────────────────────────
  // Triggered when a unique field (like phone number) already exists
  else if (err.code === 11000) {
    statusCode = 409;
    const field = Object.keys(err.keyValue)[0];
    const value = err.keyValue[field];
    message = `${field} '${value}' is already registered`;
  }

  // ── JWT Errors (fallback) ──────────────────────────────────────────────
  else if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    message = 'Invalid token';
  } else if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    message = 'Token has expired';
  }

  // ── Multer File Size Error ─────────────────────────────────────────────
  else if (err.code === 'LIMIT_FILE_SIZE') {
    statusCode = 400;
    message = `File too large. Maximum size is ${process.env.MAX_FILE_SIZE_MB || 25}MB`;
  }

  // In production, don't leak internal error details for 500s
  if (statusCode === 500 && process.env.NODE_ENV === 'production') {
    message = 'Something went wrong. Please try again.';
  }

  return sendError(res, statusCode, message, errors);
};

/**
 * 404 handler — attach this AFTER all routes to catch unmatched paths
 */
const notFoundHandler = (req, res, next) => {
  const error = new Error(`Route not found: ${req.method} ${req.originalUrl}`);
  error.statusCode = 404;
  next(error);
};

module.exports = { errorHandler, notFoundHandler };
