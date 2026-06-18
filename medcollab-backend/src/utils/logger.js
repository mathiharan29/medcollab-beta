/**
 * LOGGER
 *
 * Why not just console.log?
 * - console.log has no log levels (you can't filter errors from debug info)
 * - In production (Railway), you want structured output you can search
 * - This logger prefixes every line with timestamp + level
 * - In dev: colourised output in terminal
 * - In prod: plain text (Railway parses it)
 *
 * We keep this simple on purpose. Morgan handles HTTP request logging.
 * This handles app-level events (DB connection, socket events, errors).
 */

const isDev = process.env.NODE_ENV !== 'production';

// ANSI colour codes for terminal
const colours = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  green: '\x1b[32m',
  blue: '\x1b[34m',
  grey: '\x1b[90m',
};

const timestamp = () => new Date().toISOString();

const logger = {
  info: (message, meta = '') => {
    const colour = isDev ? colours.green : '';
    const reset = isDev ? colours.reset : '';
    console.log(`${colour}[${timestamp()}] INFO: ${message}${reset}`, meta || '');
  },

  warn: (message, meta = '') => {
    const colour = isDev ? colours.yellow : '';
    const reset = isDev ? colours.reset : '';
    console.warn(`${colour}[${timestamp()}] WARN: ${message}${reset}`, meta || '');
  },

  error: (message, meta = '') => {
    const colour = isDev ? colours.red : '';
    const reset = isDev ? colours.reset : '';
    console.error(`${colour}[${timestamp()}] ERROR: ${message}${reset}`, meta || '');
  },

  debug: (message, meta = '') => {
    if (!isDev) return; // Never log debug in production
    console.log(`${colours.grey}[${timestamp()}] DEBUG: ${message}${colours.reset}`, meta || '');
  },

  socket: (event, meta = '') => {
    if (!isDev) return;
    console.log(`${colours.blue}[${timestamp()}] SOCKET: ${event}${colours.reset}`, meta || '');
  },
};

module.exports = logger;
