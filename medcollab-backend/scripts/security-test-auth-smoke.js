#!/usr/bin/env node

/**
 * Test-only authentication smoke check for the disposable Vocle CI runner.
 * It uses the real /api/auth/verify-otp route with the application's OTP
 * bypass, then verifies the resulting tokens through protected middleware.
 */

require('dotenv').config();

const fs = require('fs');

const TEST_DATABASE_URI = 'mongodb://127.0.0.1:27017/vocle_ci';
const API_BASE_URL = 'http://127.0.0.1:5000';
const users = [
  { key: 'USER_A', phone: '+15550000001', name: 'Vocle Security User A' },
  { key: 'USER_B', phone: '+15550000002', name: 'Vocle Security User B' },
  { key: 'USER_C', phone: '+15550000003', name: 'Vocle Security User C' },
  { key: 'USER_D', phone: '+15550000004', name: 'Vocle Security User D' },
  { key: 'USER_E', phone: '+15550000005', name: 'Vocle Security User E' },
  { key: 'USER_F', phone: '+15550000006', name: 'Vocle Security User F' },
  { key: 'USER_G', phone: '+15550000007', name: 'Vocle Security User G' },
  { key: 'USER_H', phone: '+15550000008', name: 'Vocle Security User H' },
];

function assertSafeEnvironment() {
  if (process.env.NODE_ENV !== 'test') {
    throw new Error('Authentication smoke test may run only with NODE_ENV=test');
  }
  if (process.env.MONGODB_URI !== TEST_DATABASE_URI) {
    throw new Error('Authentication smoke test may run only against local vocle_ci');
  }
  if (process.env.OTP_BYPASS !== 'true') {
    throw new Error('Authentication smoke test requires test-only OTP_BYPASS=true');
  }
  if (process.env.API_BASE_URL !== API_BASE_URL) {
    throw new Error('Authentication smoke test may call only the local backend');
  }
}

async function requestJson(path, options = {}) {
  const response = await fetch(`${API_BASE_URL}${path}`, { ...options, redirect: 'error', signal: AbortSignal.timeout(10000) });
  let body;
  try {
    body = await response.json();
  } catch {
    throw new Error(`Unexpected non-JSON response from ${path}`);
  }
  return { response, body };
}

function storeTokens(tokens) {
  if (!process.env.GITHUB_ENV) return;
  const lines = Object.entries(tokens)
    .map(([key, token]) => `VOCLE_TEST_${key}_TOKEN=${token}`)
    .join('\n');
  fs.appendFileSync(process.env.GITHUB_ENV, `${lines}\n`, { encoding: 'utf8' });
}

async function authenticate(user) {
  const { response, body } = await requestJson('/api/auth/verify-otp', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone: user.phone, otp: '123456' }),
  });

  if (!response.ok || !body.success || !body.data?.accessToken) {
    throw new Error(`OTP-bypass authentication failed for ${user.key}`);
  }
  // Runner commands register masking before GITHUB_ENV exposes tokens to later
  // steps. GitHub consumes these commands; token values are redacted in logs.
  if (process.env.GITHUB_ACTIONS === 'true') {
    for (const token of [body.data.accessToken, body.data.refreshToken]) {
      if (typeof token === 'string') console.log(`::add-mask::${token}`);
    }
  }
  if (body.data.isNewUser !== false || body.data.user?.name !== user.name) {
    throw new Error(`Expected seeded identity missing for ${user.key}`);
  }
  return body.data.accessToken;
}

async function verifyAuthenticatedRequest(user, accessToken) {
  const { response, body } = await requestJson('/api/users/me', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok || !body.success || body.data?.user?.name !== user.name) {
    throw new Error(`Protected profile request was not accepted for ${user.key}`);
  }
}

async function verifyUnauthenticatedRejection() {
  const { response, body } = await requestJson('/api/users/me');
  if (response.status !== 401 || body.success !== false) {
    throw new Error('Unauthenticated protected profile request was not rejected');
  }
}

async function main() {
  assertSafeEnvironment();
  const tokens = {};
  for (const user of users) {
    tokens[user.key] = await authenticate(user);
    await verifyAuthenticatedRequest(user, tokens[user.key]);
  }
  await verifyUnauthenticatedRejection();
  storeTokens(tokens);
  console.log('Authentication smoke test passed for userA through userH; unauthenticated access was rejected.');
}

main().catch((error) => {
  console.error(`Authentication smoke test failed: ${error.message}`);
  process.exit(1);
});
