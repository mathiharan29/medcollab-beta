import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';

async function fixture(identity, request, name) {
  const a = await identity('A'), b = await identity('B');
  const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name, type: 'department' }, expectedStatus: 201 });
  await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
  return { a, b, space: created.data.space, general: created.data.channels.find((item) => item.name === 'general')._id, emergency: created.data.channels.find((item) => item.name === 'emergency')._id };
}

const cases = [{
  id: 'FR-NOT-01', module: 'NOT',
  run: async ({ identity, request, db, origin }) => {
    const { a, b, general, emergency } = await fixture(identity, request, 'Synthetic Viewed Notifications');
    const socket = await connectSocket(null, origin, b.token);
    try {
      const join = async (channelId) => {
        const ack = waitFor(socket, 'join_channel', (event) => event?.success === true && event.channelId === channelId);
        socket.emit('join_channel', { channelId }); await ack;
      };
      await join(general);
      const send = async (text, priority = 'normal') => {
        const event = waitFor(socket, 'new_message', (payload) => payload?.content?.text === text);
        const message = (await request(`/api/channels/${general}/messages`, { method: 'POST', token: a.token, body: { priority, content: { text } }, expectedStatus: 201 })).data.message;
        assert.equal((await event)._id, message._id);
        return message;
      };
      const ordinaryViewed = await send('Synthetic ordinary while viewing');
      const emergencyNotification = waitFor(socket, 'new_notification', (payload) => payload?.body === 'Synthetic emergency while viewing');
      const urgentViewed = await send('Synthetic emergency while viewing', 'emergency');
      assert.equal((await emergencyNotification).referenceId, urgentViewed._id);
      socket.emit('leave_channel', { channelId: general });
      await join(emergency); // Ordered socket acknowledgement confirms leave was handled first.
      const laterNotification = waitFor(socket, 'new_notification', (payload) => payload?.body === 'Synthetic ordinary after leaving');
      const ordinaryAfterLeave = (await request(`/api/channels/${general}/messages`, { method: 'POST', token: a.token, body: { content: { text: 'Synthetic ordinary after leaving' } }, expectedStatus: 201 })).data.message;
      assert.equal((await laterNotification).referenceId, ordinaryAfterLeave._id);
      const inbox = await request('/api/notifications', { token: b.token });
      const ids = inbox.data.notifications.map((item) => item.referenceId);
      assert.deepEqual(new Set(ids), new Set([urgentViewed._id, ordinaryAfterLeave._id]));
      assert.ok(!ids.includes(ordinaryViewed._id));
      assert.equal(inbox.data.notifications.find((item) => item.referenceId === urgentViewed._id).type, 'emergency_alert');
      assert.equal(inbox.data.notifications.find((item) => item.referenceId === ordinaryAfterLeave._id).type, 'new_message');
      await db(async (connection) => {
        const rows = await connection.collection('notifications').find({ referenceId: { $in: [ordinaryViewed, urgentViewed, ordinaryAfterLeave].map((item) => new connection.base.Types.ObjectId(item._id)) } }).toArray();
        assert.equal(rows.length, 2);
        assert.ok(rows.every((item) => String(item.userId) === b.userId));
      });
    } finally { socket.disconnect(); }
  },
}, {
  id: 'FR-NOT-02', module: 'NOT',
  run: async ({ identity, request, db, origin }) => {
    const { a, b, general, emergency } = await fixture(identity, request, 'Synthetic Mention Suppression');
    const socket = await connectSocket(null, origin, b.token);
    try {
      const join = async (channelId) => {
        const ack = waitFor(socket, 'join_channel', (event) => event?.success === true && event.channelId === channelId);
        socket.emit('join_channel', { channelId }); await ack;
      };
      await join(general);
      const path = `/api/channels/${general}/messages`;
      const send = async (text) => (await request(path, { method: 'POST', token: a.token, body: { content: { text }, mentions: [b.userId, a.userId] }, expectedStatus: 201 })).data.message;
      const viewedEvent = waitFor(socket, 'new_message', (payload) => payload?.content?.text === 'Synthetic mention while viewing');
      const viewed = await send('Synthetic mention while viewing');
      assert.equal((await viewedEvent)._id, viewed._id);
      socket.emit('leave_channel', { channelId: general });
      await join(emergency);
      const mentionEvent = waitFor(socket, 'new_notification', (payload) => payload?.type === 'mention' && payload?.body === 'Synthetic mention after leaving');
      const later = await send('Synthetic mention after leaving');
      assert.equal((await mentionEvent).referenceId, later._id);
      const inbox = await request('/api/notifications', { token: b.token });
      const laterRows = inbox.data.notifications.filter((item) => item.referenceId === later._id);
      assert.ok(laterRows.some((item) => item.type === 'mention'));
      assert.ok(laterRows.some((item) => item.type === 'new_message'), 'Ordinary and mention notification types may coexist');
      assert.ok(!inbox.data.notifications.some((item) => item.referenceId === viewed._id));
      await db(async (connection) => {
        const rows = await connection.collection('notifications').find({ referenceId: { $in: [viewed, later].map((item) => new connection.base.Types.ObjectId(item._id)) } }).toArray();
        assert.ok(rows.every((item) => String(item.userId) === b.userId), 'Self mentions must never notify the sender');
        assert.ok(!rows.some((item) => String(item.referenceId) === viewed._id));
        assert.deepEqual(new Set(rows.filter((item) => String(item.referenceId) === later._id).map((item) => item.type)), new Set(['new_message', 'mention']));
      });
    } finally { socket.disconnect(); }
  },
}, {
  id: 'FR-NOT-05', module: 'NOT',
  prerequisiteSeed: 'Disposable MongoDB notification collection validator rejects exactly the first synthetic message body, then is removed after the backend failure log',
  run: async ({ identity, request, db, origin, waitForBackendLog }) => {
    const { a, b, general } = await fixture(identity, request, 'Synthetic Notification Recovery');
    const firstText = 'Synthetic notification insert rejection';
    const secondText = 'Synthetic notification after recovery';
    await db(async (connection) => {
      const exists = (await connection.db.listCollections({ name: 'notifications' }).toArray()).length > 0;
      if (exists) await connection.db.command({ collMod: 'notifications', validator: { body: { $ne: firstText } }, validationAction: 'error' });
      else await connection.db.createCollection('notifications', { validator: { body: { $ne: firstText } }, validationAction: 'error' });
    });
    const socket = await connectSocket(null, origin, b.token);
    try {
      const firstFailure = waitForBackendLog(`Notification failed for user ${b.userId}`);
      const path = `/api/channels/${general}/messages`;
      const first = (await request(path, { method: 'POST', token: a.token, body: { content: { text: firstText } }, expectedStatus: 201 })).data.message;
      assert.ok((await firstFailure).includes('Document failed validation'));
      const afterFailure = await request(path, { token: b.token });
      assert.equal(afterFailure.data.messages.find((item) => item._id === first._id)?.content.text, firstText);
      await db(async (connection) => {
        const id = new connection.base.Types.ObjectId(first._id);
        assert.equal(await connection.collection('messages').countDocuments({ _id: id }), 1);
        assert.equal(await connection.collection('notifications').countDocuments({ referenceId: id }), 0);
        await connection.db.command({ collMod: 'notifications', validator: {}, validationAction: 'error' });
      });
      const notification = waitFor(socket, 'new_notification', (payload) => payload?.body === secondText);
      const second = (await request(path, { method: 'POST', token: a.token, body: { content: { text: secondText } }, expectedStatus: 201 })).data.message;
      assert.equal((await notification).referenceId, second._id);
      const inbox = await request('/api/notifications', { token: b.token });
      assert.deepEqual(inbox.data.notifications.map((item) => item.referenceId), [second._id], 'No automatic replay of the first failed notification is promised');
      await db(async (connection) => {
        assert.equal(await connection.collection('messages').countDocuments({ channelId: new connection.base.Types.ObjectId(general) }), 2);
        assert.equal(await connection.collection('notifications').countDocuments({ referenceId: new connection.base.Types.ObjectId(second._id), userId: new connection.base.Types.ObjectId(b.userId) }), 1);
      });
    } finally { socket.disconnect(); }
  },
}, {
  id: 'FR-NOT-03', module: 'NOT',
  prerequisiteSeed: 'Seven synthetic inbox documents inserted with controlled ObjectIds and read/type values to isolate cursor filtering',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const ids = Array.from({ length: 7 }, (_, index) => `6ac8f500000000000000${(index + 1).toString(16).padStart(4, '0')}`);
    const types = ['mention', 'new_message', 'mention', 'emergency_alert', 'mention', 'new_message', 'mention'];
    const read = [false, true, false, false, true, false, false];
    await db(async (connection) => {
      const objectId = (value) => new connection.base.Types.ObjectId(value);
      const rows = ids.map((id, index) => ({
        _id: objectId(id), userId: objectId(a.userId), type: types[index], title: `Synthetic ${index + 1}`, body: `Synthetic inbox ${index + 1}`,
        referenceId: objectId(id), referenceType: 'Message', metadata: { messageId: objectId(id) }, read: read[index],
        readAt: read[index] ? new Date(Date.UTC(2026, 0, 2)) : null, priority: 'normal',
        createdAt: new Date(Date.UTC(2026, 0, 1) + index * 1000), updatedAt: new Date(Date.UTC(2026, 0, 1) + index * 1000),
        expiresAt: new Date(Date.UTC(2027, 0, 1)),
      }));
      assert.equal((await connection.collection('notifications').insertMany(rows)).insertedCount, 7);
    });
    const pages = [];
    let before;
    for (let index = 0; index < 3; index++) {
      const page = await request(`/api/notifications?limit=3${before ? `&before=${before}` : ''}`, { token: a.token });
      pages.push(page.data);
      assert.equal(page.data.unreadCount, 5);
      assert.equal(page.data.hasMore, index < 2);
      before = page.data.notifications.at(-1)._id;
    }
    assert.deepEqual(pages.flatMap((page) => page.notifications.map((item) => item._id)), ids.slice().reverse());
    const empty = await request(`/api/notifications?limit=3&before=${ids[0]}`, { token: a.token });
    assert.deepEqual(empty.data.notifications, []);
    assert.equal(empty.data.hasMore, false);
    const filtered = await request('/api/notifications?limit=2&unreadOnly=true&type=mention', { token: a.token });
    assert.deepEqual(filtered.data.notifications.map((item) => item._id), [ids[6], ids[2]]);
    assert.equal(filtered.data.hasMore, true);
    assert.equal(filtered.data.unreadCount, 5, 'Unread count must be total, not page or type filtered');
    const filteredOlder = await request(`/api/notifications?limit=2&unreadOnly=true&type=mention&before=${ids[2]}`, { token: a.token });
    assert.deepEqual(filteredOlder.data.notifications.map((item) => item._id), [ids[0]]);
    assert.equal(filteredOlder.data.hasMore, false);
    await db(async (connection) => assert.equal(await connection.collection('notifications').countDocuments({ userId: new connection.base.Types.ObjectId(a.userId), read: false }), 5));
  },
}, {
  id: 'FR-NOT-04', module: 'NOT',
  prerequisiteSeed: 'Synthetic inbox records inserted with both string and ObjectId channel metadata, bypassing schema casting for the legacy representation',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const targetId = '6ac8f6000000000000000001', unrelatedId = '6ac8f6000000000000000002';
    const ids = ['6ac8f6000000000000000011', '6ac8f6000000000000000012', '6ac8f6000000000000000013'];
    await db(async (connection) => {
      const objectId = (value) => new connection.base.Types.ObjectId(value);
      const rows = ids.map((id, index) => ({
        _id: objectId(id), userId: objectId(a.userId), type: 'new_message', title: `Synthetic ${index}`, body: `Synthetic channel alert ${index}`,
        referenceId: objectId(id), referenceType: 'Message', metadata: { channelId: index === 0 ? targetId : objectId(index === 1 ? targetId : unrelatedId) },
        read: false, readAt: null, priority: 'normal', createdAt: new Date(), updatedAt: new Date(), expiresAt: new Date(Date.UTC(2027, 0, 1)),
      }));
      assert.equal((await connection.collection('notifications').insertMany(rows)).insertedCount, 3);
    });
    const route = `/api/notifications/read-by-channel/${targetId}`;
    const first = await request(route, { method: 'PUT', token: a.token });
    assert.equal(first.data.modifiedCount, 2);
    assert.equal(first.data.unreadCount, 1);
    const repeat = await request(route, { method: 'PUT', token: a.token });
    assert.equal(repeat.data.modifiedCount, 0);
    assert.equal(repeat.data.unreadCount, 1);
    const count = await request('/api/notifications/unread-count', { token: a.token });
    assert.equal(count.data.count, 1);
    const inbox = await request('/api/notifications', { token: a.token });
    assert.deepEqual(new Set(inbox.data.notifications.filter((item) => item.read).map((item) => item._id)), new Set(ids.slice(0, 2)));
    assert.equal(inbox.data.notifications.find((item) => item._id === ids[2]).read, false);
    await db(async (connection) => {
      const stored = await connection.collection('notifications').find({ userId: new connection.base.Types.ObjectId(a.userId) }).toArray();
      assert.equal(stored.filter((item) => item.read && item.readAt instanceof Date).length, 2);
      assert.equal(stored.find((item) => String(item._id) === ids[2]).readAt, null);
    });
  },
}];

for (const item of cases) await runModule(`notifications-${item.id.slice(-2).toLowerCase()}`, [item]);
