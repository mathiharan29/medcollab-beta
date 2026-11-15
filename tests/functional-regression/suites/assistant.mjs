import assert from 'node:assert/strict';
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
}]);
