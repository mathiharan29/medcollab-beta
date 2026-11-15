/**
 * Vocle ID = unique @username (REQ 5).
 *
 * Every onboarded doctor gets one automatically from their name
 * ("Dr Asha Rao" → "asharao", then "asharao2", …). They can change it in
 * Edit profile; uniqueness is enforced by the sparse unique index on
 * User.vocleUsername. Existing accounts are backfilled once at startup.
 */

const User = require('../features/users/user.model');
const logger = require('./logger');

const USERNAME_RE = /^[a-z0-9_]{3,30}$/;
const TITLES = new Set(['dr', 'prof', 'mr', 'mrs', 'ms', 'miss', 'sr', 'sri', 'smt']);
// Handles that would confuse people or impersonate the product.
const RESERVED = new Set([
  'admin', 'administrator', 'vocle', 'medcollab', 'support', 'help',
  'system', 'everyone', 'here', 'channel', 'team', 'official', 'root',
  'null', 'undefined', 'me', 'you',
]);

function normalizeUsername(raw) {
  return String(raw || '').trim().replace(/^@/, '').toLowerCase();
}

/** null when fine, otherwise a reason the user can read. */
function usernameProblem(raw) {
  const u = normalizeUsername(raw);
  if (!USERNAME_RE.test(u)) {
    return 'Username must be 3–30 letters, numbers or underscore';
  }
  if (RESERVED.has(u)) return 'That username is reserved';
  if (/^\d+$/.test(u)) return 'Username must include a letter';
  return null;
}

function baseFromName(name) {
  const words = String(name || '')
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((w) => w && !TITLES.has(w));
  let base = words.join('').slice(0, 24);
  if (base.length < 3) base = `${base}doc`.slice(0, 24);
  if (RESERVED.has(base) || /^\d+$/.test(base)) base = `dr${base}`.slice(0, 24);
  return base;
}

async function isUsernameTaken(username, exceptUserId = null) {
  const q = { vocleUsername: normalizeUsername(username) };
  if (exceptUserId) q._id = { $ne: exceptUserId };
  return Boolean(await User.exists(q));
}

/** First free handle for a name: asharao, asharao2, asharao3, … */
async function generateUsername(name) {
  const base = baseFromName(name);
  if (!(await isUsernameTaken(base))) return base;
  for (let n = 2; n < 10000; n += 1) {
    const candidate = `${base.slice(0, 30 - String(n).length)}${n}`;
    if (!(await isUsernameTaken(candidate))) return candidate;
  }
  return `${base.slice(0, 22)}${Date.now().toString(36).slice(-8)}`;
}

/**
 * Give `user` a username if it has none. Retries on the rare race where two
 * doctors with the same name onboard at once (unique index → E11000).
 */
async function ensureUsername(user) {
  if (!user || user.vocleUsername || !user.name) return user?.vocleUsername || null;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const candidate = await generateUsername(user.name);
    try {
      const res = await User.updateOne(
        { _id: user._id, vocleUsername: null },
        { $set: { vocleUsername: candidate } }
      );
      if (res.modifiedCount === 1) {
        user.vocleUsername = candidate;
        return candidate;
      }
      // Someone else set it meanwhile.
      const fresh = await User.findById(user._id).select('vocleUsername').lean();
      return fresh?.vocleUsername || null;
    } catch (err) {
      if (err.code !== 11000) throw err;
    }
  }
  return null;
}

/** One-off, idempotent: onboarded doctors without a handle get one. */
async function backfillUsernames({ batch = 200 } = {}) {
  let done = 0;
  for (;;) {
    const users = await User.find({
      isOnboarded: true,
      name: { $exists: true, $ne: '' },
      // null matches missing or explicit null.
      vocleUsername: null,
    })
      .select('_id name vocleUsername')
      .limit(batch);
    if (users.length === 0) break;
    let progressed = 0;
    for (const user of users) {
      if (await ensureUsername(user)) progressed += 1;
    }
    done += progressed;
    if (progressed === 0) break;
  }
  if (done > 0) logger.info(`Vocle IDs: assigned usernames to ${done} doctors`);
  return done;
}

module.exports = {
  normalizeUsername,
  usernameProblem,
  baseFromName,
  generateUsername,
  isUsernameTaken,
  ensureUsername,
  backfillUsernames,
};
