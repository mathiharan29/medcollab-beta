/**
 * API RESPONSE HELPER
 *
 * Why this exists:
 * Every API response in this app follows the same shape.
 * This prevents inconsistency where one route returns { data: ... }
 * and another returns { result: ... } — which would break the Flutter app.
 *
 * Every successful response: { success: true, message: '...', data: {...} }
 * Every error response:      { success: false, message: '...', errors: [...] }
 *
 * The Flutter app can always check response.success to know what happened.
 */

/**
 * Send a success response
 * @param {Object} res - Express response object
 * @param {number} statusCode - HTTP status code (200, 201, etc.)
 * @param {string} message - Human-readable success message
 * @param {Object} data - The actual payload
 */
const sendSuccess = (res, statusCode = 200, message = 'Success', data = {}) => {
  return res.status(statusCode).json({
    success: true,
    message,
    data,
  });
};

/**
 * Send an error response
 * @param {Object} res - Express response object
 * @param {number} statusCode - HTTP status code (400, 401, 404, 500, etc.)
 * @param {string} message - Human-readable error message
 * @param {Array}  errors - Optional array of validation errors
 */
const sendError = (res, statusCode = 500, message = 'Something went wrong', errors = []) => {
  return res.status(statusCode).json({
    success: false,
    message,
    errors,
  });
};

/**
 * Common HTTP responses as shortcuts
 */
const respond = {
  ok: (res, message, data) => sendSuccess(res, 200, message, data),
  created: (res, message, data) => sendSuccess(res, 201, message, data),

  badRequest: (res, message, errors) => sendError(res, 400, message, errors),
  unauthorized: (res, message = 'Unauthorized') => sendError(res, 401, message),
  forbidden: (res, message = 'Forbidden') => sendError(res, 403, message),
  notFound: (res, message = 'Not found') => sendError(res, 404, message),
  conflict: (res, message) => sendError(res, 409, message),
  tooManyRequests: (res, message = 'Too many requests') => sendError(res, 429, message),
  serverError: (res, message = 'Internal server error') => sendError(res, 500, message),
};

module.exports = { sendSuccess, sendError, respond };
