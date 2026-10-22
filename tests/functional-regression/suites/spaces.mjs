import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { DecisionPending } from '../src/runner.mjs';
import { backendRoot } from '../src/config.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';

const cases = [{
  id: 'FR-SPC-01', module: 'SPC',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const valid = [
      { name: 'AB', type: 'department', description: 'D'.repeat(300) },
      { name: 'S'.repeat(100), type: 'department', description: '' },
    ];
    const createdIds = [];
    for (const body of valid) {
      const created = await request('/api/spaces', { method: 'POST', token: a.token, body, expectedStatus: 201 });
      assert.equal(created.data.space.name, body.name);
      createdIds.push(created.data.space._id);
      const detail = await request(`/api/spaces/${created.data.space._id}`, { token: a.token });
      assert.equal(detail.data.space.name, body.name);
      assert.equal(detail.data.space.description, body.description);
      assert.deepEqual(new Set(detail.data.space.channels.map((item) => item.name)), new Set(['general', 'emergency', 'academics']));
    }
    const invalid = [
      { name: 'A', type: 'department' },
      { name: 'N'.repeat(101), type: 'department' },
      { name: 'Valid', type: 'department', description: 'D'.repeat(301) },
      { name: 'Valid', type: 'fictional-type' },
    ];
    for (const body of invalid) {
      const rejected = await request('/api/spaces', { method: 'POST', token: a.token, body, expectedStatus: 400 });
      assert.equal(rejected.payload.success, false);
    }
    await db(async (connection) => {
      const spaces = await connection.collection('spaces').find({ createdBy: { $exists: true } }).toArray();
      assert.deepEqual(new Set(spaces.map((item) => String(item._id))), new Set(createdIds));
      const channels = await connection.collection('channels').countDocuments({ spaceId: { $in: spaces.map((item) => item._id) } });
      assert.equal(channels, 6, 'Rejected creates must leave no partial spaces or channels');
    });
  },
}, {
  id: 'FR-SPC-02', module: 'SPC',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Invite Rotation', type: 'department' }, expectedStatus: 201 })).data.space;
    const lower = space.inviteCode.toLowerCase();
    const preview = await request(`/api/spaces/invite/${lower}`, { token: b.token });
    assert.equal(preview.data.invite.inviteCode, space.inviteCode);
    assert.equal(preview.data.invite.alreadyMember, false);
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: lower } });
    const after = await request(`/api/spaces/invite/${lower}`, { token: b.token });
    assert.equal(after.data.invite.alreadyMember, true);
    const rotated = await request(`/api/spaces/${space._id}/invite`, { method: 'POST', token: a.token });
    assert.notEqual(rotated.data.inviteCode, space.inviteCode);
    await request(`/api/spaces/invite/${lower}`, { token: c.token, expectedStatus: 404 });
    const newPreview = await request(`/api/spaces/invite/${rotated.data.inviteCode.toLowerCase()}`, { token: c.token });
    assert.equal(newPreview.data.invite.inviteCode, rotated.data.inviteCode);
    await request('/api/spaces/join', { method: 'POST', token: c.token, body: { inviteCode: rotated.data.inviteCode.toLowerCase() } });
    await db(async (connection) => {
      const stored = await connection.collection('spaces').findOne({ _id: new connection.base.Types.ObjectId(space._id) });
      assert.equal(stored.inviteCode, rotated.data.inviteCode);
      assert.deepEqual(new Set(stored.members.map((item) => String(item.userId))), new Set([a.userId, b.userId, c.userId]));
    });
  },
}, {
  id: 'FR-SPC-04', module: 'SPC',
  prerequisiteSeed: 'C space role promoted to admin directly; no promotion route exists',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Roles', type: 'department' }, expectedStatus: 201 })).data.space;
    for (const person of [b, c]) await request('/api/spaces/join', { method: 'POST', token: person.token, body: { inviteCode: space.inviteCode } });
    await db(async (connection) => {
      const changed = await connection.collection('spaces').updateOne({ _id: new connection.base.Types.ObjectId(space._id), 'members.userId': new connection.base.Types.ObjectId(c.userId) }, { $set: { 'members.$.role': 'admin' } });
      assert.equal(changed.modifiedCount, 1);
    });
    const ownerChange = await request(`/api/spaces/${space._id}`, { method: 'PUT', token: a.token, body: { name: 'Synthetic Roles Updated' } });
    assert.equal(ownerChange.data.space.name, 'Synthetic Roles Updated');
    const adminChange = await request(`/api/spaces/${space._id}`, { method: 'PUT', token: c.token, body: { description: 'Admin saved setting', settings: { requireApproval: true } } });
    assert.equal(adminChange.data.space.settings.requireApproval, true);
    await request(`/api/spaces/${space._id}`, { method: 'PUT', token: b.token, body: { name: 'Forbidden Name' }, expectedStatus: 403 });
    await request(`/api/spaces/${space._id}/members/${a.userId}`, { method: 'DELETE', token: b.token, expectedStatus: 403 });
    const reread = await request(`/api/spaces/${space._id}`, { token: a.token });
    assert.equal(reread.data.space.name, 'Synthetic Roles Updated');
    assert.equal(reread.data.space.description, 'Admin saved setting');
    assert.equal(reread.data.space.settings.requireApproval, true);
    await db(async (connection) => {
      const stored = await connection.collection('spaces').findOne({ _id: new connection.base.Types.ObjectId(space._id) });
      assert.equal(stored.members.find((item) => String(item.userId) === a.userId).role, 'owner');
      assert.equal(stored.members.find((item) => String(item.userId) === c.userId).role, 'admin');
      assert.equal(stored.name, 'Synthetic Roles Updated');
    });
  },
}, {
  id: 'FR-SPC-05', module: 'SPC',
  run: async ({ identity, request }) => {
    const a = await identity('A');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Presence Rank', type: 'department' }, expectedStatus: 201 })).data.space;
    const ranked = [
      ['B', 'on_call', 0], ['C', 'in_ot', 1], ['D', 'on_rounds', 1], ['E', 'in_icu', 1],
      ['F', 'available', 2], ['G', 'do_not_disturb', 3], ['H', 'off_duty', 4],
    ];
    const byId = new Map();
    for (const [label, status, rank] of ranked) {
      const person = await identity(label);
      byId.set(person.userId, rank);
      await request('/api/spaces/join', { method: 'POST', token: person.token, body: { inviteCode: space.inviteCode } });
      const updated = await request('/api/users/me/availability', { method: 'PUT', token: person.token, body: { status } });
      assert.equal(updated.data.availability.status, status);
    }
    const members = (await request(`/api/spaces/${space._id}/members`, { token: a.token })).data.members;
    const selected = members.filter((person) => byId.has(person._id));
    assert.equal(selected.length, ranked.length);
    const ranks = selected.map((person) => byId.get(person._id));
    assert.deepEqual(ranks, [...ranks].sort((x, y) => x - y));
    assert.equal(ranks[0], 0);
    assert.equal(ranks.at(-1), 4);
  },
}, {
  id: 'FR-SPC-06', module: 'SPC', timeoutMs: 30000,
  run: async ({ identity, request, db, origin }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Revocation', type: 'department' }, expectedStatus: 201 })).data.space;
    for (const person of [b, c]) await request('/api/spaces/join', { method: 'POST', token: person.token, body: { inviteCode: space.inviteCode } });
    const sockets = [];
    const sync = async (socket) => {
      const acknowledged = waitFor(socket, 'sync_space_rooms', (payload) => typeof payload?.spaceCount === 'number');
      socket.emit('sync_space_rooms');
      const response = await acknowledged;
      assert.equal(response.success, true);
      return response.spaceCount;
    };
    try {
      const owner = await connectSocket(backendRoot, origin, a.token);
      const leaving = await connectSocket(backendRoot, origin, b.token);
      const removed = await connectSocket(backendRoot, origin, c.token);
      sockets.push(owner, leaving, removed);
      assert.equal(await sync(leaving), 1);
      assert.equal(await sync(removed), 1);
      await request(`/api/spaces/${space._id}/leave`, { method: 'POST', token: b.token });
      await request(`/api/spaces/${space._id}/members/${c.userId}`, { method: 'DELETE', token: a.token });
      for (const person of [b, c]) {
        const list = await request('/api/spaces', { token: person.token });
        assert.ok(!list.data.spaces.some((item) => item._id === space._id));
        await request(`/api/spaces/${space._id}`, { token: person.token, expectedStatus: 403 });
      }
      const search = await request(`/api/users/search?q=${encodeURIComponent('Synthetic')}&spaceId=${space._id}`, { token: a.token });
      assert.ok(!search.data.users.some((user) => [b.userId, c.userId].includes(user._id)));
      const members = await request(`/api/spaces/${space._id}/members`, { token: a.token });
      assert.deepEqual(members.data.members.map((member) => member._id), [a.userId]);
      await db(async (connection) => {
        const stored = await connection.collection('spaces').findOne({ _id: new connection.base.Types.ObjectId(space._id) });
        assert.deepEqual(stored.members.map((member) => String(member.userId)), [a.userId]);
      });
      assert.equal(await sync(leaving), 0);
      assert.equal(await sync(removed), 0);
      const probe = async (note, peers) => {
        const predicate = (event) => event?.userId === a.userId && event?.availability?.note === note;
        const ownerEvent = waitFor(owner, 'presence_update', predicate, 3000);
        const unexpected = peers.map((socket) => waitFor(socket, 'presence_update', predicate, 1500).then(() => true, () => false));
        const updated = await request('/api/users/me/availability', { method: 'PUT', token: a.token, body: { status: 'on_call', note } });
        assert.equal(updated.data.availability.note, note);
        await ownerEvent;
        return Promise.all(unexpected);
      };
      const afterSyncLeaks = await probe('synthetic-post-sync-revocation', [leaving, removed]);
      leaving.disconnect(); removed.disconnect();
      const reconnectedB = await connectSocket(backendRoot, origin, b.token);
      const reconnectedC = await connectSocket(backendRoot, origin, c.token);
      sockets.push(reconnectedB, reconnectedC);
      assert.equal(await sync(reconnectedB), 0);
      assert.equal(await sync(reconnectedC), 0);
      const afterReconnectLeaks = await probe('synthetic-post-reconnect-revocation', [reconnectedB, reconnectedC]);
      assert.deepEqual(afterReconnectLeaks, [false, false], 'Revoked users rejoined a space room after reconnect');
      assert.deepEqual(afterSyncLeaks, [false, false], 'Explicit room sync left revoked users subscribed to a space room');
      throw new DecisionPending('Q10: immediate room eviction before explicit sync/reconnect needs product decision', [
        'leave and removal persisted', 'lists and search excluded former members', 'sync and reconnect showed zero spaces', 'reconnected sockets received no correlated space event',
      ]);
    } finally { for (const socket of sockets) socket.disconnect(); }
  },
}, {
  id: 'FR-SPC-03', module: 'SPC',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Pending Approval', type: 'department' }, expectedStatus: 201 });
    const space = created.data.space;
    const updated = await request(`/api/spaces/${space._id}`, { method: 'PUT', token: a.token, body: { settings: { requireApproval: true } } });
    assert.equal(updated.data.space.settings.requireApproval, true);
    for (let attempt = 0; attempt < 2; attempt++) {
      const joined = await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: space.inviteCode } });
      assert.match(joined.payload.message, /waiting for admin approval/i);
    }
    const list = await request('/api/spaces', { token: b.token });
    assert.ok(!list.data.spaces.some((item) => item._id === space._id));
    await request(`/api/spaces/${space._id}`, { token: b.token, expectedStatus: 403 });
    await db(async (connection) => {
      const stored = await connection.collection('spaces').findOne({ _id: new connection.base.Types.ObjectId(space._id) });
      assert.equal(stored.pendingRequests.length, 1);
      assert.equal(String(stored.pendingRequests[0].userId), b.userId);
      assert.ok(!stored.members.some((member) => String(member.userId) === b.userId));
    });
    throw new DecisionPending('Q14: pending-join client state and approval completion need product decision', [
      'requireApproval persisted', 'repeat join created one pending request', 'requester has no membership or channel detail access',
    ]);
  },
}];

// Membership and room state must be independent for each lifecycle case.
for (const item of cases) await runModule(`spaces-${item.id.slice(-2).toLowerCase()}`, [item]);
