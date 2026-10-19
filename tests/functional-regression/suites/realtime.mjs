import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { DecisionPending } from '../src/runner.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';

async function spaceFixture(identity, request, name) {
  const a = await identity('A'), b = await identity('B');
  const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name, type: 'department' }, expectedStatus: 201 });
  await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
  return { a, b, spaceId: created.data.space._id, channelId: created.data.channels.find((item) => item.name === 'general')._id };
}

const cases = [{
  id: 'FR-RT-01', module: 'RT',
  run: async ({ identity, request, db, origin }) => {
    const { a, b, spaceId } = await spaceFixture(identity, request, 'Synthetic Multi Device Presence');
    const peer = await connectSocket(null, origin, b.token);
    const first = await connectSocket(null, origin, a.token);
    const second = await connectSocket(null, origin, a.token);
    try {
      const initial = await db(async (connection) => (await connection.collection('users').findOne({ _id: new connection.base.Types.ObjectId(a.userId) })).lastSeenAt || null);
      first.disconnect();
      const snapshot = [];
      const listener = (payload) => { if (payload?.userId === a.userId && payload.availability) snapshot.push(payload); };
      peer.on('presence_update', listener);
      const synced = waitFor(peer, 'sync_space_rooms', (event) => event?.success === true && event.spaceCount === 1);
      peer.emit('sync_space_rooms');
      await synced;
      peer.off('presence_update', listener);
      assert.ok(snapshot.some((item) => item.isOnline === true), 'First device disconnect must leave A online');
      await db(async (connection) => {
        const stored = await connection.collection('users').findOne({ _id: new connection.base.Types.ObjectId(a.userId) });
        assert.equal(stored.lastSeenAt?.getTime() || null, initial?.getTime() || null, 'First disconnect must not update lastSeenAt');
      });
      const offline = waitFor(peer, 'presence_update', (payload) => payload?.userId === a.userId && payload?.isOnline === false);
      second.disconnect();
      assert.equal((await offline).userId, a.userId);
      const deadline = Date.now() + 5000;
      let lastSeen;
      do {
        lastSeen = await db(async (connection) => (await connection.collection('users').findOne({ _id: new connection.base.Types.ObjectId(a.userId) })).lastSeenAt);
        if (lastSeen && (!initial || lastSeen.getTime() > initial.getTime())) break;
        await new Promise((resolve) => setTimeout(resolve, 25));
      } while (Date.now() < deadline);
      assert.ok(lastSeen instanceof Date && (!initial || lastSeen > initial));
      const space = await request(`/api/spaces/${spaceId}`, { token: b.token });
      assert.ok(space.data.space.members.some((item) => item.userId._id === a.userId || item.userId === a.userId));
    } finally { first.disconnect(); second.disconnect(); peer.disconnect(); }
  },
}, {
  id: 'FR-RT-02', module: 'RT',
  run: async ({ identity, request, origin }) => {
    const a = await identity('A'), b = await identity('B');
    const socketA = await connectSocket(null, origin, a.token);
    const socketB = await connectSocket(null, origin, b.token);
    try {
      const spaces = [];
      for (const index of [1, 2]) {
        const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: `Synthetic Live Space ${index}`, type: 'department' }, expectedStatus: 201 });
        spaces.push(created.data.space._id);
        await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
      }
      const presence = [];
      const listener = (payload) => { if (payload?.availability) presence.push(payload); };
      socketB.on('presence_update', listener);
      const sync = waitFor(socketB, 'sync_space_rooms', (event) => event?.success === true && event.spaceCount === 2);
      socketB.emit('sync_space_rooms');
      await sync;
      socketB.off('presence_update', listener);
      assert.deepEqual(new Set(presence.map((item) => item.userId)), new Set([a.userId, b.userId]));
      assert.equal(presence.filter((item) => item.userId === a.userId).length, 1, 'Snapshot must dedupe A across spaces');
      assert.equal(presence.filter((item) => item.userId === b.userId).length, 1, 'Snapshot must dedupe B across spaces');
      const event = waitFor(socketB, 'presence_update', (payload) => payload?.userId === a.userId && payload?.availability?.status === 'on_call');
      await request('/api/users/me/availability', { method: 'PUT', token: a.token, body: { status: 'on_call' } });
      assert.equal((await event).userId, a.userId, 'Newly joined space rooms must receive peer updates');
      const refreshed = await request('/api/spaces', { token: b.token });
      assert.deepEqual(new Set(refreshed.data.spaces.map((item) => item._id)), new Set(spaces));
    } finally { socketA.disconnect(); socketB.disconnect(); }
  },
}, {
  id: 'FR-RT-07', module: 'RT', timeoutMs: 30000,
  run: async ({ identity, request, db, origin }) => {
    const { a, b, spaceId, channelId } = await spaceFixture(identity, request, 'Synthetic Socket Recovery');
    const socketA = await connectSocket(null, origin, a.token);
    const socketB = await connectSocket(null, origin, b.token);
    try {
      const join = async (socket) => {
        const ack = waitFor(socket, 'join_channel', (event) => event?.success === true && event.channelId === channelId);
        socket.emit('join_channel', { channelId }); await ack;
      };
      await join(socketA); await join(socketB);
      const baseline = waitFor(socketB, 'new_message', (payload) => payload?.content?.text === 'Synthetic recovery baseline');
      await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body: { content: { text: 'Synthetic recovery baseline' } }, expectedStatus: 201 });
      await baseline; // The client now has a Socket.IO offset for state recovery.
      socketB.io.reconnectionDelay(2000);
      socketB.io.reconnectionDelayMax(2000);
      const disconnected = waitFor(socketB, 'disconnect');
      const reconnected = waitFor(socketB, 'connect', () => true, 10000);
      const missed = waitFor(socketB, 'new_message', (payload) => payload?.content?.text === 'Synthetic message during transport gap', 10000);
      socketB.io.engine.close();
      await disconnected;
      const sent = (await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body: { content: { text: 'Synthetic message during transport gap' } }, expectedStatus: 201 })).data.message;
      await reconnected;
      assert.equal(socketB.recovered, true, 'Transport interruption must exercise Socket.IO recovery, not a fresh connection');
      assert.equal((await missed)._id, sent._id, 'Recovered client must replay the missed message');
      const persisted = await request(`/api/channels/${channelId}/messages`, { token: b.token });
      assert.ok(persisted.data.messages.some((item) => item._id === sent._id));
      const typing = waitFor(socketA, 'user_typing', (payload) => payload?.userId === b.userId && payload?.channelId === channelId, 2500);
      const synced = waitFor(socketB, 'sync_space_rooms', (payload) => payload?.success === true && payload?.spaceCount === 1, 2500);
      const availability = waitFor(socketA, 'presence_update', (payload) => payload?.userId === b.userId && payload?.availability?.status === 'on_call', 2500);
      socketB.emit('typing_start', { channelId });
      socketB.emit('sync_space_rooms');
      socketB.emit('update_availability', { status: 'on_call', note: 'Synthetic recovered note' });
      const outcomes = await Promise.allSettled([typing, synced, availability]);
      const [typingOk, syncOk, availabilityOk] = outcomes.map((item) => item.status === 'fulfilled');
      const profile = await request('/api/users/me', { token: b.token });
      await db(async (connection) => {
        const stored = await connection.collection('users').findOne({ _id: new connection.base.Types.ObjectId(b.userId) });
        assert.equal(stored.availability.status, profile.data.user.availability.status);
      });
      assert.deepEqual({ typingOk, syncOk, availabilityOk, persistedStatus: profile.data.user.availability.status },
        { typingOk: true, syncOk: true, availabilityOk: true, persistedStatus: 'on_call' },
        'Recovered socket must keep typing, room sync, availability handlers and persisted state');
      assert.equal(spaceId.length, 24);
    } finally { socketA.disconnect(); socketB.disconnect(); }
  },
}, {
  id: 'FR-RT-03', module: 'RT',
  run: async ({ identity, request, db, origin }) => {
    const { a, b } = await spaceFixture(identity, request, 'Synthetic Availability Paths');
    const socketA = await connectSocket(null, origin, a.token);
    const socketB = await connectSocket(null, origin, b.token);
    try {
      const restUntil = '2030-01-15T08:00:00.000Z', socketUntil = '2030-01-16T08:00:00.000Z';
      const restEvent = waitFor(socketB, 'presence_update', (payload) => payload?.userId === a.userId && payload?.availability?.status === 'on_call');
      const rest = await request('/api/users/me/availability', { method: 'PUT', token: a.token, body: { status: 'on_call', note: 'Synthetic REST note', until: restUntil } });
      assert.equal(rest.data.availability.note, 'Synthetic REST note');
      const peerRest = await restEvent;
      const socketEvent = waitFor(socketB, 'presence_update', (payload) => payload?.userId === a.userId && payload?.availability?.status === 'in_ot');
      socketA.emit('update_availability', { status: 'in_ot', note: 'Synthetic socket note', until: socketUntil });
      const peerSocket = await socketEvent;
      const me = await request('/api/users/me', { token: a.token });
      assert.equal(me.data.user.availability.status, 'in_ot');
      assert.equal(me.data.user.availability.note, 'Synthetic socket note');
      assert.equal(new Date(me.data.user.availability.until).toISOString(), socketUntil);
      await db(async (connection) => {
        const stored = await connection.collection('users').findOne({ _id: new connection.base.Types.ObjectId(a.userId) });
        assert.equal(stored.availability.status, 'in_ot');
        assert.equal(stored.availability.note, 'Synthetic socket note');
        assert.equal(stored.availability.until.toISOString(), socketUntil);
      });
      throw new DecisionPending('Q8: intended socket availability note/until convergence needs product decision', [
        `REST peer event availability ${JSON.stringify(peerRest.availability)}`,
        `Socket peer event availability ${JSON.stringify(peerSocket.availability)}`,
        'HTTP and MongoDB persisted the socket note and until fields',
      ]);
    } finally { socketA.disconnect(); socketB.disconnect(); }
  },
}];

for (const item of cases) await runModule(`realtime-${item.id.slice(-2).toLowerCase()}`, [item]);
