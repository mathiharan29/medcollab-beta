import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { DecisionPending } from '../src/runner.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';

async function spaceFixture(identity, request, name, labels = ['A', 'B']) {
  const people = Object.fromEntries(await Promise.all(labels.map(async (label) => [label, await identity(label)])));
  const created = await request('/api/spaces', { method: 'POST', token: people.A.token, body: { name, type: 'department' }, expectedStatus: 201 });
  for (const label of labels.filter((item) => item !== 'A')) await request('/api/spaces/join', { method: 'POST', token: people[label].token, body: { inviteCode: created.data.space.inviteCode } });
  return { people, space: created.data.space, channelId: created.data.channels.find((channel) => channel.name === 'general')._id };
}

const cases = [{
  id: 'FR-THR-01', module: 'THR',
  run: async ({ identity, request, db, origin }) => {
    const { people, channelId } = await spaceFixture(identity, request, 'Synthetic Thread Counts');
    const path = `/api/channels/${channelId}/messages`;
    const root = (await request(path, { method: 'POST', token: people.A.token, body: { content: { text: 'Synthetic thread root' } }, expectedStatus: 201 })).data.message;
    const sockets = { A: await connectSocket(null, origin, people.A.token), B: await connectSocket(null, origin, people.B.token) };
    try {
      const replies = [];
      for (const [sender, recipient, text] of [
        ['B', 'A', 'Synthetic first reply'],
        ['A', 'B', 'Synthetic second reply with '.repeat(7)],
      ]) {
        const notification = waitFor(sockets[recipient], 'new_notification', (payload) => payload?.body === text.slice(0, 100));
        const reply = (await request(`${path}/${root._id}/reply`, { method: 'POST', token: people[sender].token, body: { content: { text } }, expectedStatus: 201 })).data.message;
        replies.push(reply);
        assert.equal(reply.threadId, root._id);
        assert.equal((await notification).referenceId, reply._id);
      }
      const roots = await request(path, { token: people.B.token });
      assert.deepEqual(roots.data.messages.map((item) => item._id), [root._id]);
      const refreshed = roots.data.messages[0];
      assert.equal(refreshed.replyCount, 2);
      assert.equal(refreshed.lastReply.senderId, people.A.userId);
      assert.equal(refreshed.lastReply.text, 'Synthetic second reply with '.repeat(7).slice(0, 100));
      const thread = await request(`${path}/${root._id}/thread`, { token: people.B.token });
      assert.equal(thread.data.rootMessage._id, root._id);
      assert.deepEqual(thread.data.replies.map((item) => item._id), replies.map((item) => item._id));
      const needl = await request('/api/users/me/needl', { token: people.B.token });
      const entry = needl.data.threads.find((item) => item.rootMessageId === root._id);
      assert.equal(entry.channelId, channelId);
      assert.equal(entry.replyCount, 2);
      await db(async (connection) => {
        const saved = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(channelId) }).toArray();
        assert.equal(saved.length, 3);
        assert.equal(saved.find((item) => String(item._id) === root._id).replyCount, 2);
        assert.deepEqual(new Set(saved.filter((item) => item.threadId).map((item) => String(item._id))), new Set(replies.map((item) => item._id)));
      });
    } finally { sockets.A.disconnect(); sockets.B.disconnect(); }
  },
}, {
  id: 'FR-THR-02', module: 'THR',
  run: async ({ identity, request, db }) => {
    const { people, channelId } = await spaceFixture(identity, request, 'Synthetic Thread Cursor');
    const path = `/api/channels/${channelId}/messages`;
    const root = (await request(path, { method: 'POST', token: people.A.token, body: { content: { text: 'Synthetic pagination root' } }, expectedStatus: 201 })).data.message;
    const replies = [];
    for (let index = 1; index <= 3; index++) replies.push((await request(`${path}/${root._id}/reply`, { method: 'POST', token: people.B.token, body: { content: { text: `Synthetic reply ${index}` } }, expectedStatus: 201 })).data.message);
    const first = await request(`${path}/${root._id}/thread?limit=2`, { token: people.A.token });
    assert.deepEqual(first.data.replies.map((item) => item._id), replies.slice(1).map((item) => item._id));
    assert.equal(first.data.hasMore, true);
    const older = await request(`${path}/${root._id}/thread?limit=2&before=${first.data.replies[0]._id}`, { token: people.A.token });
    assert.deepEqual(older.data.replies.map((item) => item._id), [replies[0]._id]);
    assert.equal(older.data.hasMore, false);
    assert.equal(new Set([...first.data.replies, ...older.data.replies].map((item) => item._id)).size, 3);
    await request(`${path}/${replies[1]._id}`, { method: 'DELETE', token: people.B.token });
    const afterDelete = await request(`${path}/${root._id}/thread?limit=2`, { token: people.A.token });
    assert.deepEqual(afterDelete.data.replies.map((item) => item._id), [replies[0]._id, replies[2]._id]);
    assert.equal(afterDelete.data.hasMore, false);
    await db(async (connection) => {
      const stored = await connection.collection('messages').findOne({ _id: new connection.base.Types.ObjectId(replies[1]._id) });
      assert.equal(stored.isDeleted, true);
      assert.equal(stored.content.text, 'This message was deleted');
    });
  },
}, {
  id: 'FR-THR-03', module: 'THR',
  prerequisiteSeed: '41 active thread roots and one archived-channel root inserted directly with distinct updatedAt values to isolate Needl selection',
  run: async ({ identity, request, db }) => {
    const { people, space, channelId } = await spaceFixture(identity, request, 'Synthetic Needl Limit', ['A']);
    const archived = (await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: people.A.token, body: { name: 'archived-needl' }, expectedStatus: 201 })).data.channel;
    const ids = Array.from({ length: 42 }, (_, index) => `6ac8f300000000000000${(index + 1).toString(16).padStart(4, '0')}`);
    await db(async (connection) => {
      const objectId = (value) => new connection.base.Types.ObjectId(value);
      const rows = ids.map((id, index) => ({
        _id: objectId(id), channelId: objectId(index === 41 ? archived._id : channelId), spaceId: objectId(space._id), senderId: objectId(people.A.userId),
        type: 'text', content: { text: `Synthetic Needl root ${index + 1}` }, threadId: null, replyCount: 1, isDeleted: false,
        createdAt: new Date(Date.UTC(2026, 0, 1) + index * 1000), updatedAt: new Date(Date.UTC(2026, 0, 1) + index * 1000),
      }));
      assert.equal((await connection.collection('messages').insertMany(rows)).insertedCount, 42);
    });
    await request(`/api/channels/${archived._id}`, { method: 'DELETE', token: people.A.token });
    const needl = await request('/api/users/me/needl', { token: people.A.token });
    assert.equal(needl.data.threads.length, 40);
    assert.deepEqual(needl.data.threads.map((item) => item.rootMessageId), ids.slice(1, 41).reverse());
    assert.ok(needl.data.threads.every((item) => item.channelId === channelId && item.spaceId === space._id && item.channelName === 'general'));
    assert.ok(!needl.data.threads.some((item) => item.rootMessageId === ids[41]));
    await db(async (connection) => {
      assert.equal(await connection.collection('messages').countDocuments({ channelId: new connection.base.Types.ObjectId(channelId) }), 41);
      assert.equal((await connection.collection('channels').findOne({ _id: new connection.base.Types.ObjectId(archived._id) })).isArchived, true);
    });
  },
}, {
  id: 'FR-THR-04', module: 'THR',
  run: async ({ identity, request, db, origin }) => {
    const { people, channelId } = await spaceFixture(identity, request, 'Synthetic Thread Revision');
    const path = `/api/channels/${channelId}/messages`;
    const root = (await request(path, { method: 'POST', token: people.A.token, body: { content: { text: 'Synthetic revision root' } }, expectedStatus: 201 })).data.message;
    const listener = await connectSocket(null, origin, people.A.token);
    try {
      const text = 'Synthetic reply before revision';
      const notification = waitFor(listener, 'new_notification', (payload) => payload?.body === text);
      const reply = (await request(`${path}/${root._id}/reply`, { method: 'POST', token: people.B.token, body: { content: { text } }, expectedStatus: 201 })).data.message;
      await notification;
      const edited = await request(`${path}/${reply._id}`, { method: 'PUT', token: people.B.token, body: { content: { text: 'Synthetic reply after revision' } } });
      assert.equal(edited.data.message.content.text, 'Synthetic reply after revision');
      let thread = await request(`${path}/${root._id}/thread`, { token: people.A.token });
      assert.equal(thread.data.replies[0].content.text, 'Synthetic reply after revision');
      const rootAfterEdit = thread.data.rootMessage;
      await request(`${path}/${reply._id}`, { method: 'DELETE', token: people.B.token });
      thread = await request(`${path}/${root._id}/thread`, { token: people.A.token });
      assert.deepEqual(thread.data.replies, []);
      const needl = await request('/api/users/me/needl', { token: people.A.token });
      const entry = needl.data.threads.find((item) => item.rootMessageId === root._id);
      await db(async (connection) => {
        const saved = await connection.collection('messages').findOne({ _id: new connection.base.Types.ObjectId(reply._id) });
        assert.equal(saved.isDeleted, true);
        assert.equal(saved.isEdited, true);
      });
      throw new DecisionPending('Q1: expected thread aggregate correction after editing/deleting the latest reply needs product decision', [
        `Reply ${reply._id} edit and soft deletion persisted; thread page excludes deleted reply`,
        `Root after edit: ${JSON.stringify({ replyCount: rootAfterEdit.replyCount, lastReply: rootAfterEdit.lastReply })}`,
        `Root after delete: ${JSON.stringify({ replyCount: thread.data.rootMessage.replyCount, lastReply: thread.data.rootMessage.lastReply })}`,
        `Needl after delete: ${JSON.stringify(entry)}`,
      ]);
    } finally { listener.disconnect(); }
  },
}];

for (const item of cases) await runModule(`threads-${item.id.slice(-2).toLowerCase()}`, [item]);
