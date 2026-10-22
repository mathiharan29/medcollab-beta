import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { DecisionPending } from '../src/runner.mjs';
import { capturedOtp } from '../src/fixtures.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';

async function spaceFor(identity, request, name, members = ['B']) {
  const a = await identity('A');
  const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name, type: 'department' }, expectedStatus: 201 });
  const people = { A: a };
  for (const label of members) {
    people[label] = await identity(label);
    await request('/api/spaces/join', { method: 'POST', token: people[label].token, body: { inviteCode: created.data.space.inviteCode } });
  }
  return { ...people, space: created.data.space, channelId: created.data.channels.find((item) => item.name === 'general')._id };
}

async function handoff(request, f, token = f.A.token, toUserId = f.B.userId) {
  return (await request('/api/handoffs', { method: 'POST', token, body: { spaceId: f.space._id, channelId: f.channelId, toUserId, shiftDate: '2030-01-15T00:00:00.000Z', shiftType: 'night', shiftSummary: 'Synthetic integrated shift', patients: [{ bedNumber: 'J-01', clinicalAlias: 'Synthetic integrated patient', pendingTasks: ['Synthetic ECG', 'Synthetic handoff review'], isFlagged: true }] }, expectedStatus: 201 })).data.handoff;
}

const cases = [{
  id: 'FR-JRN-01', module: 'JRN', timeoutMs: 30000,
  run: async ({ identity, request, db, origin, inbox }) => {
    const f = await spaceFor(identity, request, 'Synthetic Onboard Chat Handoff');
    const socketA = await connectSocket(null, origin, f.A.token);
    const socketB = await connectSocket(null, origin, f.B.token);
    try {
      const send = async (person, text) => (await request(`/api/channels/${f.channelId}/messages`, { method: 'POST', token: person.token, body: { content: { text } }, expectedStatus: 201 })).data.message;
      const first = await send(f.A, 'Synthetic A to B integrated');
      const second = await send(f.B, 'Synthetic B to A integrated');
      const draft = await handoff(request, f);
      const receivedNotice = waitFor(socketB, 'new_notification', (item) => item?.type === 'handoff_received' && item?.referenceId === draft._id);
      const submitEvent = waitFor(socketB, 'handoff_submitted', (item) => item?.handoffId === draft._id);
      const submitted = (await request(`/api/handoffs/${draft._id}/submit`, { method: 'POST', token: f.A.token })).data.handoff;
      assert.equal((await submitEvent).status, 'submitted');
      assert.equal((await receivedNotice).referenceId, draft._id);
      assert.equal(submitted.status, 'submitted');
      const ackNotice = waitFor(socketA, 'new_notification', (item) => item?.type === 'handoff_acknowledged' && item?.referenceId === draft._id);
      const acknowledged = (await request(`/api/handoffs/${draft._id}/acknowledge`, { method: 'POST', token: f.B.token, body: { note: 'Synthetic accepted' } })).data.handoff;
      assert.equal((await ackNotice).referenceId, draft._id);
      assert.equal(acknowledged.status, 'acknowledged');
      const login = async (person) => {
        await request('/api/auth/request-otp', { method: 'POST', body: { phone: person.phone } });
        const result = await request('/api/auth/verify-otp', { method: 'POST', body: { phone: person.phone, otp: await capturedOtp(inbox, person.phone) } });
        assert.equal(result.data.user._id, person.userId);
        return result.data.accessToken;
      };
      const [tokenA, tokenB] = await Promise.all([login(f.A), login(f.B)]);
      const spacesB = (await request('/api/spaces', { token: tokenB })).data.spaces;
      assert.ok(spacesB.some((item) => item._id === f.space._id));
      const messages = (await request(`/api/channels/${f.channelId}/messages`, { token: tokenB })).data.messages;
      assert.deepEqual(new Set(messages.map((item) => item._id)), new Set([first._id, second._id]));
      assert.deepEqual(new Set(messages.map((item) => item.content.text)), new Set(['Synthetic A to B integrated', 'Synthetic B to A integrated']));
      const detail = (await request(`/api/handoffs/${draft._id}`, { token: tokenB })).data.handoff;
      assert.equal(detail.status, 'acknowledged');
      assert.equal(detail.patients[0].clinicalAlias, 'Synthetic integrated patient');
      const senderInbox = (await request('/api/notifications', { token: tokenA })).data.notifications;
      const receiverInbox = (await request('/api/notifications', { token: tokenB })).data.notifications;
      assert.ok(senderInbox.some((item) => item.referenceId === draft._id && item.type === 'handoff_acknowledged'));
      assert.ok(receiverInbox.some((item) => item.referenceId === draft._id && item.type === 'handoff_received'));
      await db(async (connection) => {
        const id = (value) => new connection.base.Types.ObjectId(value);
        assert.equal(await connection.collection('messages').countDocuments({ channelId: id(f.channelId) }), 2, 'Handoff lifecycle must not be credited as an invented system message');
        assert.equal(await connection.collection('handoffs').countDocuments({ _id: id(draft._id), status: 'acknowledged' }), 1);
        const stored = await connection.collection('spaces').findOne({ _id: id(f.space._id) });
        assert.deepEqual(new Set(stored.members.map((item) => String(item.userId))), new Set([f.A.userId, f.B.userId]));
      });
    } finally { socketA.disconnect(); socketB.disconnect(); }
  },
}, {
  id: 'FR-JRN-02', module: 'JRN', timeoutMs: 30000,
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), d = await identity('D');
    await request('/api/users/me', { method: 'PUT', token: d.token, body: { notifications: { allowMessageRequestsFromAnyone: true } } });
    const lookup = (await request(`/api/users/lookup?phone=${encodeURIComponent(d.phone)}`, { token: a.token })).data;
    assert.equal(lookup.canRequest, true);
    assert.equal(lookup.canMessage, false);
    const created = await request('/api/message-requests', { method: 'POST', token: a.token, body: { toUserId: d.userId, introMessage: 'Synthetic integrated consent' }, expectedStatus: 201 });
    const requestId = created.data.request.id;
    const received = (await request('/api/message-requests?direction=received', { token: d.token })).data.requests;
    assert.ok(received.some((item) => item.id === requestId));
    let accepted, acceptanceError;
    try { accepted = await request(`/api/message-requests/${requestId}/accept`, { method: 'POST', token: d.token }); }
    catch (error) { acceptanceError = error; }
    if (acceptanceError) {
      await db(async (connection) => {
        const id = (value) => new connection.base.Types.ObjectId(value);
        const row = await connection.collection('messagerequests').findOne({ _id: id(requestId) });
        assert.equal(row.status, 'accepted');
        assert.equal(await connection.collection('channels').countDocuments({ type: 'direct', members: { $all: [id(a.userId), id(d.userId)] } }), 0);
      });
      throw acceptanceError;
    }
    const channelId = accepted.data.channel._id;
    assert.equal(accepted.data.request.status, 'accepted');
    const after = (await request(`/api/users/lookup?phone=${encodeURIComponent(d.phone)}`, { token: a.token })).data;
    assert.equal(after.canMessage, true);
    const first = (await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body: { content: { text: 'Synthetic consent hello' } }, expectedStatus: 201 })).data.message;
    const second = (await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: d.token, body: { content: { text: 'Synthetic consent reply' } }, expectedStatus: 201 })).data.message;
    await request(`/api/channels/${channelId}/messages/read`, { method: 'POST', token: d.token, body: { messageIds: [first._id] } });
    for (const person of [a, d]) {
      const dm = (await request('/api/channels/dm', { token: person.token })).data.channels;
      assert.equal(dm.filter((item) => item._id === channelId).length, 1);
      const history = (await request(`/api/channels/${channelId}/messages`, { token: person.token })).data.messages;
      assert.deepEqual(new Set(history.map((item) => item._id)), new Set([first._id, second._id]));
    }
    await db(async (connection) => {
      const id = (value) => new connection.base.Types.ObjectId(value);
      assert.equal(await connection.collection('channels').countDocuments({ _id: id(channelId), type: 'direct' }), 1);
      assert.equal(await connection.collection('messages').countDocuments({ channelId: id(channelId) }), 2);
      const stored = await connection.collection('messages').findOne({ _id: id(first._id) });
      assert.ok(stored.readBy.some((item) => String(item.userId) === d.userId));
    });
    const inbox = (await request('/api/notifications', { token: d.token })).data.notifications;
    assert.ok(inbox.some((item) => item.referenceId === first._id));
  },
}, {
  id: 'FR-JRN-03', module: 'JRN', timeoutMs: 30000,
  run: async ({ identity, request, db, origin }) => {
    const f = await spaceFor(identity, request, 'Synthetic Responsibility Transfer', ['B', 'C']);
    const socketA = await connectSocket(null, origin, f.A.token);
    const socketC = await connectSocket(null, origin, f.C.token);
    try {
      const d = await handoff(request, f);
      await request(`/api/handoffs/${d._id}/submit`, { method: 'POST', token: f.A.token });
      const cant = (await request(`/api/handoffs/${d._id}/notes`, { method: 'POST', token: f.B.token, body: { text: 'Synthetic cannot cover', kind: 'cant_cover' } })).data.handoff;
      assert.equal(cant.writeBackNotes.at(-1).kind, 'cant_cover');
      const reassignedEvent = waitFor(socketC, 'handoff_reassigned', (event) => event?.handoffId === d._id && event?.toUserId === f.C.userId);
      const receivedNotice = waitFor(socketC, 'new_notification', (event) => event?.referenceId === d._id && event?.type === 'handoff_received');
      const reassigned = (await request(`/api/handoffs/${d._id}/reassign`, { method: 'POST', token: f.B.token, body: { toUserId: f.C.userId, note: 'Synthetic C takeover' } })).data.handoff;
      assert.equal((await reassignedEvent).previousToUserId, f.B.userId);
      assert.equal((await receivedNotice).referenceId, d._id);
      assert.equal(reassigned.status, 'submitted');
      assert.equal(reassigned.acknowledgedAt, null);
      const ackNotice = waitFor(socketA, 'new_notification', (event) => event?.referenceId === d._id && event?.type === 'handoff_acknowledged');
      const acknowledged = (await request(`/api/handoffs/${d._id}/acknowledge`, { method: 'POST', token: f.C.token, body: { note: 'Synthetic C accepted' } })).data.handoff;
      assert.equal((await ackNotice).referenceId, d._id);
      assert.equal(acknowledged.status, 'acknowledged');
      const senderDetail = (await request(`/api/handoffs/${d._id}`, { token: f.A.token })).data.handoff;
      assert.equal(senderDetail.toUserId._id, f.C.userId);
      assert.equal(senderDetail.patients[0].clinicalAlias, 'Synthetic integrated patient');
      assert.deepEqual(senderDetail.patients[0].pendingTasks, ['Synthetic ECG', 'Synthetic handoff review']);
      assert.deepEqual(senderDetail.writeBackNotes.map((item) => item.kind), ['cant_cover', 'reassign']);
      assert.equal(senderDetail.assignmentHistory.length, 1);
      const receivedC = (await request('/api/handoffs?type=received', { token: f.C.token })).data.handoffs;
      const receivedB = (await request('/api/handoffs?type=received', { token: f.B.token })).data.handoffs;
      assert.ok(receivedC.some((item) => item._id === d._id));
      assert.ok(!receivedB.some((item) => item._id === d._id));
      const history = (await request(`/api/spaces/${f.space._id}/handoffs`, { token: f.A.token })).data.handoffs;
      assert.ok(history.some((item) => item._id === d._id && item.status === 'acknowledged'));
      await db(async (connection) => {
        const row = await connection.collection('handoffs').findOne({ _id: new connection.base.Types.ObjectId(d._id) });
        assert.equal(String(row.toUserId), f.C.userId);
        assert.equal(row.assignmentHistory.length, 1);
        assert.equal(row.patients[0].pendingTasks.length, 2);
      });
    } finally { socketA.disconnect(); socketC.disconnect(); }
  },
}, {
  id: 'FR-JRN-04', module: 'JRN', timeoutMs: 30000,
  run: async ({ identity, request, db, origin }) => {
    const f = await spaceFor(identity, request, 'Synthetic Leave Rejoin Journey');
    const root = (await request(`/api/channels/${f.channelId}/messages`, { method: 'POST', token: f.A.token, body: { content: { text: 'Synthetic journey search root' } }, expectedStatus: 201 })).data.message;
    const reply = (await request(`/api/channels/${f.channelId}/messages/${root._id}/reply`, { method: 'POST', token: f.B.token, body: { content: { text: 'Synthetic journey Needl reply' } }, expectedStatus: 201 })).data.message;
    const socketA = await connectSocket(null, origin, f.A.token);
    const socketB = await connectSocket(null, origin, f.B.token);
    try {
      const sync = async (count) => {
        const ack = waitFor(socketB, 'sync_space_rooms', (event) => event?.success === true);
        socketB.emit('sync_space_rooms');
        const response = await ack;
        assert.equal(response.spaceCount, count, 'Socket room count must match current space membership');
        return response;
      };
      const spacesBeforeLeave = (await request('/api/spaces', { token: f.B.token })).data.spaces;
      assert.ok(spacesBeforeLeave.some((item) => item._id === f.space._id));
      await sync(spacesBeforeLeave.length);
      const beforeNeedl = (await request('/api/users/me/needl', { token: f.B.token })).data.threads;
      assert.ok(beforeNeedl.some((item) => item.rootMessageId === root._id));
      const beforeSearch = (await request('/api/search?q=journey%20search%20root&type=messages', { token: f.B.token })).data.messages;
      assert.ok(beforeSearch.some((item) => item._id === root._id));
      await request(`/api/spaces/${f.space._id}/leave`, { method: 'POST', token: f.B.token });
      const spacesAfterLeave = (await request('/api/spaces', { token: f.B.token })).data.spaces;
      assert.ok(!spacesAfterLeave.some((item) => item._id === f.space._id));
      const searchAfterLeave = (await request('/api/search?q=journey%20search%20root&type=messages', { token: f.B.token })).data.messages;
      assert.ok(!searchAfterLeave.some((item) => item._id === root._id));
      const needlAfterLeave = (await request('/api/users/me/needl', { token: f.B.token })).data.threads;
      assert.ok(!needlAfterLeave.some((item) => item.rootMessageId === root._id));
      await sync(spacesAfterLeave.length);
      const note = 'synthetic-journey-after-sync';
      const predicate = (event) => event?.userId === f.A.userId && event?.availability?.note === note;
      const ownerEvent = waitFor(socketA, 'presence_update', predicate, 3000);
      const leaked = waitFor(socketB, 'presence_update', predicate, 1500).then(() => true, () => false);
      await request('/api/users/me/availability', { method: 'PUT', token: f.A.token, body: { status: 'on_call', note } });
      await ownerEvent;
      const staleAfterSync = await leaked;
      const invite = (await request(`/api/spaces/${f.space._id}`, { token: f.A.token })).data.space.inviteCode;
      await request('/api/spaces/join', { method: 'POST', token: f.B.token, body: { inviteCode: invite } });
      const spacesAfterJoin = (await request('/api/spaces', { token: f.B.token })).data.spaces;
      assert.ok(spacesAfterJoin.some((item) => item._id === f.space._id));
      await sync(spacesAfterJoin.length);
      const searchAfterJoin = (await request('/api/search?q=journey%20search%20root&type=messages', { token: f.B.token })).data.messages;
      assert.ok(searchAfterJoin.some((item) => item._id === root._id));
      const needlAfterJoin = (await request('/api/users/me/needl', { token: f.B.token })).data.threads;
      assert.ok(needlAfterJoin.some((item) => item.rootMessageId === root._id));
      const thread = (await request(`/api/channels/${f.channelId}/messages/${root._id}/thread`, { token: f.B.token })).data.replies;
      assert.ok(thread.some((item) => item._id === reply._id));
      await db(async (connection) => {
        const space = await connection.collection('spaces').findOne({ _id: new connection.base.Types.ObjectId(f.space._id) });
        assert.ok(space.members.some((item) => String(item.userId) === f.B.userId));
        assert.equal(await connection.collection('messages').countDocuments({ _id: new connection.base.Types.ObjectId(reply._id) }), 1);
      });
      assert.equal(staleAfterSync, false, 'Explicit room sync left the departed user receiving a correlated space event');
      throw new DecisionPending('Q10: immediate event eviction before explicit sync remains undecided', ['Leave/rejoin persistence and lists verified', 'Search and Needl exclusion/recovery verified', 'Explicit socket sync room counts verified']);
    } finally { socketA.disconnect(); socketB.disconnect(); }
  },
}];

const selected = process.env.VOCLE_CASE_IDS?.split(',').filter(Boolean);
await runModule('journeys', selected ? cases.filter((item) => selected.includes(item.id)) : cases);
