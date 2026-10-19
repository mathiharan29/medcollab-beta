import { latestOtp } from './fake-inbox.js';
import { request, expectSuccess } from './http.js';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

export const fixtureUsers = Object.freeze([
  ['A', '+12025550101'], ['B', '+12025550102'], ['C', '+12025550103'], ['D', '+12025550104'], ['E', '+12025550105'],
]);

export async function createFixtureUsers() {
  const fixtureDirectory = process.env.SANITY_FIXTURE_DIR;
  if (!fixtureDirectory) throw new Error('SANITY_FIXTURE_DIR is required.');
  const fixturePath = join(fixtureDirectory, 'identities.json');
  try {
    const cached = JSON.parse(await readFile(fixturePath, 'utf8'));
    if (fixtureUsers.every(([label, phone]) => cached[label]?.phone === phone && cached[label]?.token && cached[label]?.userId)) return cached;
    throw new Error('Invalid cached fixture identities.');
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  const identities = {};
  for (const [label, phone] of fixtureUsers) {
    await request('/api/auth/request-otp', { method: 'POST', body: { phone } });
    const auth = expectSuccess(await request('/api/auth/verify-otp', { method: 'POST', body: { phone, otp: await latestOtp(phone) } }), `authenticate fixture ${label}`);
    const profile = expectSuccess(await request('/api/users/me', {
      method: 'PUT', token: auth.accessToken,
      body: { name: `Dr Sanity ${label}`, institution: 'Vocle Sanity Institute', speciality: 'Sanity Medicine' },
    }), `onboard fixture ${label}`);
    identities[label] = { phone, token: auth.accessToken, refreshToken: auth.refreshToken, userId: profile.user._id };
  }
  await mkdir(fixtureDirectory, { recursive: true });
  await writeFile(fixturePath, `${JSON.stringify(identities)}\n`, { mode: 0o600 });
  return identities;
}
