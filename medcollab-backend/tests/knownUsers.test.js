/**
 * Unit tests for known-user privacy helpers (no DB).
 */
const assert = require('node:assert/strict');
const { describe, test } = require('node:test');
const {
  normalizeInstitution,
} = require('../src/utils/knownUsers');

describe('knownUsers.normalizeInstitution', () => {
  test('trims and lowercases', () => {
    assert.equal(normalizeInstitution('  AIIMS Delhi '), 'aiims delhi');
  });

  test('collapses whitespace', () => {
    assert.equal(normalizeInstitution('Apollo   Hospital'), 'apollo hospital');
  });

  test('empty for nullish', () => {
    assert.equal(normalizeInstitution(null), '');
    assert.equal(normalizeInstitution(undefined), '');
  });
});
