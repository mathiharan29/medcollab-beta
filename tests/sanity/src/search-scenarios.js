import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createFixtureUsers } from './fixtures.js';
import { closeDatabase, connectDatabase } from './database.js';
import { expectSuccess, request } from './http.js';

const results = [];
const assert = (value, message) => { if (!value) throw new Error(message); };
const term = 'atlasprobe';
async function scenario(id, action) {
  const startedAt = Date.now();
  try { await action(); results.push({ id, status: 'passed', durationMs: Date.now() - startedAt }); }
  catch (error) { results.push({ id, status: 'failed', durationMs: Date.now() - startedAt, error: error.message }); throw error; }
}

async function run() {
  await connectDatabase();
  const people = await createFixtureUsers();
  try {
    const created = expectSuccess(await request('/api/spaces', { method: 'POST', token: people.A.token, expectedStatus: 201, body: { name: `${term} space`, type: 'department', description: 'Search fixture' } }), 'create search space');
    const general = created.channels.find((item) => item.name === 'general');
    await request('/api/spaces/join', { method: 'POST', token: people.B.token, body: { inviteCode: created.space.inviteCode } });
    await request('/api/users/me', { method: 'PUT', token: people.B.token, body: { name: `Dr ${term} B` } });
    const channel = expectSuccess(await request(`/api/spaces/${created.space._id}/channels`, { method: 'POST', token: people.A.token, expectedStatus: 201, body: { name: `${term}-channel` } }), 'create searchable channel').channel;
    await request(`/api/channels/${general._id}/messages`, { method: 'POST', token: people.A.token, expectedStatus: 201, body: { type: 'text', content: { text: `${term} message` } } });
    await request(`/api/channels/${general._id}/messages`, { method: 'POST', token: people.A.token, expectedStatus: 201, body: { type: 'document', content: { mediaUrl: `https://res.cloudinary.com/sanity/raw/upload/${term}.pdf`, fileName: `${term}.pdf`, mimeType: 'application/pdf' } } });
    await request('/api/handoffs', { method: 'POST', token: people.A.token, expectedStatus: 201, body: { spaceId: created.space._id, channelId: general._id, toUserId: people.B.userId, shiftDate: '2030-01-15T00:00:00.000Z', shiftType: 'night', shiftSummary: `${term} handoff`, patients: [{ bedNumber: 'Q-01', clinicalAlias: `${term} patient` }] } });

    await scenario('search-01', async () => {
      const [users, lookup] = await Promise.all([request(`/api/users/search?q=${term}`, { token: people.A.token }), request(`/api/users/lookup?phone=${encodeURIComponent(people.B.phone)}`, { token: people.A.token })]);
      assert(expectSuccess(users, 'known-user search').users.some((user) => user._id === people.B.userId), 'Known-user search did not return the synthetic colleague.');
      assert(expectSuccess(lookup, 'phone lookup').user._id === people.B.userId, 'Phone lookup did not return the synthetic colleague.');
    });

    await scenario('search-02', async () => {
      const found = expectSuccess(await request(`/api/search?q=${term}`, { token: people.A.token }), 'global search');
      const empty = expectSuccess(await request('/api/search?q=zzzz-no-sanity-match', { token: people.A.token }), 'empty global search');
      assert(found.messages.length >= 1 && found.doctors.some((user) => user._id === people.B.userId) && found.channels.some((item) => item._id === channel._id) && found.attachments.length >= 1 && found.handoffs.length >= 1, 'Global search did not return each required result class.');
      assert(Object.values(empty).filter(Array.isArray).every((items) => items.length === 0), 'Nonmatching global search was not empty.');
    });
  } finally {
    await closeDatabase();
    const output = resolve(process.env.SANITY_OUTPUT_DIR || 'output'); await mkdir(output, { recursive: true });
    await writeFile(resolve(output, 'search-results.json'), `${JSON.stringify({ expected: 2, results }, null, 2)}\n`);
  }
  console.log('Search scenarios passed: 2/2.');
}
run().catch(async (error) => { console.error(error.stack || error.message); await closeDatabase(); process.exitCode = 1; });
