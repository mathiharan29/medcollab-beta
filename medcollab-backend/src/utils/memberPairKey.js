/**
 * Canonical key for exact DM membership sets (pair or group).
 * Enables unique-index upserts without matching on `members` twice.
 */
const memberPairKey = (userIds) =>
  [...new Set((userIds || []).map((id) => id?.toString()).filter(Boolean))]
    .sort()
    .join(':');

module.exports = { memberPairKey };
