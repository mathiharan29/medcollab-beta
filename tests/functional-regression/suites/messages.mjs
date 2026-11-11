import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { runModule } from '../src/module-runner.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';

const cases = [{
  id: 'FR-MSG-01', module: 'MSG',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Message Boundary', type: 'department' }, expectedStatus: 201 });
    const general = created.data.channels.find((channel) => channel.name === 'general');
    assert.ok(general?._id);
    const path = `/api/channels/${general._id}/messages`;
    const initial = (await request(path, { token: a.token })).data.messages;
    assert.deepEqual(initial.map((message) => message.type), ['system']);
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
    assert.deepEqual(reread.data.messages.map((item) => item._id), [initial[0]._id, exact.data.message._id, sent.data.message._id]);
    assert.deepEqual(reread.data.messages.slice(1).map((item) => item.content.text), ['Y'.repeat(4000), unicode]);
    await db(async (connection) => {
      const messages = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(general._id) }).toArray();
      assert.equal(messages.length, 3, 'Invalid sends must not persist');
      assert.deepEqual(new Set(messages.map((item) => String(item._id))), new Set([initial[0]._id, exact.data.message._id, sent.data.message._id]));
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
    const storedLongText = longText.trim(); // sendMessage persists trimmed text
    const textRoot = await send(a.token, { content: { text: longText } });
    const textQuote = await send(b.token, { content: { text: 'synthetic quote text', }, replyToId: textRoot._id });
    const imageRoot = await send(a.token, { type: 'image', content: { mediaUrl: 'https://res.cloudinary.com/synthetic-test/image.jpg', fileName: 'synthetic-image.jpg', mimeType: 'image/jpeg' } });
    const imageQuote = await send(b.token, { content: { text: 'synthetic quote image' }, replyToId: imageRoot._id });
    const documentRoot = await send(a.token, { type: 'document', content: { mediaUrl: 'https://res.cloudinary.com/synthetic-test/fixture.pdf', fileName: 'synthetic-discharge.pdf', mimeType: 'application/pdf' } });
    const documentQuote = await send(b.token, { content: { text: 'synthetic quote document' }, replyToId: documentRoot._id });
    for (const [quote, root, preview, type] of [
      [textQuote, textRoot, storedLongText.slice(0, 120), 'text'],
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
      const saved = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(channelId), type: { $ne: 'system' } }).toArray();
      assert.equal(saved.length, 6);
      const byId = new Map(saved.map((message) => [String(message._id), message]));
      for (const [quote, root] of [[textQuote, textRoot], [imageQuote, imageRoot], [documentQuote, documentRoot]]) {
        assert.equal(String(byId.get(quote._id).replyTo.messageId), root._id);
        assert.equal(byId.get(quote._id).replyTo.text, quote.replyTo.text);
      }
      assert.equal(byId.get(textRoot._id).content.text, storedLongText);
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
    assert.equal(quoteAfterEdit, oldText, 'Editing must not rewrite existing quote snapshots');
    const newest = (await request(path, { method: 'POST', token: a.token, body: { content: { text: 'Synthetic newest before edit' } }, expectedStatus: 201 })).data.message;
    const newestEdited = await request(`${path}/${newest._id}`, { method: 'PUT', token: a.token, body: { content: { text: 'Synthetic newest after edit' } } });
    assert.equal(newestEdited.data.message.content.text, 'Synthetic newest after edit');
    const newestAfterEdit = await request(path, { token: b.token });
    assert.equal(newestAfterEdit.data.messages.at(-1)?._id, newest._id);
    assert.equal(newestAfterEdit.data.messages.at(-1)?.content.text, 'Synthetic newest after edit');
    await request(`${path}/${newest._id}`, { method: 'DELETE', token: a.token });
    const newestAfterDelete = await request(path, { token: b.token });
    assert.ok(!newestAfterDelete.data.messages.some((message) => message._id === newest._id));
    const latestSpaceAfterDelete = await request('/api/spaces', { token: b.token });
    const latestPreviewAfterDelete = latestSpaceAfterDelete.data.spaces.flatMap((space) => space.channels || []).find((channel) => channel._id === channelId)?.lastMessage;
    assert.equal(latestPreviewAfterDelete.messageId, quote._id);
    assert.equal(latestPreviewAfterDelete.text, quote.content.text);
    await request(`${path}/${root._id}`, { method: 'DELETE', token: a.token });
    const afterDelete = await request(path, { token: b.token });
    assert.ok(!afterDelete.data.messages.some((message) => message._id === root._id));
    assert.ok(afterDelete.data.messages.some((message) => message._id === quote._id));
    assert.equal(
      afterDelete.data.messages.find((message) => message._id === quote._id)?.replyTo?.text,
      'This message was deleted'
    );
    const searchAfterDelete = await request(`/api/search?q=${encodeURIComponent(newText)}&type=messages`, { token: b.token });
    assert.ok(!searchAfterDelete.data.messages.some((message) => message._id === root._id));
    await db(async (connection) => {
      const saved = await connection.collection('messages').findOne({ _id: new connection.base.Types.ObjectId(root._id) });
      const savedNewest = await connection.collection('messages').findOne({ _id: new connection.base.Types.ObjectId(newest._id) });
      const savedQuote = await connection.collection('messages').findOne({ _id: new connection.base.Types.ObjectId(quote._id) });
      assert.equal(saved, null);
      assert.equal(savedNewest, null);
      assert.equal(savedQuote.replyTo.text, 'This message was deleted');
    });
    const latest = (await request(path, { method: 'POST', token: a.token, body: { content: { text: 'syntheticpersonalhide' } }, expectedStatus: 201 })).data.message;
    const search = async (person, q) => (await request(`/api/search?q=${q}&type=messages`, { token: person.token })).data.messages.map((item) => item._id);
    const preview = async (person) => {
      const token = person.token;
      const groupList = (await request('/api/spaces', { token })).data.spaces.find((space) => space._id === created.data.space._id);
      const channelList = (await request(`/api/spaces/${created.data.space._id}/channels`, { token })).data.channels;
      const findPreviewId = (channels) => channels.find((channel) => channel._id === channelId)?.lastMessage?.messageId ?? null;
      return { groupList: findPreviewId(groupList.channels), channelList: findPreviewId(channelList) };
    };
    const hidePath = `${path}/${latest._id}?scope=me`;
    for (let attempt = 0; attempt < 2; attempt++) {
      const hidden = await request(hidePath, { method: 'DELETE', token: b.token });
      assert.equal(hidden.data.scope, 'me');
      assert.deepEqual(hidden.data.deletedIds, [latest._id]);
    }
    const senderView = (await request(path, { token: a.token })).data.messages;
    assert.equal(senderView.at(-1)._id, latest._id);
    assert.ok(!Object.hasOwn(senderView.at(-1), 'hiddenFor'));
    assert.ok(!(await request(path, { token: b.token })).data.messages.some((item) => item._id === latest._id));
    assert.deepEqual(await search(a, 'syntheticpersonalhide'), [latest._id]);
    assert.deepEqual(await search(b, 'syntheticpersonalhide'), []);
    assert.deepEqual(await preview(a), { groupList: latest._id, channelList: latest._id });
    const afterHide = await preview(b);

    const priorReply = (await request(`${path}/${quote._id}/reply`, { method: 'POST', token: a.token, body: { content: { text: 'syntheticpriorreply' } }, expectedStatus: 201 })).data.message;
    const cleared = (await request(`${path}/clear`, { method: 'POST', token: b.token })).data;
    assert.ok(Date.parse(cleared.clearedAt) >= Date.parse(priorReply.createdAt));
    assert.deepEqual((await request(path, { token: b.token })).data.messages, []);
    const afterClear = await preview(b);
    assert.deepEqual(await search(b, 'syntheticpriorreply'), []);
    assert.deepEqual(await search(a, 'syntheticpriorreply'), [priorReply._id]);
    assert.equal((await request(path, { token: a.token })).data.messages.at(-1)._id, latest._id);
    const fresh = (await request(path, { method: 'POST', token: a.token, body: { content: { text: 'syntheticafterclear' } }, expectedStatus: 201 })).data.message;
    assert.deepEqual((await request(path, { token: b.token })).data.messages.map((item) => item._id), [fresh._id]);
    assert.deepEqual(await preview(b), { groupList: fresh._id, channelList: fresh._id });
    assert.deepEqual(await search(b, 'syntheticafterclear'), [fresh._id]);
    await db(async (connection) => {
      const objectId = (id) => new connection.base.Types.ObjectId(id);
      const original = await connection.collection('messages').findOne({ _id: objectId(latest._id) });
      assert.deepEqual(original.hiddenFor.map(String), [b.userId]);
      assert.equal(original.content.text, 'syntheticpersonalhide');
      const clears = await connection.collection('chatclears').find({ channelId: objectId(channelId) }).toArray();
      assert.deepEqual(clears.map((item) => String(item.userId)), [b.userId]);
      assert.equal(clears[0].clearedAt.toISOString(), cleared.clearedAt);
    });
    const threadPath = `${path}/${quote._id}/thread`;
    assert.deepEqual((await request(threadPath, { token: a.token })).data.replies.map((item) => item._id), [priorReply._id]);
    const threadAfterClear = await request(threadPath, { token: b.token }).catch((error) => {
      if ([403, 404].includes(error.detail?.status)) return null;
      throw error;
    });
    assert.deepEqual(threadAfterClear?.data.replies ?? [], []);
    assert.deepEqual({
      previewsAfterDeleteForMe: afterHide,
      previewsAfterClearChat: afterClear,
      preClearRootVisibleViaThread: threadAfterClear?.data.rootMessage?._id === quote._id,
    }, {
      previewsAfterDeleteForMe: { groupList: quote._id, channelList: quote._id },
      previewsAfterClearChat: { groupList: null, channelList: null },
      preClearRootVisibleViaThread: false,
    }, 'Personal history must stay hidden in both preview lists and in a directly reopened thread');
  },
}, {
  id: 'FR-MSG-06', module: 'MSG',
  run: async ({ identity, request, db, origin }) => {
    const a = await identity('A'), b = await identity('B');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Delete Lifecycle', type: 'department' }, expectedStatus: 201 });
    const channelId = created.data.channels.find((channel) => channel.name === 'general')._id;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
    // Listen from the personal room without opening the channel.
    const socket = await connectSocket(null, origin, b.token);
    try {
      const path = `/api/channels/${channelId}/messages`;
      const activity = (await request(path, { token: b.token })).data.messages;
      assert.deepEqual(activity.map((message) => message.type), ['system', 'system']);
      const textNotice = waitFor(socket, 'new_notification', (event) => event?.body === 'Synthetic deletion attachment');
      const media = (await request(path, { method: 'POST', token: b.token, body: { type: 'image', content: { mediaUrl: 'https://res.cloudinary.com/synthetic-test/delete-image.jpg', thumbnailUrl: 'https://res.cloudinary.com/synthetic-test/thumbnail.jpg', fileName: 'delete-image.jpg', mimeType: 'image/jpeg' } }, expectedStatus: 201 })).data.message;
      const text = (await request(path, { method: 'POST', token: a.token, body: { content: { text: 'Synthetic deletion attachment' } }, expectedStatus: 201 })).data.message;
      assert.equal((await textNotice).metadata.messageId, text._id);
      const reply = (await request(`${path}/${text._id}/reply`, { method: 'POST', token: b.token, body: { content: { text: 'Synthetic doomed thread reply' } }, expectedStatus: 201 })).data.message;
      const unrelated = (await request(path, { method: 'POST', token: a.token, body: { content: { text: 'Unrelated newest record' } }, expectedStatus: 201 })).data.message;
      await request(`${path}/${media._id}/react`, { method: 'POST', token: a.token, body: { emoji: '👍' } });
      await request(`/api/channels/${channelId}/pin/${text._id}`, { method: 'POST', token: a.token });
      await request(`/api/channels/${channelId}/pin/${unrelated._id}`, { method: 'POST', token: a.token });
      await request(`${path}/${text._id}?scope=everyone`, { method: 'DELETE', token: b.token, expectedStatus: 403 });
      for (const [message, actor, scope, expectedIds] of [
        [media, a, '?scope=everyone', [media._id]],
        [text, a, '', [text._id, reply._id]],
      ]) {
        const events = Promise.all(expectedIds.map((id) => waitFor(socket, 'message_deleted', (payload) => payload?.messageId === id)));
        const deleted = await request(`${path}/${message._id}${scope}`, { method: 'DELETE', token: actor.token });
        assert.deepEqual(new Set(deleted.data.deletedIds), new Set(expectedIds));
        for (const event of await events) assert.equal(event.channelId, channelId);
      }
      await request(`${path}/${text._id}/thread`, { token: b.token, expectedStatus: 404 });
      const listed = await request(path, { token: b.token });
      assert.deepEqual(listed.data.messages.map((message) => message._id), [...activity.map((item) => item._id), unrelated._id]);
      assert.equal(listed.data.messages.find((item) => item._id === unrelated._id).content.text, 'Unrelated newest record');
      await db(async (connection) => {
        const objectId = (id) => new connection.base.Types.ObjectId(id);
        const doomed = [media, text, reply].map((item) => objectId(item._id));
        const messages = connection.collection('messages');
        assert.equal(await messages.countDocuments({ _id: { $in: doomed } }), 0);
        assert.equal((await messages.findOne({ _id: objectId(unrelated._id) })).isDeleted, false);
        assert.equal(await connection.collection('notifications').countDocuments({ referenceId: { $in: doomed } }), 0);
        const channel = await connection.collection('channels').findOne({ _id: objectId(channelId) });
        assert.deepEqual(channel.pinnedMessages.map((pin) => String(pin.messageId)), [unrelated._id]);
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
      // Product decision Q7: client must wait for ack / reconcile via fetch before
      // resend (WhatsApp-style ticks). Server already has exactly one committed row;
      // automatic duplicate send is forbidden on the client pending-queue path.
      assert.equal(
        reopened.data.messages.filter((message) => message.content.text === marker).length,
        1,
        'Reconcile-before-resend must observe a single committed message'
      );
    } finally { await new Promise((resolve) => proxy.close(resolve)); }
  },
}, {
  id: 'FR-MSG-02', module: 'MSG',
  prerequisiteSeed: 'Controlled ObjectId sequence and one thread reply inserted directly to isolate root cursor behavior',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Root Cursor', type: 'department' }, expectedStatus: 201 });
    const channel = await request(`/api/spaces/${created.data.space._id}/channels`, { method: 'POST', token: a.token, body: { name: 'cursor-fixture' }, expectedStatus: 201 });
    const channelId = channel.data.channel._id;
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
