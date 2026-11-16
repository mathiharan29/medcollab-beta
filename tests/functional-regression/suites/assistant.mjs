import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { capturedOtp, users } from '../src/fixtures.mjs';
import { runModule } from '../src/module-runner.mjs';

await runModule('assistant', [{
  id: 'FR-AST-01', module: 'AST',
  run: async ({ identity, request, db, inbox }) => {
    const capability = '/api/assistant/capabilities';
    const interpret = '/api/assistant/interpret';
    const doctor = await identity('A');
    const { phone } = users.B;
    await request('/api/auth/request-otp', { method: 'POST', body: { phone } });
    const { data: pending } = await request('/api/auth/verify-otp', {
      method: 'POST', body: { phone, otp: await capturedOtp(inbox, phone) },
    });
    const command = { text: 'Set availability to on call' };
    await request(capability, { expectedStatus: 401 });
    await request(capability, { token: pending.accessToken, expectedStatus: 403 });
    await request(interpret, { method: 'POST', token: pending.accessToken, body: command, expectedStatus: 403 });

    const snapshot = () => db(async (connection) => ({
      availability: (await connection.collection('users').findOne({
        _id: new connection.base.Types.ObjectId(doctor.userId),
      })).availability,
      messages: await connection.collection('messages').countDocuments(),
      handoffs: await connection.collection('handoffs').countDocuments(),
    }));
    const before = await snapshot();
    assert.deepEqual((await request(capability, { token: doctor.token })).data, { llm: false, model: null });
    for (const text of [command.text, `  ${'x'.repeat(1000)}  `]) {
      const result = await request(interpret, { method: 'POST', token: doctor.token, body: { text } });
      assert.deepEqual(result.data, { llm: false, actions: [] });
    }
    await request(interpret, {
      method: 'POST', token: doctor.token, body: { text: 'x'.repeat(1001) }, expectedStatus: 400,
    });
    assert.deepEqual(await snapshot(), before);
  },
}, {
  id: 'FR-AST-02', module: 'AST', timeoutMs: 60000,
  run: async ({ identity, request, db, restartBackend }) => {
    const doctor = await identity('A');
    const peer = await identity('C');
    const room = (await request('/api/spaces', {
      method: 'POST', token: doctor.token, body: { name: 'Synthetic Assistant Ward', type: 'department' }, expectedStatus: 201,
    })).data.space;
    await request('/api/spaces/join', { method: 'POST', token: peer.token, body: { inviteCode: room.inviteCode } });
    const snapshot = () => db(async connection => ({
      user: await connection.collection('users').findOne(
        { _id: new connection.base.Types.ObjectId(doctor.userId) }, { projection: { availability: 1 } }),
      messages: await connection.collection('messages').countDocuments(),
      channels: await connection.collection('channels').countDocuments(),
      handoffs: await connection.collection('handoffs').countDocuments(),
    }));
    const replies = [];
    let status = 429;
    const blocks = [
      { type: 'tool_use', id: 'tool_1', name: 'send_message', input: { to: `p:${peer.userId}`, text: '  Synthetic confirmed only  ' } },
      { type: 'tool_use', id: 'tool_2', name: 'send_message', input: { to: 'p:unlisted', text: 'must not leave the directory' } },
      { type: 'tool_use', id: 'tool_3', name: 'delete_everything', input: {} },
    ];
    const provider = createServer((req, res) => {
      replies.push({ path: req.url, status });
      req.resume();
      res.writeHead(status, { 'content-type': 'application/json' });
      res.end(JSON.stringify(status === 200
        ? { type: 'message', stop_reason: 'tool_use', content: blocks }
        : { type: 'error', error: { type: 'synthetic_error', message: 'Synthetic provider unavailable' } }));
    });
    await new Promise((ready, reject) => provider.once('error', reject).listen(0, '127.0.0.1', ready));
    try {
      await restartBackend({
        ANTHROPIC_API_KEY: 'synthetic-loopback-only',
        ANTHROPIC_BASE_URL: `http://127.0.0.1:${provider.address().port}`,
      });
      const interpret = '/api/assistant/interpret';
      const body = { text: 'Synthetic command for provider' };
      const call = expectedStatus => request(interpret, { method: 'POST', token: doctor.token, body, expectedStatus });
      const before = await snapshot();
      await request(interpret, { method: 'POST', body, expectedStatus: 401 });
      assert.deepEqual(replies, []);
      assert.match((await call(429)).payload.message, /busy/i);
      status = 500;
      assert.match((await call(502)).payload.message, /unavailable/i);
      status = 200;
      const result = (await call(200)).data;
      assert.equal(result.llm, true);
      assert.deepEqual(result.actions.map(action => [action.type, action.to.id, action.text]), [
        ['send_message', `p:${peer.userId}`, 'Synthetic confirmed only'],
      ]);
      assert.deepEqual(new Set(replies.map(reply => reply.status)), new Set([429, 500, 200]));
      assert.ok(replies.every(reply => reply.path.startsWith('/v1/messages')));
      assert.deepEqual(await snapshot(), before, 'Provider proposals and errors must leave all write targets unchanged');
    } finally {
      provider.closeAllConnections();
      await new Promise((closed, reject) => provider.close(error => error ? reject(error) : closed()));
    }
  },
}]);
