/**
 * ASYNC HANDLER
 *
 * The problem this solves:
 * Without this, every async route handler needs its own try/catch block.
 * That's repetitive and easy to forget — causing unhandled promise rejections.
 *
 * With this wrapper, any unhandled error in a controller automatically
 * gets passed to Express's next() error handler middleware.
 *
 * Usage:
 *   router.get('/path', asyncHandler(async (req, res) => {
 *     // Any throw here goes to the global error handler
 *   }));
 *
 * Instead of:
 *   router.get('/path', async (req, res, next) => {
 *     try {
 *       // logic
 *     } catch (err) {
 *       next(err); // you'll forget this somewhere
 *     }
 *   });
 */

const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

module.exports = asyncHandler;
