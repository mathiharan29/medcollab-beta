const assert = require('node:assert/strict');
const { describe, test } = require('node:test');
const {
  bearerUserIdFromRequest,
  apiRateLimitKey,
} = require('../src/middleware/rateLimiter');

describe('rateLimiter keys', () => {
  const sampleToken =
    'header.' +
    Buffer.from(JSON.stringify({ userId: '507f1f77bcf86cd799439011' })).toString(
      'base64url'
    ) +
    '.sig';

  test('bearerUserIdFromRequest extracts userId', () => {
    const req = { headers: { authorization: `Bearer ${sampleToken}` } };
    assert.equal(bearerUserIdFromRequest(req), '507f1f77bcf86cd799439011');
  });

  test('apiRateLimitKey prefers user bucket over IP', () => {
    const req = {
      headers: { authorization: `Bearer ${sampleToken}` },
      ip: '203.0.113.10',
    };
    assert.equal(apiRateLimitKey(req), 'user:507f1f77bcf86cd799439011');
  });

  test('apiRateLimitKey falls back to IP without auth', () => {
    const req = { headers: {}, ip: '203.0.113.10' };
    assert.match(apiRateLimitKey(req), /^203\.0\.113\.10$/);
  });
});
