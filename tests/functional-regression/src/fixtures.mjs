import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

export const users = Object.freeze(Object.fromEntries(['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K'].map((label, index) => [label, { phone: `+120255501${String(index + 1).padStart(2, '0')}`, name: `Dr Synthetic ${label}` }])));

export async function capturedOtp(inboxDirectory, phone) {
  const entries = (await readFile(join(inboxDirectory, 'msg91-inbox.ndjson'), 'utf8')).trim().split(/\r?\n/).filter(Boolean).map((line) => JSON.parse(line));
  const entry = entries.reverse().find((item) => item.type === 'otp' && item.mobile === phone.slice(1));
  assert.match(entry?.otp || '', /^\d{6}$/);
  return entry.otp;
}

export async function createIdentity(request, inboxDirectory, label) {
  const user = users[label];
  if (!user) throw new Error(`Unknown synthetic user ${label}`);
  await request('/api/auth/request-otp', { method: 'POST', body: { phone: user.phone } });
  const verification = await request('/api/auth/verify-otp', { method: 'POST', body: { phone: user.phone, otp: await capturedOtp(inboxDirectory, user.phone) } });
  assert.equal(verification.payload.success, true);
  const { accessToken, refreshToken } = verification.data;
  assert.ok(accessToken && refreshToken);
  const profile = await request('/api/users/me', { method: 'PUT', token: accessToken, body: { name: user.name, institution: 'Vocle Synthetic Institute', speciality: 'Synthetic Medicine' } });
  assert.equal(profile.payload.success, true);
  assert.equal(profile.data.user.name, user.name);
  return { label, phone: user.phone, userId: profile.data.user._id, token: accessToken, refreshToken };
}
