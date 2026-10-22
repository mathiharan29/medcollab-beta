import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';

async function fixture(identity, request, name, labels = ['A', 'B']) {
  const people = Object.fromEntries(await Promise.all(labels.map(async (label) => [label, await identity(label)])));
  const created = await request('/api/spaces', { method: 'POST', token: people.A.token, body: { name, type: 'department' }, expectedStatus: 201 });
  for (const label of labels.filter((item) => item !== 'A')) await request('/api/spaces/join', { method: 'POST', token: people[label].token, body: { inviteCode: created.data.space.inviteCode } });
  return { people, channelId: created.data.channels.find((channel) => channel.name === 'general')._id };
}

const cases = [{
  id: 'FR-SOC-01', module: 'SOC',
  run: async ({ identity, request, db, origin }) => {
    const { people, channelId } = await fixture(identity, request, 'Synthetic Reaction Switch');
    const path = `/api/channels/${channelId}/messages`;
    const root = (await request(path, { method: 'POST', token: people.A.token, body: { content: { text: 'Synthetic reaction target' } }, expectedStatus: 201 })).data.message;
    const socket = await connectSocket(null, origin, people.A.token);
    try {
      const joined = waitFor(socket, 'join_channel', (event) => event?.success === true && event.channelId === channelId);
      socket.emit('join_channel', { channelId }); await joined;
      const react = async (person, emoji) => {
        const event = waitFor(socket, 'message_updated', (payload) => payload?.messageId === root._id && Array.isArray(payload.reactions));
        const response = await request(`${path}/${root._id}/react`, { method: 'POST', token: person.token, body: { emoji } });
        const update = await event;
        assert.deepEqual(new Set(update.reactions.map((item) => item.emoji)), new Set(response.data.reactions.map((item) => item.emoji)));
        return response.data.reactions;
      };
      await react(people.A, '👍');
      await react(people.B, '👍');
      await react(people.B, '❤️');
      await react(people.A, '👍');
      const listed = await request(path, { token: people.B.token });
      const final = listed.data.messages.find((item) => item._id === root._id)?.reactions;
      assert.ok(final);
      const owners = final.flatMap((item) => item.userIds.map((id) => [item.emoji, id]));
      await db(async (connection) => {
        const stored = await connection.collection('messages').findOne({ _id: new connection.base.Types.ObjectId(root._id) });
        assert.deepEqual(new Set(stored.reactions.map((item) => item.emoji)), new Set(final.map((item) => item.emoji)));
      });
      assert.deepEqual(owners.filter(([, id]) => id === people.B.userId).map(([emoji]) => emoji), ['❤️'], 'Switching emoji must replace B prior reaction');
      assert.equal(owners.filter(([, id]) => id === people.A.userId).length, 0, 'A removal must leave B intact');
    } finally { socket.disconnect(); }
  },
}, {
  id: 'FR-SOC-02', module: 'SOC',
  run: async ({ identity, request, db }) => {
    const { people, channelId } = await fixture(identity, request, 'Synthetic Reaction Rejection');
    const path = `/api/channels/${channelId}/messages`;
    const root = (await request(path, { method: 'POST', token: people.A.token, body: { content: { text: 'Synthetic reject target' } }, expectedStatus: 201 })).data.message;
    const reactPath = `${path}/${root._id}/react`;
    const initial = await request(reactPath, { method: 'POST', token: people.B.token, body: { emoji: '👍' } });
    assert.deepEqual(initial.data.reactions.map((item) => item.emoji), ['👍']);
    for (const body of [{}, { emoji: '' }]) {
      const rejected = await request(reactPath, { method: 'POST', token: people.B.token, body, expectedStatus: 400 });
      assert.equal(rejected.payload.success, false);
    }
    let reload = await request(path, { token: people.A.token });
    assert.deepEqual(reload.data.messages.find((item) => item._id === root._id).reactions.map((item) => item.emoji), ['👍']);
    await request(`${path}/${root._id}`, { method: 'DELETE', token: people.A.token });
    const deletedReaction = await request(reactPath, { method: 'POST', token: people.B.token, body: { emoji: '❤️' }, expectedStatus: 400 });
    assert.equal(deletedReaction.payload.success, false);
    await db(async (connection) => {
      const stored = await connection.collection('messages').findOne({ _id: new connection.base.Types.ObjectId(root._id) });
      assert.equal(stored.isDeleted, true);
      assert.deepEqual(stored.reactions, [], 'Soft deletion clears old reactions and rejected additions must not restore them');
    });
  },
}, {
  id: 'FR-SOC-03', module: 'SOC',
  run: async ({ identity, request, db }) => {
    const { people, channelId } = await fixture(identity, request, 'Synthetic Pin Capacity');
    const path = `/api/channels/${channelId}/messages`;
    const messages = [];
    for (let index = 1; index <= 6; index++) messages.push((await request(path, { method: 'POST', token: people.A.token, body: { content: { text: `Synthetic pin ${index}` } }, expectedStatus: 201 })).data.message);
    const pin = (message) => `/api/channels/${channelId}/pin/${message._id}`;
    for (const message of messages.slice(0, 5)) await request(pin(message), { method: 'POST', token: people.B.token });
    const sixth = await request(pin(messages[5]), { method: 'POST', token: people.B.token, expectedStatus: 400 });
    assert.equal(sixth.payload.success, false);
    await request(pin(messages[1]), { method: 'DELETE', token: people.A.token });
    const replacement = await request(pin(messages[5]), { method: 'POST', token: people.A.token });
    assert.equal(replacement.data.pinnedMessages.length, 5);
    const detail = await request(`/api/channels/${channelId}`, { token: people.B.token });
    const pins = detail.data.channel.pinnedMessages;
    assert.equal(pins.length, 5);
    assert.deepEqual(new Set(pins.map((item) => item.messageId._id)), new Set([messages[0], ...messages.slice(2)].map((item) => item._id)));
    for (const entry of pins) {
      assert.ok(entry.messageId.senderId._id);
      assert.ok(entry.pinnedBy);
      assert.ok(Date.parse(entry.pinnedAt));
    }
    await db(async (connection) => {
      const stored = await connection.collection('channels').findOne({ _id: new connection.base.Types.ObjectId(channelId) });
      assert.equal(stored.pinnedMessages.length, 5);
      assert.deepEqual(new Set(stored.pinnedMessages.map((item) => String(item.messageId))), new Set(pins.map((item) => item.messageId._id)));
    });
  },
}, {
  id: 'FR-SOC-05', module: 'SOC',
  run: async ({ identity, request, db }) => {
    const { people } = await fixture(identity, request, 'Synthetic Group Receipts', ['A', 'B', 'C']);
    const group = await request('/api/channels/dm/group', { method: 'POST', token: people.A.token, body: { userIds: [people.B.userId, people.C.userId] } });
    const channelId = group.data.channel._id;
    assert.deepEqual(new Set(group.data.channel.members.map((item) => item._id)), new Set([people.A.userId, people.B.userId, people.C.userId]));
    const path = `/api/channels/${channelId}/messages`;
    const messages = [];
    for (let index = 1; index <= 3; index++) messages.push((await request(path, { method: 'POST', token: people.A.token, body: { content: { text: `Synthetic read receipt ${index}` } }, expectedStatus: 201 })).data.message);
    const mark = (token, ids) => request(`${path}/read`, { method: 'POST', token, body: { messageIds: ids } });
    await mark(people.B.token, [messages[0]._id]);
    await mark(people.C.token, [messages[1]._id]);
    const beforeRepeat = await db(async (connection) => connection.collection('messages').find({ _id: { $in: messages.slice(0, 2).map((item) => new connection.base.Types.ObjectId(item._id)) } }).toArray());
    await mark(people.B.token, [messages[0]._id]);
    await mark(people.C.token, [messages[1]._id]);
    await mark(people.C.token, [messages[0]._id]);
    const afterRepeat = await request(path, { token: people.A.token });
    const byId = new Map(afterRepeat.data.messages.map((item) => [item._id, item]));
    assert.deepEqual(new Set(byId.get(messages[0]._id).readBy.map((entry) => entry.userId._id)), new Set([people.B.userId, people.C.userId]));
    assert.deepEqual(byId.get(messages[1]._id).readBy.map((entry) => entry.userId._id), [people.C.userId]);
    for (const [message, person] of [[messages[0], people.B], [messages[1], people.C]]) {
      const original = beforeRepeat.find((item) => String(item._id) === message._id).readBy.find((item) => String(item.userId) === person.userId);
      const refreshed = byId.get(message._id).readBy.find((item) => item.userId._id === person.userId);
      assert.equal(new Date(refreshed.readAt).getTime(), original.readAt.getTime(), 'Repeated mark-read must not replace timestamp');
    }
    const preference = await request('/api/users/me', { method: 'PUT', token: people.B.token, body: { notifications: { readReceiptsEnabled: false } } });
    assert.equal(preference.data.user.notifications.readReceiptsEnabled, false);
    await mark(people.B.token, [messages[2]._id]);
    await mark(people.C.token, [messages[2]._id]);
    await db(async (connection) => {
      const stored = await connection.collection('messages').findOne({ _id: new connection.base.Types.ObjectId(messages[2]._id) });
      assert.deepEqual(stored.readBy.map((item) => String(item.userId)), [people.C.userId], 'B opt-out must prevent a new B receipt');
      assert.equal(await connection.collection('messages').countDocuments({ channelId: new connection.base.Types.ObjectId(channelId) }), 3);
    });
  },
}, {
  id: 'FR-SOC-04', module: 'SOC',
  run: async ({ identity, request, db }) => {
    const { people, channelId } = await fixture(identity, request, 'Synthetic Pin Idempotency', ['A']);
    const path = `/api/channels/${channelId}/messages`;
    const messages = [];
    for (let index = 1; index <= 5; index++) messages.push((await request(path, { method: 'POST', token: people.A.token, body: { content: { text: `Synthetic repin ${index}` } }, expectedStatus: 201 })).data.message);
    const pin = (message) => `/api/channels/${channelId}/pin/${message._id}`;
    await request(pin(messages[0]), { method: 'POST', token: people.A.token });
    await request(pin(messages[0]), { method: 'POST', token: people.A.token, expectedStatus: 409 });
    for (const message of messages.slice(1)) await request(pin(message), { method: 'POST', token: people.A.token });
    const atCap = await request(pin(messages[0]), { method: 'POST', token: people.A.token, expectedStatus: 400 });
    assert.equal(atCap.payload.success, false);
    const absent = await request(`/api/channels/${channelId}/pin/6ac8f400000000000000ffff`, { method: 'DELETE', token: people.A.token });
    assert.equal(absent.data.pinnedMessages.length, 5);
    await db(async (connection) => {
      const stored = await connection.collection('channels').findOne({ _id: new connection.base.Types.ObjectId(channelId) });
      assert.deepEqual(new Set(stored.pinnedMessages.map((item) => String(item.messageId))), new Set(messages.map((item) => item._id)));
    });
  },
}];

for (const item of cases) await runModule(`social-${item.id.slice(-2).toLowerCase()}`, [item]);
