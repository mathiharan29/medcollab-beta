import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { InfrastructureError } from '../src/runner.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';

const cases = [{
  id: 'FR-RUN-01', module: 'RUN', timeoutMs: 45000,
  run: async ({ identity, request, db, origin, restartBackend }) => {
    const a = await identity('A'), b = await identity('B');
    await request('/api/users/me', { method: 'PUT', token: a.token, body: { bio: 'Synthetic persisted profile' } });
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Restart Space', type: 'department' }, expectedStatus: 201 });
    const spaceId = created.data.space._id, channelId = created.data.channels.find((item) => item.name === 'general')._id;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
    const message = (await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body: { content: { text: 'Synthetic restart message' } }, expectedStatus: 201 })).data.message;
    const handoff = (await request('/api/handoffs', { method: 'POST', token: a.token, body: { spaceId, channelId, toUserId: b.userId, shiftDate: '2030-01-15T00:00:00.000Z', shiftType: 'night', patients: [{ bedNumber: 'R-01', clinicalAlias: 'Synthetic restart patient', pendingTasks: ['Synthetic follow-up'] }] }, expectedStatus: 201 })).data.handoff;
    await request(`/api/handoffs/${handoff._id}/submit`, { method: 'POST', token: a.token });
    await db(async (connection) => {
      const id = (value) => new connection.base.Types.ObjectId(value);
      assert.equal(await connection.collection('messages').countDocuments({ _id: id(message._id) }), 1);
      assert.equal(await connection.collection('handoffs').countDocuments({ _id: id(handoff._id), status: 'submitted' }), 1);
    });
    await restartBackend();
    const profile = (await request('/api/users/me', { token: a.token })).data.user;
    assert.equal(profile.bio, 'Synthetic persisted profile');
    const spaces = (await request('/api/spaces', { token: b.token })).data.spaces;
    assert.ok(spaces.some((item) => item._id === spaceId));
    const messages = (await request(`/api/channels/${channelId}/messages`, { token: b.token })).data.messages;
    assert.equal(messages.find((item) => item._id === message._id)?.content.text, 'Synthetic restart message');
    const detail = (await request(`/api/handoffs/${handoff._id}`, { token: b.token })).data.handoff;
    assert.equal(detail.status, 'submitted');
    assert.equal(detail.patients[0].clinicalAlias, 'Synthetic restart patient');
    assert.deepEqual(detail.patients[0].pendingTasks, ['Synthetic follow-up']);
    const socketB = await connectSocket(null, origin, b.token);
    let socketA;
    try {
      const online = waitFor(socketB, 'presence_update', (event) => event?.userId === a.userId && event?.isOnline === true);
      socketA = await connectSocket(null, origin, a.token);
      assert.equal((await online).userId, a.userId);
    } finally { socketA?.disconnect(); socketB.disconnect(); }
  },
}, {
  id: 'FR-RUN-02', module: 'RUN', timeoutMs: 60000, mongoRestart: true,
  run: async ({ identity, request, db, pauseMongo, resumeMongo }) => {
    const a = await identity('C');
    await request('/api/users/me', { method: 'PUT', token: a.token, body: { bio: 'Synthetic outage recovery profile' } });
    const before = await request('/api/users/me', { token: a.token });
    assert.equal(before.data.user.bio, 'Synthetic outage recovery profile', 'Pre-outage HTTP reread');
    await db(async (connection) => {
      const row = await connection.collection('users').findOne({ _id: new connection.base.Types.ObjectId(a.userId) });
      assert.equal(row.bio, 'Synthetic outage recovery profile', 'Pre-outage independent Mongo read');
      try { await connection.db.admin().command({ fsync: 1 }); }
      catch (error) { throw new InfrastructureError(`Disposable MongoDB could not flush the recovery fixture: ${error.message}`); }
    });
    await pauseMongo();
    let resumed = false;
    try {
      let failed;
      try { await request('/api/users/me', { token: a.token, timeoutMs: 12000 }); }
      catch (error) { failed = error; }
      assert.ok(failed, 'Read while MongoDB is stopped must not fabricate an empty success');
      if (failed.detail?.status) assert.ok(failed.detail.status >= 500);
      try { await resumeMongo(); resumed = true; }
      catch (error) { throw new InfrastructureError(`Disposable MongoDB could not resume: ${error.message}`); }
      await db(async (connection) => {
        const row = await connection.collection('users').findOne({ _id: new connection.base.Types.ObjectId(a.userId) });
        assert.equal(row.bio, 'Synthetic outage recovery profile', 'Post-restart independent Mongo read');
      });
      let recovered;
      const deadline = Date.now() + 12000;
      do {
        try { recovered = await request('/api/users/me', { token: a.token, timeoutMs: 3000 }); break; }
        catch (error) { if (Date.now() >= deadline) throw error; await new Promise((resolve) => setTimeout(resolve, 200)); }
      } while (true);
      assert.equal(recovered.data.user._id, a.userId);
      assert.equal(recovered.data.user.bio, 'Synthetic outage recovery profile');
    } finally { if (!resumed) await resumeMongo(); }
  },
}];

const selected = process.env.VOCLE_CASE_IDS?.split(',').filter(Boolean);
await runModule('runtime', selected ? cases.filter((item) => selected.includes(item.id)) : cases);
