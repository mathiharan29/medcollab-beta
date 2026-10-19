import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createFixtureUsers } from './fixtures.js';
import { request, expectSuccess } from './http.js';
import { closeDatabase, connectDatabase, messageById } from './database.js';

const results = [];
const assert = (condition, message) => { if (!condition) throw new Error(message); };
async function scenario(id, action) {
  const startedAt = Date.now();
  try { await action(); results.push({ id, status: 'passed', durationMs: Date.now() - startedAt }); }
  catch (error) { results.push({ id, status: 'failed', durationMs: Date.now() - startedAt, error: error.message }); throw error; }
}

async function run() {
  await connectDatabase();
  const people = await createFixtureUsers();
  let space;
  let general;
  let custom;
  try {
    await scenario('spaces-and-invitations-01', async () => {
      const data = expectSuccess(await request('/api/spaces', { method: 'POST', token: people.A.token, body: { name: 'Sanity Main Space', type: 'department', description: 'Synthetic suite space' }, expectedStatus: 201 }), 'create space');
      space = data.space;
      assert(data.channels.length === 3 && data.channels.map((channel) => channel.name).join(',') === 'general,emergency,academics', 'New space did not contain exactly the three default channels.');
      general = data.channels.find((channel) => channel.name === 'general');
    });
    await scenario('spaces-and-invitations-02', async () => {
      const preview = expectSuccess(await request(`/api/spaces/invite/${space.inviteCode}`, { token: people.B.token }), 'preview invitation');
      assert(preview.invite.name === space.name && preview.invite.alreadyMember === false, 'Invitation preview was incorrect.');
      await request('/api/spaces/join', { method: 'POST', token: people.B.token, body: { inviteCode: space.inviteCode } });
      const [list, detail, members] = await Promise.all([
        request('/api/spaces', { token: people.B.token }), request(`/api/spaces/${space._id}`, { token: people.B.token }), request(`/api/spaces/${space._id}/members`, { token: people.B.token }),
      ]);
      assert(expectSuccess(list, 'space list').spaces.some((item) => item._id === space._id), 'Joined space missing from list.');
      assert(expectSuccess(detail, 'space detail').space._id === space._id, 'Joined space detail missing.');
      assert(expectSuccess(members, 'members').members.length === 2, 'Member list did not reflect invitation join.');
    });
    await scenario('spaces-and-invitations-03', async () => {
      await request('/api/spaces/join', { method: 'POST', token: people.B.token, body: { inviteCode: space.inviteCode }, expectedStatus: 409 });
      const members = expectSuccess(await request(`/api/spaces/${space._id}/members`, { token: people.A.token }), 'members after duplicate join');
      assert(members.members.length === 2, 'Duplicate join created another membership.');
    });
    await scenario('spaces-and-invitations-04', async () => {
      const renamed = expectSuccess(await request(`/api/spaces/${space._id}`, { method: 'PUT', token: people.A.token, body: { name: 'Sanity Renamed Space' } }), 'rename space');
      const oldCode = space.inviteCode;
      const regenerated = expectSuccess(await request(`/api/spaces/${space._id}/invite`, { method: 'POST', token: people.A.token }), 'regenerate invite');
      assert(renamed.space.name === 'Sanity Renamed Space' && regenerated.inviteCode !== oldCode, 'Space rename or invitation regeneration did not persist.');
      await request(`/api/spaces/invite/${oldCode}`, { token: people.C.token, expectedStatus: 404 });
      space = { ...space, inviteCode: regenerated.inviteCode };
    });
    await scenario('spaces-and-invitations-05', async () => {
      await request('/api/spaces/join', { method: 'POST', token: people.C.token, body: { inviteCode: space.inviteCode } });
      await request(`/api/spaces/${space._id}/leave`, { method: 'POST', token: people.C.token });
      await request(`/api/spaces/${space._id}/members/${people.B.userId}`, { method: 'DELETE', token: people.A.token });
      await request(`/api/spaces/${space._id}/leave`, { method: 'POST', token: people.A.token, expectedStatus: 400 });
      assert(expectSuccess(await request(`/api/spaces/${space._id}/members`, { token: people.A.token }), 'members after leave/remove').members.length === 1, 'Membership lifecycle did not persist.');
    });
    await scenario('channels-01', async () => {
      custom = expectSuccess(await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: people.A.token, body: { name: 'sanity-rounds', description: 'Synthetic channel' }, expectedStatus: 201 }), 'create public channel').channel;
      await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: people.A.token, body: { name: 'sanity-rounds' }, expectedStatus: 409 });
      const updated = expectSuccess(await request(`/api/channels/${custom._id}`, { method: 'PUT', token: people.A.token, body: { name: 'sanity-updated' } }), 'update public channel');
      assert(updated.channel.name === 'sanity-updated', 'Public channel update did not persist.');
    });
    await scenario('channels-02', async () => {
      const privateChannel = expectSuccess(await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: people.A.token, body: { name: 'sanity-private', isPrivate: true }, expectedStatus: 201 }), 'create private channel').channel;
      assert(expectSuccess(await request(`/api/channels/${privateChannel._id}`, { token: people.A.token }), 'read private channel').channel._id === privateChannel._id, 'Private creator access failed.');
    });
    await scenario('channels-03', async () => {
      const message = expectSuccess(await request(`/api/channels/${custom._id}/messages`, { method: 'POST', token: people.A.token, body: { type: 'text', content: { text: 'archive retention marker' } }, expectedStatus: 201 }), 'send retained channel message').message;
      await request(`/api/channels/${custom._id}`, { method: 'DELETE', token: people.A.token });
      await request(`/api/channels/${custom._id}/messages`, { token: people.A.token, expectedStatus: 403 });
      assert((await messageById(message._id))?.content?.text === 'archive retention marker', 'Archiving removed stored channel messages.');
      const listed = expectSuccess(await request(`/api/spaces/${space._id}/channels`, { token: people.A.token }), 'list active channels');
      assert(!listed.channels.some((item) => item._id === custom._id), 'Archived channel remains in active lists.');
      await request(`/api/channels/${general._id}`, { method: 'DELETE', token: people.A.token, expectedStatus: 400 });
    });
  } finally {
    await closeDatabase();
    const output = resolve(process.env.SANITY_OUTPUT_DIR || 'output');
    await mkdir(output, { recursive: true });
    await writeFile(resolve(output, 'spaces-and-channels-results.json'), `${JSON.stringify({ expected: 8, results }, null, 2)}\n`);
  }
  console.log('Spaces and channel scenarios passed: 8/8.');
}
run().catch(async (error) => { console.error(error.stack || error.message); await closeDatabase(); process.exitCode = 1; });
