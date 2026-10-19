import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { runModule } from '../src/module-runner.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';
import { DecisionPending } from '../src/runner.mjs';

const cases = [{
  id: 'FR-MSG-01', module: 'MSG',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Message Boundary', type: 'department' }, expectedStatus: 201 });
    const general = created.data.channels.find((channel) => channel.name === 'general');
    assert.ok(general?._id);
    const path = `/api/channels/${general._id}/messages`;
    const invalid = [
      {}, { content: {} }, { content: { text: 42 } }, { content: { text: '  \n  ' } },
      { content: { text: `  ${'X'.repeat(4001)}  ` } },
    ];
    for (const body of invalid) {
      const rejected = await request(path, { method: 'POST', token: a.token, body, expectedStatus: 400 });
      assert.equal(rejected.payload.success, false);
    }
    const exact = await request(path, { method: 'POST', token: a.token, body: { content: { text: 'Y'.repeat(4000) } }, expectedStatus: 201 });
    assert.equal(exact.data.message.content.text, 'Y'.repeat(4000));
    const unicode = 'Δοκιμή 医療\nSynthetic second line 🩺';
    const sent = await request(path, { method: 'POST', token: a.token, body: { content: { text: unicode } }, expectedStatus: 201 });
    assert.equal(sent.data.message.content.text, unicode);
    const reread = await request(path, { token: a.token });
    assert.deepEqual(reread.data.messages.map((item) => item._id), [exact.data.message._id, sent.data.message._id]);
    assert.deepEqual(reread.data.messages.map((item) => item.content.text), ['Y'.repeat(4000), unicode]);
    await db(async (connection) => {
      const messages = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(general._id) }).toArray();
      assert.equal(messages.length, 2, 'Invalid sends must not persist');
      assert.deepEqual(new Set(messages.map((item) => String(item._id))), new Set([exact.data.message._id, sent.data.message._id]));
      assert.equal(messages.find((item) => String(item._id) === sent.data.message._id).content.text, unicode);
    });
    // Route validation counts trimmed characters; persistence must accept the
    // same 4000-character payload after surrounding whitespace is normalized.
    await request(path, { method: 'POST', token: a.token, body: { content: { text: `  ${'Z'.repeat(4000)}  ` } }, expectedStatus: 201 });
  },
}, {
  id: 'FR-MSG-03', module: 'MSG',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Quote Snapshot', type: 'department' }, expectedStatus: 201 });
    const channelId = created.data.channels.find((channel) => channel.name === 'general')._id;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
    const path = `/api/channels/${channelId}/messages`;
    const send = async (token, body) => (await request(path, { method: 'POST', token, body, expectedStatus: 201 })).data.message;
    const longText = 'Synthetic quoted context '.repeat(8);
    assert.ok(longText.length > 120);
    const textRoot = await send(a.token, { content: { text: longText } });
    const textQuote = await send(b.token, { content: { text: 'synthetic quote text', }, replyToId: textRoot._id });
    const imageRoot = await send(a.token, { type: 'image', content: { mediaUrl: 'https://res.cloudinary.com/synthetic-test/image.jpg', fileName: 'synthetic-image.jpg', mimeType: 'image/jpeg' } });
    const imageQuote = await send(b.token, { content: { text: 'synthetic quote image' }, replyToId: imageRoot._id });
    const documentRoot = await send(a.token, { type: 'document', content: { mediaUrl: 'https://res.cloudinary.com/synthetic-test/fixture.pdf', fileName: 'synthetic-discharge.pdf', mimeType: 'application/pdf' } });
    const documentQuote = await send(b.token, { content: { text: 'synthetic quote document' }, replyToId: documentRoot._id });
    for (const [quote, root, preview, type] of [
      [textQuote, textRoot, longText.slice(0, 120), 'text'],
      [imageQuote, imageRoot, 'Photo', 'image'],
      [documentQuote, documentRoot, 'synthetic-discharge.pdf', 'document'],
    ]) {
      assert.equal(quote.replyTo.messageId, root._id);
      assert.equal(quote.replyTo.senderId, a.userId);
      assert.equal(quote.replyTo.senderName, 'Dr Synthetic A');
      assert.equal(quote.replyTo.type, type);
      assert.equal(quote.replyTo.text, preview);
    }
    const reread = await request(path, { token: b.token });
    const byId = new Map(reread.data.messages.map((message) => [message._id, message]));
    for (const [quote, root] of [[textQuote, textRoot], [imageQuote, imageRoot], [documentQuote, documentRoot]]) {
      assert.equal(byId.get(quote._id).replyTo.messageId, root._id);
      assert.equal(byId.get(quote._id).replyTo.text, quote.replyTo.text);
    }
    await db(async (connection) => {
      const saved = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(channelId) }).toArray();
      assert.equal(saved.length, 6);
      const byId = new Map(saved.map((message) => [String(message._id), message]));
      for (const [quote, root] of [[textQuote, textRoot], [imageQuote, imageRoot], [documentQuote, documentRoot]]) {
        assert.equal(String(byId.get(quote._id).replyTo.messageId), root._id);
        assert.equal(byId.get(quote._id).replyTo.text, quote.replyTo.text);
      }
      assert.equal(byId.get(textRoot._id).content.text, longText);
    });
  },
}, {
  id: 'FR-MSG-04', module: 'MSG',
  run: async ({ identity, request, db, origin }) => {
    const a = await identity('A'), b = await identity('B');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Edit Lifecycle', type: 'department' }, expectedStatus: 201 });
    const channelId = created.data.channels.find((channel) => channel.name === 'general')._id;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
    const socket = await connectSocket(null, origin, b.token);
    try {
      const joined = waitFor(socket, 'join_channel', (event) => event?.success === true && event.channelId === channelId);
      socket.emit('join_channel', { channelId });
      await joined;
      const path = `/api/channels/${channelId}/messages`;
      const root = (await request(path, { method: 'POST', token: a.token, body: { content: { text: 'Synthetic original' } }, expectedStatus: 201 })).data.message;
      for (const changedText of ['Synthetic first edit', 'Synthetic second edit']) {
        const event = waitFor(socket, 'message_updated', (payload) => payload?.messageId === root._id);
        const edited = await request(`${path}/${root._id}`, { method: 'PUT', token: a.token, body: { content: { text: changedText } } });
        assert.equal(edited.data.message.content.text, changedText);
        assert.equal(edited.data.message.isEdited, true);
        assert.ok(Date.parse(edited.data.message.editedAt));
        const emitted = await event;
        assert.equal(emitted.content.text, changedText);
        assert.equal(emitted.isEdited, true);
        const listed = await request(path, { token: b.token });
        assert.equal(listed.data.messages.find((message) => message._id === root._id)?.content.text, changedText);
      }
      const image = (await request(path, { method: 'POST', token: a.token, body: { type: 'image', content: { mediaUrl: 'https://res.cloudinary.com/synthetic-test/edit-image.jpg', fileName: 'edit-image.jpg', mimeType: 'image/jpeg' } }, expectedStatus: 201 })).data.message;
      const rejected = await request(`${path}/${image._id}`, { method: 'PUT', token: a.token, body: { content: { text: 'Forbidden media edit' } }, expectedStatus: 400 });
      assert.equal(rejected.payload.success, false);
      await db(async (connection) => {
        const messages = connection.collection('messages');
        const storedRoot = await messages.findOne({ _id: new connection.base.Types.ObjectId(root._id) });
        const storedImage = await messages.findOne({ _id: new connection.base.Types.ObjectId(image._id) });
        assert.equal(storedRoot.content.text, 'Synthetic second edit');
        assert.equal(storedRoot.isEdited, true);
        assert.ok(storedRoot.editedAt instanceof Date);
        assert.equal(storedImage.isEdited, false);
        assert.equal(storedImage.content.mediaUrl, image.content.mediaUrl);
      });
    } finally { socket.disconnect(); }
  },
}, {
  id: 'FR-MSG-05', module: 'MSG',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Derived Views', type: 'department' }, expectedStatus: 201 });
    const channelId = created.data.channels.find((channel) => channel.name === 'general')._id;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
    const path = `/api/channels/${channelId}/messages`;
    const oldText = 'Synthetic previeworiginal unique marker';
    const newText = 'Synthetic previewchanged unique marker';
    const root = (await request(path, { method: 'POST', token: a.token, body: { content: { text: oldText } }, expectedStatus: 201 })).data.message;
    const quote = (await request(path, { method: 'POST', token: b.token, body: { content: { text: 'Synthetic quote of newest' }, replyToId: root._id }, expectedStatus: 201 })).data.message;
    const edited = await request(`${path}/${root._id}`, { method: 'PUT', token: a.token, body: { content: { text: newText } } });
    assert.equal(edited.data.message.content.text, newText);
    assert.equal(edited.data.message.isEdited, true);
    const searchOldAfterEdit = await request(`/api/search?q=${encodeURIComponent(oldText)}&type=messages`, { token: b.token });
    const searchNewAfterEdit = await request(`/api/search?q=${encodeURIComponent(newText)}&type=messages`, { token: b.token });
    assert.ok(!searchOldAfterEdit.data.messages.some((message) => message._id === root._id));
    assert.ok(searchNewAfterEdit.data.messages.some((message) => message._id === root._id));
    const afterEdit = await request(path, { token: b.token });
    assert.equal(afterEdit.data.messages.find((message) => message._id === root._id)?.content.text, newText);
    const quoteAfterEdit = afterEdit.data.messages.find((message) => message._id === quote._id)?.replyTo?.text;
    const spaceAfterEdit = await request('/api/spaces', { token: b.token });
    const previewAfterEdit = spaceAfterEdit.data.spaces.flatMap((space) => space.channels || []).find((channel) => channel._id === channelId)?.lastMessage;
    const newest = (await request(path, { method: 'POST', token: a.token, body: { content: { text: 'Synthetic newest before edit' } }, expectedStatus: 201 })).data.message;
    const newestEdited = await request(`${path}/${newest._id}`, { method: 'PUT', token: a.token, body: { content: { text: 'Synthetic newest after edit' } } });
    assert.equal(newestEdited.data.message.content.text, 'Synthetic newest after edit');
    const newestAfterEdit = await request(path, { token: b.token });
    assert.equal(newestAfterEdit.data.messages.at(-1)?._id, newest._id);
    assert.equal(newestAfterEdit.data.messages.at(-1)?.content.text, 'Synthetic newest after edit');
    const latestSpaceAfterEdit = await request('/api/spaces', { token: b.token });
    const latestPreviewAfterEdit = latestSpaceAfterEdit.data.spaces.flatMap((space) => space.channels || []).find((channel) => channel._id === channelId)?.lastMessage;
    await request(`${path}/${newest._id}`, { method: 'DELETE', token: a.token });
    const newestAfterDelete = await request(path, { token: b.token });
    assert.ok(!newestAfterDelete.data.messages.some((message) => message._id === newest._id));
    const latestSpaceAfterDelete = await request('/api/spaces', { token: b.token });
    const latestPreviewAfterDelete = latestSpaceAfterDelete.data.spaces.flatMap((space) => space.channels || []).find((channel) => channel._id === channelId)?.lastMessage;
    await request(`${path}/${root._id}`, { method: 'DELETE', token: a.token });
    const afterDelete = await request(path, { token: b.token });
    assert.ok(!afterDelete.data.messages.some((message) => message._id === root._id));
    assert.ok(afterDelete.data.messages.some((message) => message._id === quote._id));
    const searchAfterDelete = await request(`/api/search?q=${encodeURIComponent(newText)}&type=messages`, { token: b.token });
    assert.ok(!searchAfterDelete.data.messages.some((message) => message._id === root._id));
    const spaceAfterDelete = await request('/api/spaces', { token: b.token });
    const previewAfterDelete = spaceAfterDelete.data.spaces.flatMap((space) => space.channels || []).find((channel) => channel._id === channelId)?.lastMessage;
    await db(async (connection) => {
      const saved = await connection.collection('messages').findOne({ _id: new connection.base.Types.ObjectId(root._id) });
      const savedNewest = await connection.collection('messages').findOne({ _id: new connection.base.Types.ObjectId(newest._id) });
      assert.equal(saved.isDeleted, true);
      assert.equal(saved.isEdited, true);
      assert.equal(saved.content.text, 'This message was deleted');
      assert.ok(saved.deletedAt instanceof Date);
      assert.equal(savedNewest.isDeleted, true);
      assert.equal(savedNewest.isEdited, true);
      assert.equal(savedNewest.content.text, 'This message was deleted');
    });
    throw new DecisionPending('Q1: derived quote snapshot and channel preview propagation after edit/delete needs product decision', [
      `Root ${root._id} persisted edit then soft deletion; search removed old text after edit and new text after deletion`,
      `Quote ${quote._id} after edit retained text ${JSON.stringify(quoteAfterEdit)}`,
      `Channel preview after edit ${JSON.stringify(previewAfterEdit)}; after delete ${JSON.stringify(previewAfterDelete)}`,
      `Newest ${newest._id} edited and deleted; preview after edit ${JSON.stringify(latestPreviewAfterEdit)}; after delete ${JSON.stringify(latestPreviewAfterDelete)}`,
    ]);
  },
}, {
  id: 'FR-MSG-06', module: 'MSG',
  run: async ({ identity, request, db, origin }) => {
    const a = await identity('A'), b = await identity('B');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Delete Lifecycle', type: 'department' }, expectedStatus: 201 });
    const channelId = created.data.channels.find((channel) => channel.name === 'general')._id;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
    const socket = await connectSocket(null, origin, b.token);
    try {
      const joined = waitFor(socket, 'join_channel', (event) => event?.success === true && event.channelId === channelId);
      socket.emit('join_channel', { channelId });
      await joined;
      const path = `/api/channels/${channelId}/messages`;
      const media = (await request(path, { method: 'POST', token: b.token, body: { type: 'image', content: { mediaUrl: 'https://res.cloudinary.com/synthetic-test/delete-image.jpg', thumbnailUrl: 'https://res.cloudinary.com/synthetic-test/thumbnail.jpg', fileName: 'delete-image.jpg', mimeType: 'image/jpeg' } }, expectedStatus: 201 })).data.message;
      const text = (await request(path, { method: 'POST', token: b.token, body: { content: { text: 'Synthetic older text' } }, expectedStatus: 201 })).data.message;
      const unrelated = (await request(path, { method: 'POST', token: a.token, body: { content: { text: 'Unrelated newest record' } }, expectedStatus: 201 })).data.message;
      await request(`${path}/${media._id}/react`, { method: 'POST', token: a.token, body: { emoji: '👍' } });
      for (const [message, actor] of [[media, b], [text, a]]) {
        const event = waitFor(socket, 'message_deleted', (payload) => payload?.messageId === message._id);
        await request(`${path}/${message._id}`, { method: 'DELETE', token: actor.token });
        assert.equal((await event).messageId, message._id);
      }
      const listed = await request(path, { token: b.token });
      assert.deepEqual(listed.data.messages.map((message) => message._id), [unrelated._id], 'Deleted records must be omitted from root pages');
      assert.equal(listed.data.messages.find((item) => item._id === unrelated._id).content.text, 'Unrelated newest record');
      await db(async (connection) => {
        const saved = await connection.collection('messages').find({ _id: { $in: [media, text, unrelated].map((item) => new connection.base.Types.ObjectId(item._id)) } }).toArray();
        assert.equal(saved.length, 3);
        for (const item of saved.filter((row) => String(row._id) !== unrelated._id)) {
          assert.equal(item.isDeleted, true);
          assert.ok(item.deletedAt instanceof Date);
          assert.equal(item.content.text, 'This message was deleted');
          assert.equal(item.content.mediaUrl, null);
          assert.equal(item.reactions.length, 0);
        }
        assert.equal(saved.find((row) => String(row._id) === unrelated._id).isDeleted, false);
      });
    } finally { socket.disconnect(); }
  },
}, {
  id: 'FR-MSG-07', module: 'MSG',
  run: async ({ identity, request, db, origin }) => {
    const a = await identity('A'), b = await identity('B');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Priority Flow', type: 'department' }, expectedStatus: 201 });
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
    const general = created.data.channels.find((channel) => channel.name === 'general')._id;
    const emergency = created.data.channels.find((channel) => channel.name === 'emergency')._id;
    const socket = await connectSocket(null, origin, b.token);
    try {
      for (const [channelId, submittedPriority, expectedPriority, expectedType] of [
        [general, 'urgent', 'urgent', 'new_message'],
        [emergency, 'normal', 'emergency', 'emergency_alert'],
      ]) {
        const text = `Synthetic ${expectedPriority} priority ${channelId}`;
        const notification = waitFor(socket, 'new_notification', (payload) => payload?.metadata?.channelId === channelId && payload?.body === text);
        const sent = (await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body: { priority: submittedPriority, content: { text } }, expectedStatus: 201 })).data.message;
        assert.equal(sent.priority, expectedPriority);
        const delivered = await notification;
        assert.equal(delivered.type, expectedType);
        assert.equal(delivered.priority, expectedPriority);
        assert.equal(delivered.metadata.messageId, sent._id);
        const reload = await request(`/api/channels/${channelId}/messages`, { token: b.token });
        assert.equal(reload.data.messages.find((message) => message._id === sent._id)?.priority, expectedPriority);
        await db(async (connection) => {
          const id = new connection.base.Types.ObjectId(sent._id);
          const record = await connection.collection('messages').findOne({ _id: id });
          const inbox = await connection.collection('notifications').find({ referenceId: id }).toArray();
          assert.equal(record.priority, expectedPriority);
          assert.equal(inbox.length, 1);
          assert.equal(String(inbox[0].userId), b.userId);
          assert.equal(inbox[0].priority, expectedPriority);
          assert.equal(inbox[0].type, expectedType);
        });
      }
    } finally { socket.disconnect(); }
  },
}, {
  id: 'FR-MSG-08', module: 'MSG',
  run: async ({ identity, request, db, origin }) => {
    const a = await identity('A');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Response Loss', type: 'department' }, expectedStatus: 201 });
    const channelId = created.data.channels.find((channel) => channel.name === 'general')._id;
    const path = `/api/channels/${channelId}/messages`;
    const marker = 'Synthetic committed after proxy response loss';
    let receipt;
    const proxy = createServer(async (incoming) => {
      try {
        const parts = [];
        for await (const part of incoming) parts.push(part);
        const upstream = await fetch(`${origin}${incoming.url}`, {
          method: incoming.method,
          headers: { authorization: incoming.headers.authorization, 'content-type': incoming.headers['content-type'] },
          body: Buffer.concat(parts),
          signal: AbortSignal.timeout(10000),
        });
        receipt = { status: upstream.status, payload: await upstream.json() };
      } catch (error) { receipt = { error: error.message }; }
      incoming.socket.destroy();
    });
    await new Promise((resolve, reject) => proxy.once('error', reject).listen(0, '127.0.0.1', resolve));
    try {
      let dropped = false;
      try {
        await fetch(`http://127.0.0.1:${proxy.address().port}${path}`, {
          method: 'POST', headers: { authorization: `Bearer ${a.token}`, 'content-type': 'application/json' },
          body: JSON.stringify({ content: { text: marker } }), signal: AbortSignal.timeout(10000),
        });
      } catch { dropped = true; }
      assert.equal(dropped, true, 'The proxy must drop the client response after upstream commit');
      assert.equal(receipt?.status, 201);
      const committedId = receipt.payload?.data?.message?._id;
      assert.ok(committedId);
      const reopened = await request(path, { token: a.token });
      assert.deepEqual(reopened.data.messages.filter((message) => message.content.text === marker).map((message) => message._id), [committedId]);
      await db(async (connection) => {
        const stored = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(channelId), 'content.text': marker }).toArray();
        assert.equal(stored.length, 1);
        assert.equal(String(stored[0]._id), committedId);
      });
      throw new DecisionPending('Q7: automatic duplicate prevention after a lost successful response needs product decision', [
        `Proxy consumed HTTP 201 for committed message ${committedId} and dropped the client response`,
        'A fresh channel fetch recovered exactly one persisted message before any manual resend',
      ]);
    } finally { await new Promise((resolve) => proxy.close(resolve)); }
  },
}, {
  id: 'FR-MSG-02', module: 'MSG',
  prerequisiteSeed: 'Controlled ObjectId sequence and one thread reply inserted directly to isolate root cursor behavior',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Root Cursor', type: 'department' }, expectedStatus: 201 });
    const channelId = created.data.channels.find((channel) => channel.name === 'general')._id;
    const objectId = (connection, index) => new connection.base.Types.ObjectId(`6ac8f100000000000000${index.toString(16).padStart(4, '0')}`);
    const ids = Array.from({ length: 101 }, (_, index) => `6ac8f100000000000000${(index + 1).toString(16).padStart(4, '0')}`);
    await db(async (connection) => {
      const make = (index) => ({
        _id: objectId(connection, index), channelId: new connection.base.Types.ObjectId(channelId),
        spaceId: new connection.base.Types.ObjectId(created.data.space._id), senderId: new connection.base.Types.ObjectId(a.userId),
        type: 'text', content: { text: `synthetic cursor ${index}` }, priority: 'normal', threadId: null,
        isDeleted: false, deletedAt: null, createdAt: new Date(Date.UTC(2026, 0, 1) + index * 1000), updatedAt: new Date(Date.UTC(2026, 0, 1) + index * 1000),
      });
      await connection.collection('messages').insertMany(Array.from({ length: 100 }, (_, index) => make(index + 1)));
      await connection.collection('messages').insertOne({ ...make(102), threadId: objectId(connection, 100) });
    });
    const path = `/api/channels/${channelId}/messages`;
    for (const query of ['limit=0', 'limit=101', 'before=malformed']) {
      const denied = await request(`${path}?${query}`, { token: a.token, expectedStatus: 400 });
      assert.equal(denied.payload.success, false);
    }
    const exactFull = await request(`${path}?limit=100`, { token: a.token });
    assert.equal(exactFull.data.messages.length, 100);
    assert.equal(exactFull.data.hasMore, false);
    assert.deepEqual(exactFull.data.messages.map((message) => message._id), ids.slice(0, 100));
    await db(async (connection) => assert.equal((await connection.collection('messages').insertOne({
      _id: objectId(connection, 101), channelId: new connection.base.Types.ObjectId(channelId),
      spaceId: new connection.base.Types.ObjectId(created.data.space._id), senderId: new connection.base.Types.ObjectId(a.userId),
      type: 'text', content: { text: 'synthetic cursor 101' }, priority: 'normal', threadId: null,
      isDeleted: false, deletedAt: null, createdAt: new Date(Date.UTC(2026, 0, 1) + 101000), updatedAt: new Date(Date.UTC(2026, 0, 1) + 101000),
    })).acknowledged, true));
    const one = await request(`${path}?limit=1`, { token: a.token });
    assert.deepEqual(one.data.messages.map((message) => message._id), [ids[100]]);
    assert.equal(one.data.hasMore, true);
    const first = await request(`${path}?limit=100`, { token: a.token });
    assert.equal(first.data.hasMore, true);
    assert.deepEqual(first.data.messages.map((message) => message._id), ids.slice(1));
    const final = await request(`${path}?limit=100&before=${first.data.messages[0]._id}`, { token: a.token });
    assert.deepEqual(final.data.messages.map((message) => message._id), [ids[0]]);
    assert.equal(final.data.hasMore, false);
    const empty = await request(`${path}?before=${ids[0]}`, { token: a.token });
    assert.deepEqual(empty.data.messages, []);
    assert.equal(empty.data.hasMore, false);
    assert.equal(new Set([...first.data.messages, ...final.data.messages].map((message) => message._id)).size, 101);
    await db(async (connection) => {
      const roots = await connection.collection('messages').countDocuments({ channelId: new connection.base.Types.ObjectId(channelId), threadId: null });
      assert.equal(roots, 101);
      assert.equal(await connection.collection('messages').countDocuments({ channelId: new connection.base.Types.ObjectId(channelId), threadId: objectId(connection, 100) }), 1);
    });
  },
}];

for (const item of cases) await runModule(`messages-${item.id.slice(-2).toLowerCase()}`, [item]);
