import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';

await runModule('channels', [{
  id: 'FR-CH-01', module: 'CH',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Channel Boundaries', type: 'department' }, expectedStatus: 201 })).data.space;
    const valid = [{ name: 'x', description: 'D'.repeat(200) }, { name: 'n'.repeat(80), description: '' }];
    const createdIds = [];
    for (const body of valid) {
      const made = await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: a.token, body, expectedStatus: 201 });
      assert.equal(made.data.channel.name, body.name);
      createdIds.push(made.data.channel._id);
    }
    for (const body of [{ name: 'n'.repeat(81) }, { name: 'Upper' }, { name: 'has space' }, { name: 'valid', description: 'D'.repeat(201) }]) {
      const rejected = await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: a.token, body, expectedStatus: 400 });
      assert.equal(rejected.payload.success, false);
    }
    const list = await request(`/api/spaces/${space._id}/channels`, { token: a.token });
    for (const id of createdIds) assert.equal(list.data.channels.filter((item) => item._id === id).length, 1);
    await db(async (connection) => {
      const channels = await connection.collection('channels').find({ spaceId: new connection.base.Types.ObjectId(space._id) }).toArray();
      assert.equal(channels.length, 5, 'Rejected creates must not persist partial channels');
      assert.deepEqual(new Set(channels.filter((item) => createdIds.includes(String(item._id))).map((item) => item.name)), new Set(valid.map((item) => item.name)));
    });
  },
}, {
  id: 'FR-CH-02', module: 'CH',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Channel Views', type: 'department' }, expectedStatus: 201 })).data.space;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: space.inviteCode } });
    const publicId = (await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: a.token, body: { name: 'public-x' }, expectedStatus: 201 })).data.channel._id;
    const privateId = (await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: a.token, body: { name: 'private-y', isPrivate: true }, expectedStatus: 201 })).data.channel._id;
    for (const viewer of [a, b]) {
      const spaceDetail = await request(`/api/spaces/${space._id}`, { token: viewer.token });
      const channelList = await request(`/api/spaces/${space._id}/channels`, { token: viewer.token });
      const spaces = await request('/api/spaces', { token: viewer.token });
      const surfaces = [spaceDetail.data.space.channels, channelList.data.channels, spaces.data.spaces.find((item) => item._id === space._id).channels];
      for (const entries of surfaces) {
        const ids = new Set(entries.map((item) => item._id));
        assert.ok(ids.has(publicId));
        assert.equal(ids.has(privateId), viewer.userId === a.userId);
      }
      const detail = await request(`/api/channels/${publicId}`, { token: viewer.token });
      assert.equal(detail.data.channel._id, publicId);
    }
    const ownerPrivate = await request(`/api/channels/${privateId}`, { token: a.token });
    assert.equal(ownerPrivate.data.channel._id, privateId);
    await request(`/api/channels/${privateId}`, { token: b.token, expectedStatus: 403 });
    await db(async (connection) => {
      const ids = [publicId, privateId].map((id) => new connection.base.Types.ObjectId(id));
      const stored = await connection.collection('channels').find({ _id: { $in: ids } }).toArray();
      assert.equal(stored.length, 2);
      assert.equal(stored.find((item) => String(item._id) === privateId).isPrivate, true);
    });
  },
}, {
  id: 'FR-CH-04', module: 'CH',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Channel Edit', type: 'department' }, expectedStatus: 201 });
    const space = created.data.space;
    const defaults = created.data.channels;
    const custom = (await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: a.token, body: { name: 'custom-old' }, expectedStatus: 201 })).data.channel;
    await request(`/api/channels/${custom._id}`, { method: 'PUT', token: a.token, body: { name: 'custom-new', description: 'Synthetic changed description' } });
    const reread = await request(`/api/channels/${custom._id}`, { token: a.token });
    assert.equal(reread.data.channel.name, 'custom-new');
    assert.equal(reread.data.channel.description, 'Synthetic changed description');
    for (const channel of defaults) {
      await request(`/api/channels/${channel._id}`, { method: 'PUT', token: a.token, body: { name: 'renamed-default' } });
      const after = await request(`/api/channels/${channel._id}`, { token: a.token });
      assert.equal(after.data.channel.name, channel.name);
      const archived = await request(`/api/channels/${channel._id}`, { method: 'DELETE', token: a.token, expectedStatus: 400 });
      assert.equal(archived.payload.success, false);
    }
    await db(async (connection) => {
      const channels = await connection.collection('channels').find({ spaceId: new connection.base.Types.ObjectId(space._id) }).toArray();
      assert.equal(channels.find((item) => String(item._id) === custom._id).name, 'custom-new');
      for (const channel of defaults) {
        const stored = channels.find((item) => String(item._id) === channel._id);
        assert.equal(stored.name, channel.name);
        assert.equal(stored.isArchived, false);
      }
    });
  },
}, {
  id: 'FR-CH-05', module: 'CH',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Archive', type: 'department' }, expectedStatus: 201 })).data.space;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: space.inviteCode } });
    const channel = (await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: a.token, body: { name: 'archive-x' }, expectedStatus: 201 })).data.channel;
    const rootText = 'Synthetic archive retained root 5081';
    const root = (await request(`/api/channels/${channel._id}/messages`, { method: 'POST', token: a.token, body: { content: { text: rootText } }, expectedStatus: 201 })).data.message;
    await request(`/api/channels/${channel._id}/pin/${root._id}`, { method: 'POST', token: a.token });
    await db(async (connection) => {
      const saved = await connection.collection('channels').findOne({ _id: new connection.base.Types.ObjectId(channel._id) });
      assert.equal(saved.pinnedMessages.length, 1);
      assert.equal(String(saved.pinnedMessages[0].messageId), root._id);
    });
    const archived = await request(`/api/channels/${channel._id}`, { method: 'DELETE', token: a.token });
    assert.match(archived.payload.message, /archived/i);
    for (const viewer of [a, b]) {
      const list = await request(`/api/spaces/${space._id}/channels`, { token: viewer.token });
      assert.ok(!list.data.channels.some((item) => item._id === channel._id));
      const spaceDetail = await request(`/api/spaces/${space._id}`, { token: viewer.token });
      assert.ok(!spaceDetail.data.space.channels.some((item) => item._id === channel._id));
      const search = await request(`/api/search?q=${encodeURIComponent('archive-x')}&type=channels`, { token: viewer.token });
      assert.ok(!search.data.channels.some((item) => item._id === channel._id));
      const messageSearch = await request(`/api/search?q=${encodeURIComponent(rootText)}&type=messages`, { token: viewer.token });
      assert.ok(!messageSearch.data.messages.some((item) => item._id === root._id));
      const denied = await request(`/api/channels/${channel._id}/messages`, { method: 'POST', token: viewer.token, body: { content: { text: 'should not persist after archive' } }, expectedStatus: 403 });
      assert.equal(denied.payload.success, false);
    }
    await db(async (connection) => {
      const id = new connection.base.Types.ObjectId(channel._id);
      const saved = await connection.collection('channels').findOne({ _id: id });
      assert.equal(saved.isArchived, true);
      assert.equal(saved.pinnedMessages.length, 1);
      assert.equal(String(saved.pinnedMessages[0].messageId), root._id);
      const messages = await connection.collection('messages').find({ channelId: id }).toArray();
      assert.deepEqual(messages.map((message) => String(message._id)), [root._id]);
      assert.equal(messages[0].content.text, rootText);
    });
  },
}, {
  id: 'FR-CH-03', module: 'CH',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B');
    const createdSpace = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Channel Rules', type: 'department' }, expectedStatus: 201 });
    const space = createdSpace.data.space;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: space.inviteCode } });
    const made = await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: a.token, body: { name: 'announcements' }, expectedStatus: 201 });
    const channelId = made.data.channel._id;
    await request(`/api/channels/${channelId}`, { method: 'PUT', token: a.token, body: { onlyAdminsCanPost: true } });
    const body = { content: { text: 'synthetic announcement' } };
    const rejected = await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: b.token, body, expectedStatus: 403 });
    assert.equal(rejected.payload.success, false);
    const adminPost = await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body, expectedStatus: 201 });
    assert.ok(adminPost.data.message._id);
    await request(`/api/channels/${channelId}`, { method: 'PUT', token: a.token, body: { onlyAdminsCanPost: false } });
    const memberPost = await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: b.token, body: { content: { text: 'synthetic member post' } }, expectedStatus: 201 });
    const detail = await request(`/api/channels/${channelId}`, { token: b.token });
    assert.equal(detail.data.channel.onlyAdminsCanPost, false);
    await db(async (connection) => {
      const messages = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(channelId) }).toArray();
      assert.deepEqual(new Set(messages.map((item) => String(item._id))), new Set([adminPost.data.message._id, memberPost.data.message._id]));
      const channel = await connection.collection('channels').findOne({ _id: new connection.base.Types.ObjectId(channelId) });
      assert.equal(channel.onlyAdminsCanPost, false);
      assert.equal(String(channel.lastMessage.messageId), memberPost.data.message._id);
    });
  },
}]);
