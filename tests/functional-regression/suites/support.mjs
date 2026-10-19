import assert from 'node:assert/strict';
import { createServer } from 'node:net';
import { randomUUID } from 'node:crypto';
import { mkdir, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { runModule } from '../src/module-runner.mjs';
import { createHttp } from '../src/http.mjs';
import { outputRoot } from '../src/config.mjs';
import { startBackend, stopChild } from '../src/runner.mjs';

async function ticket(db, id) {
  return db((connection) => connection.collection('supporttickets').findOne({ _id: new connection.base.Types.ObjectId(id) }));
}

async function freePort() {
  const server = createServer();
  await new Promise((resolve, reject) => server.once('error', reject).listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  await new Promise((resolve) => server.close(resolve));
  return port;
}

const cases = [{
  id: 'FR-SUP-01', module: 'SUP',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const created = [];
    for (const type of ['bug', 'feature', 'feedback']) {
      const title = `Synthetic ${type} title`;
      const description = `Synthetic ${type} description`;
      const response = await request(`/api/support/${type}`, { method: 'POST', token: a.token, body: { title, description }, expectedStatus: 201 });
      assert.ok(response.data.ticketId);
      const row = await ticket(db, response.data.ticketId);
      assert.equal(row.type, type);
      assert.equal(row.title, title);
      assert.equal(row.description, description);
      assert.equal(row.status, 'open');
      assert.equal(String(row.userId), a.userId);
      assert.equal(row.userName, 'Dr Synthetic A');
      created.push(row._id);
      for (const invalid of [{ title: ' ', description }, { title, description: ' ' }]) await request(`/api/support/${type}`, { method: 'POST', token: a.token, body: invalid, expectedStatus: 400 });
    }
    await db(async (connection) => assert.equal(await connection.collection('supporttickets').countDocuments({ userId: new connection.base.Types.ObjectId(a.userId) }), created.length));
  },
}, {
  id: 'FR-SUP-02', module: 'SUP',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const title = `  ${'T'.repeat(201)}  `, description = `  ${'D'.repeat(5001)}  `;
    for (const [type, field] of [['bug', 'steps'], ['feature', 'context']]) {
      const body = { title, description, [field]: `  ${'X'.repeat(3001)}  ` };
      const response = await request(`/api/support/${type}`, { method: 'POST', token: a.token, body, expectedStatus: 201 });
      const row = await ticket(db, response.data.ticketId);
      assert.equal(row.title, 'T'.repeat(200));
      assert.equal(row.description, 'D'.repeat(5000));
      assert.equal(row[field], 'X'.repeat(3000));
      assert.equal(String(row.userId), a.userId);
    }
  },
}, {
  id: 'FR-SUP-03', module: 'SUP', timeoutMs: 45000,
  run: async ({ identity, request, db, uri, inbox }) => {
    const a = await identity('A');
    let notifications;
    try { notifications = await request('/api/dev/seed-notifications', { method: 'POST', token: a.token }); }
    catch (error) { if (error.detail?.status !== 400) throw error; notifications = { status: 400, payload: error.detail.payload }; }
    const inboxResult = await request('/api/notifications', { token: a.token });
    if (notifications.status === 200) {
      assert.equal(notifications.data.count, 3);
      assert.deepEqual(new Set(inboxResult.data.notifications.map((item) => item.type)), new Set(['new_message', 'mention', 'handoff_received']));
    } else assert.equal(inboxResult.data.notifications.length, 0);
    const noSpaceConversation = await request('/api/dev/seed-conversation', { method: 'POST', token: a.token, expectedStatus: 400 });
    const noSpaceHandoff = await request('/api/dev/seed-handoff', { method: 'POST', token: a.token, expectedStatus: 400 });
    assert.match(noSpaceConversation.payload.message, /Join or create a group/);
    assert.match(noSpaceHandoff.payload.message, /Join a group/);
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Dev Seed Space', type: 'department' }, expectedStatus: 201 })).data.space;
    const conversation = await request('/api/dev/seed-conversation', { method: 'POST', token: a.token });
    const handoff = await request('/api/dev/seed-handoff', { method: 'POST', token: a.token });
    assert.ok(conversation.data.channelId && conversation.data.messageId);
    assert.equal(handoff.data.spaceId, space._id);
    await db(async (connection) => {
      const objectId = (value) => new connection.base.Types.ObjectId(value);
      assert.equal(await connection.collection('notifications').countDocuments({ userId: objectId(a.userId) }), notifications.status === 200 ? 3 : 0);
      const message = await connection.collection('messages').findOne({ _id: objectId(conversation.data.messageId) });
      assert.equal(message.content.text, 'Vocle beta seed message — safe to delete.');
      assert.equal(String(message.channelId), conversation.data.channelId);
      const row = await connection.collection('handoffs').findOne({ _id: objectId(handoff.data.handoffId) });
      assert.equal(row.status, 'draft');
      assert.equal(row.patients[0].clinicalAlias, 'Demo patient (beta)');
    });
    const port = await freePort();
    const runtime = join(outputRoot, 'runtime', `support-disabled-${randomUUID()}`);
    const secondInbox = join(runtime, 'inbox');
    await mkdir(secondInbox, { recursive: true });
    let backend;
    try {
      backend = await startBackend(uri, port, runtime, secondInbox, { extraEnv: { NODE_ENV: 'production', ENABLE_DEV_TOOLS: 'false' } });
      const disabledRequest = createHttp(`http://127.0.0.1:${port}`);
      for (const endpoint of ['seed-notifications', 'seed-conversation', 'seed-handoff']) {
        const result = await disabledRequest(`/api/dev/${endpoint}`, { method: 'POST', token: a.token, expectedStatus: 403 });
        assert.equal(result.payload.success, false);
      }
    } finally { await stopChild(backend?.child); await rm(runtime, { recursive: true, force: true }); }
    assert.equal(notifications.status, 200, 'Dev notification seeding must create three valid inbox records');
  },
}];

const selected = process.env.VOCLE_CASE_IDS?.split(',').filter(Boolean);
await runModule('support', selected ? cases.filter((item) => selected.includes(item.id)) : cases);
