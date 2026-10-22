import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createFixtureUsers } from './fixtures.js';
import { closeDatabase, connectDatabase, userByPhone } from './database.js';
import { expectSuccess, request } from './http.js';
import { closeRealtime, connectRealtime, joinChannel, waitFor } from './socket-client.js';

const results = [];
const assert = (value, message) => { if (!value) throw new Error(message); };
const marker = (name) => `sanity-realtime-${name}`;
async function scenario(id, action) {
  const startedAt = Date.now();
  try { await action(); results.push({ id, status: 'passed', durationMs: Date.now() - startedAt }); }
  catch (error) { results.push({ id, status: 'failed', durationMs: Date.now() - startedAt, error: error.message }); throw error; }
}

async function run() {
  await connectDatabase();
  const people = await createFixtureUsers();
  let general; let clientA; let clientB;
  try {
    const created = expectSuccess(await request('/api/spaces', { method: 'POST', token: people.A.token, expectedStatus: 201, body: { name: 'Sanity Realtime Space', type: 'department', description: 'Realtime fixture' } }), 'create realtime space');
    general = created.channels.find((item) => item.name === 'general');
    await request('/api/spaces/join', { method: 'POST', token: people.B.token, body: { inviteCode: created.space.inviteCode } });

    await scenario('realtime-and-availability-01', async () => {
      clientA = await connectRealtime(people.A.token); clientB = await connectRealtime(people.B.token);
      assert(clientA.authenticated.userId === people.A.userId && clientB.authenticated.userId === people.B.userId, 'Socket authentication did not return the authenticated identities.');
      await Promise.all([joinChannel(clientA, general._id), joinChannel(clientB, general._id)]);
      const received = waitFor(clientB.socket, 'new_message', (payload) => payload?.content?.text === marker('rest-message'));
      await request(`/api/channels/${general._id}/messages`, { method: 'POST', token: people.A.token, expectedStatus: 201, body: { type: 'text', content: { text: marker('rest-message') } } });
      await received;
      closeRealtime(clientA);
      clientA = await connectRealtime(people.A.token);
      await joinChannel(clientA, general._id);
    });

    await scenario('realtime-and-availability-02', async () => {
      const started = waitFor(clientB.socket, 'user_typing', (payload) => payload?.channelId === general._id && payload?.userId === people.A.userId);
      clientA.socket.emit('typing_start', { channelId: general._id });
      await started;
      const stopped = waitFor(clientB.socket, 'user_stopped_typing', (payload) => payload?.channelId === general._id && payload?.userId === people.A.userId);
      clientA.socket.emit('typing_stop', { channelId: general._id });
      await stopped;
    });

    await scenario('realtime-and-availability-03', async () => {
      const restBroadcast = waitFor(clientB.socket, 'presence_update', (payload) => payload?.userId === people.A.userId && payload?.availability?.status === 'on_call');
      await request('/api/users/me/availability', { method: 'PUT', token: people.A.token, body: { status: 'on_call', note: marker('rest-note') } });
      await restBroadcast;
      const socketBroadcast = waitFor(clientB.socket, 'presence_update', (payload) => payload?.userId === people.A.userId && payload?.availability?.status === 'in_ot');
      clientA.socket.emit('update_availability', { status: 'in_ot', note: marker('socket-note') });
      await socketBroadcast;
      const sync = waitFor(clientA.socket, 'sync_space_rooms', (payload) => payload?.success === true && payload?.spaceCount >= 1);
      clientA.socket.emit('sync_space_rooms');
      await sync;
      assert((await userByPhone(people.A.phone)).availability.status === 'in_ot', 'Socket availability update was not persisted.');
      const offline = waitFor(clientB.socket, 'presence_update', (payload) => payload?.userId === people.A.userId && payload?.isOnline === false);
      closeRealtime(clientA); clientA = undefined;
      await offline;
    });
  } finally {
    closeRealtime(clientA); closeRealtime(clientB); await closeDatabase();
    const output = resolve(process.env.SANITY_OUTPUT_DIR || 'output'); await mkdir(output, { recursive: true });
    await writeFile(resolve(output, 'realtime-availability-results.json'), `${JSON.stringify({ expected: 3, results }, null, 2)}\n`);
  }
  console.log('Realtime and availability scenarios passed: 3/3.');
}
run().catch(async (error) => { console.error(error.stack || error.message); await closeDatabase(); process.exitCode = 1; });
