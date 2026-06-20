/**
 * Escape user input before embedding in MongoDB $regex / JavaScript RegExp.
 */
const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

module.exports = escapeRegex;
