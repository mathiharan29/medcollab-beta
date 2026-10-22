import assert from 'node:assert/strict';
import { readFile, rename, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { runModule } from '../src/module-runner.mjs';
import { DecisionPending } from '../src/runner.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';

const cases = [{
  id: 'FR-PUSH-01', module: 'PUSH',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const register = async (token) => request('/api/users/me/fcm-token', { method: 'PUT', token: a.token, body: { token } });
    for (let index = 1; index <= 6; index++) await register(`synthetic-device-token-${index}`);
    const tokens = async () => db(async (connection) => {
      const user = await connection.collection('users').findOne({ _id: new connection.base.Types.ObjectId(a.userId) });
      return user.fcmTokens;
    });
    assert.deepEqual(await tokens(), [6, 5, 4, 3, 2].map((index) => `synthetic-device-token-${index}`));
    await register('synthetic-device-token-3');
    assert.deepEqual(await tokens(), [3, 6, 5, 4, 2].map((index) => `synthetic-device-token-${index}`));
    await request('/api/auth/logout', { method: 'POST', token: a.token, body: { fcmToken: 'synthetic-device-token-3' } });
    assert.deepEqual(await tokens(), [6, 5, 4, 2].map((index) => `synthetic-device-token-${index}`));
    const profile = await request('/api/users/me', { token: a.token });
    assert.equal(profile.data.user._id, a.userId, 'Removing one device token must not delete the account or other tokens');
  },
}, {
  id: 'FR-PUSH-02', module: 'PUSH', fakeFirebase: true, timeoutMs: 60000,
  run: async ({ identity, request, db, origin, inbox, waitForBackendLog }) => {
    const a = await identity('A'), b = await identity('B');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Push Preferences', type: 'department' }, expectedStatus: 201 });
    const space = created.data.space;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: space.inviteCode } });
    const channelId = created.data.channels.find((item) => item.name === 'general')._id;
    const tokenA = 'synthetic-fcm-pref-A', tokenB = 'synthetic-fcm-pref-B';
    await request('/api/users/me/fcm-token', { method: 'PUT', token: a.token, body: { token: tokenA } });
    await request('/api/users/me/fcm-token', { method: 'PUT', token: b.token, body: { token: tokenB } });
    const prefs = (person, values) => request('/api/users/me', { method: 'PUT', token: person.token, body: { notifications: values } });
    await prefs(a, { handoffs: false });
    await prefs(b, { newMessages: false, mentions: false, emergencyAlerts: false, handoffs: false });
    const sockets = { A: await connectSocket(null, origin, a.token), B: await connectSocket(null, origin, b.token) };
    const observed = [];
    try {
      const send = async (type, text, bodyExtras = {}, enabled = false) => {
        const notification = waitFor(sockets.B, 'new_notification', (payload) => payload?.type === type && payload?.body === text);
        const message = (await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body: { content: { text }, ...bodyExtras }, expectedStatus: 201 })).data.message;
        const emitted = await notification;
        assert.equal(emitted.referenceId, message._id);
        if (enabled) await waitForBackendLog(`VOCLE_FAKE_FCM_CAPTURE ${emitted._id} ${tokenB} success`);
        observed.push({ id: emitted._id, type, enabled });
        return message;
      };
      await send('new_message', 'Synthetic pref ordinary disabled');
      await prefs(b, { newMessages: true });
      await send('new_message', 'Synthetic pref ordinary enabled', {}, true);
      await prefs(b, { newMessages: false });
      await send('mention', 'Synthetic pref mention disabled', { mentions: [b.userId] });
      await prefs(b, { mentions: true });
      await send('mention', 'Synthetic pref mention enabled', { mentions: [b.userId] }, true);
      await prefs(b, { mentions: false });
      await send('emergency_alert', 'Synthetic pref emergency disabled', { priority: 'emergency' });
      await prefs(b, { emergencyAlerts: true });
      await send('emergency_alert', 'Synthetic pref emergency enabled', { priority: 'emergency' }, true);
      await prefs(b, { emergencyAlerts: false });
      const handoff = async (enabled) => {
        const name = enabled ? 'enabled' : 'disabled';
        const draft = (await request('/api/handoffs', { method: 'POST', token: a.token, body: {
          spaceId: space._id, channelId, toUserId: b.userId, shiftDate: '2030-01-15T00:00:00.000Z', shiftType: 'night',
          shiftSummary: `Synthetic pref handoff ${name}`, patients: [{ bedNumber: 'S-07', ward: 'Synthetic ICU', clinicalAlias: `Synthetic patient ${name}`, diagnosis: 'Synthetic', status: 'monitoring', notes: 'Synthetic notes', pendingTasks: ['Synthetic follow-up'] }],
        }, expectedStatus: 201 })).data.handoff;
        const received = waitFor(sockets.B, 'new_notification', (payload) => payload?.type === 'handoff_received' && payload?.referenceId === draft._id);
        await request(`/api/handoffs/${draft._id}/submit`, { method: 'POST', token: a.token });
        const receivedEvent = await received;
        if (enabled) await waitForBackendLog(`VOCLE_FAKE_FCM_CAPTURE ${receivedEvent._id} ${tokenB} success`);
        observed.push({ id: receivedEvent._id, type: 'handoff_received', enabled });
        const acknowledged = waitFor(sockets.A, 'new_notification', (payload) => payload?.type === 'handoff_acknowledged' && payload?.referenceId === draft._id);
        await request(`/api/handoffs/${draft._id}/acknowledge`, { method: 'POST', token: b.token, body: { note: `Synthetic acknowledge ${name}` } });
        const ackEvent = await acknowledged;
        if (enabled) await waitForBackendLog(`VOCLE_FAKE_FCM_CAPTURE ${ackEvent._id} ${tokenA} success`);
        observed.push({ id: ackEvent._id, type: 'handoff_acknowledged', enabled });
      };
      await handoff(false);
      await prefs(a, { handoffs: true });
      await prefs(b, { handoffs: true });
      await handoff(true);
      const captures = (await readFile(join(inbox, 'fcm-capture.ndjson'), 'utf8')).trim().split('\n').map((line) => JSON.parse(line));
      assert.deepEqual(new Set(captures.map((item) => item.message.data.notificationId)), new Set(observed.filter((item) => item.enabled).map((item) => item.id)), 'Disabled notification types must not call the fake push provider');
      assert.ok(captures.every((item) => [tokenA, tokenB].includes(item.message.token)));
      await db(async (connection) => {
        const ids = observed.map((item) => new connection.base.Types.ObjectId(item.id));
        assert.equal(await connection.collection('notifications').countDocuments({ _id: { $in: ids } }), observed.length, 'Inbox records must persist independent of push preferences');
      });
    } finally { sockets.A.disconnect(); sockets.B.disconnect(); }
  },
}, {
  id: 'FR-PUSH-03', module: 'PUSH', fakeFirebase: true, fakeClock: true,
  run: async ({ identity, request, db, origin, inbox, waitForBackendLog }) => {
    const a = await identity('A'), b = await identity('B');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Quiet Hour Boundaries', type: 'department' }, expectedStatus: 201 });
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
    const channelId = created.data.channels.find((item) => item.name === 'general')._id;
    const token = 'synthetic-fcm-quiet-hours';
    await request('/api/users/me/fcm-token', { method: 'PUT', token: b.token, body: { token } });
    const socket = await connectSocket(null, origin, b.token);
    const observations = [];
    try {
      const scenarios = [
        ['2026-10-09T09:00:00.000Z', '09:00', '09:01', 'normal', true, false, 'same-day start inclusive'],
        ['2026-10-09T09:01:00.000Z', '09:00', '09:01', 'normal', true, true, 'same-day end exclusive'],
        ['2026-10-08T23:00:00.000Z', '23:00', '01:00', 'normal', true, false, 'overnight start inclusive'],
        ['2026-10-09T00:30:00.000Z', '23:00', '01:00', 'normal', true, false, 'overnight inside'],
        ['2026-10-09T01:00:00.000Z', '23:00', '01:00', 'normal', true, true, 'overnight end exclusive'],
        ['2026-10-09T10:00:00.000Z', '10:00', '10:00', 'normal', true, true, 'equal endpoints disable quiet hours'],
        ['2026-10-09T00:30:00.000Z', '23:00', '01:00', 'emergency', true, true, 'emergency bypasses quiet hours'],
        ['2026-10-09T00:30:00.000Z', '23:00', '01:00', 'emergency', false, false, 'disabled emergency preference takes precedence'],
        ['2026-10-09T00:30:00.000Z', '23:00', '01:00', 'emergency', true, true, 'enabled emergency control after disabled case'],
      ];
      for (const [index, scenario] of scenarios.entries()) {
        const [iso, start, end, priority, emergencyAlerts, shouldPush, label] = scenario;
        const clockFile = `clock-${String(index).padStart(2, '0')}.json`;
        const pendingClock = join(inbox, `${clockFile}.tmp`);
        await writeFile(pendingClock, JSON.stringify({ iso }));
        await rename(pendingClock, join(inbox, clockFile));
        const updated = await request('/api/users/me', { method: 'PUT', token: b.token, body: { notifications: { quietHoursStart: start, quietHoursEnd: end, emergencyAlerts } } });
        assert.equal(updated.data.user.notifications.quietHoursStart, start);
        assert.equal(updated.data.user.notifications.quietHoursEnd, end);
        assert.equal(updated.data.user.notifications.emergencyAlerts, emergencyAlerts);
        const text = `Synthetic quiet ${label}`;
        const notification = waitFor(socket, 'new_notification', (payload) => payload?.body === text);
        const message = (await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body: { priority, content: { text } }, expectedStatus: 201 })).data.message;
        const emitted = await notification;
        assert.equal(emitted.referenceId, message._id);
        await waitForBackendLog(`VOCLE_FAKE_NOTIFY_DONE ${message._id}`);
        if (shouldPush) await waitForBackendLog(`VOCLE_FAKE_FCM_CAPTURE ${emitted._id} ${token} success`);
        observations.push({ label, notificationId: emitted._id, shouldPush, priority: emitted.priority });
      }
      const captures = (await readFile(join(inbox, 'fcm-capture.ndjson'), 'utf8')).trim().split('\n').map((line) => JSON.parse(line));
      assert.deepEqual(new Set(captures.map((item) => item.message.data.notificationId)), new Set(observations.filter((item) => item.shouldPush).map((item) => item.notificationId)));
      assert.ok(captures.every((item) => item.message.token === token));
      await db(async (connection) => {
        const rows = await connection.collection('notifications').find({ userId: new connection.base.Types.ObjectId(b.userId) }).toArray();
        assert.equal(rows.length, scenarios.length, 'Quiet hours suppress push, not the inbox');
      });
      throw new DecisionPending('Q9: client/device timezone policy for quiet hours needs product decision', observations.map((item) => `${item.label}: inbox ${item.notificationId}, fake push ${item.shouldPush}, priority ${item.priority}`));
    } finally { socket.disconnect(); }
  },
}, {
  id: 'FR-PUSH-04', module: 'PUSH', fakeFirebase: true,
  run: async ({ identity, request, db, origin, inbox, waitForBackendLog }) => {
    const a = await identity('A'), b = await identity('B');
    const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Push Errors', type: 'department' }, expectedStatus: 201 });
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
    const channelId = created.data.channels.find((item) => item.name === 'general')._id;
    const tokens = ['synthetic-fcm-stale', 'synthetic-fcm-temporary', 'synthetic-fcm-success'];
    for (const token of tokens) await request('/api/users/me/fcm-token', { method: 'PUT', token: b.token, body: { token } });
    await writeFile(join(inbox, 'fcm-modes.json'), JSON.stringify({ [tokens[0]]: 'stale', [tokens[1]]: 'temporary' }));
    const socket = await connectSocket(null, origin, b.token);
    try {
      const messageText = 'Synthetic push error correlation';
      const notification = waitFor(socket, 'new_notification', (payload) => payload?.body === messageText);
      const captured = tokens.map((token) => waitForBackendLog(` ${token} `));
      const sent = (await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body: { content: { text: messageText } }, expectedStatus: 201 })).data.message;
      const inboxEvent = await notification;
      assert.equal(inboxEvent.referenceId, sent._id);
      await Promise.all(captured);
      const lines = (await readFile(join(inbox, 'fcm-capture.ndjson'), 'utf8')).trim().split('\n').map((line) => JSON.parse(line));
      assert.deepEqual(new Set(lines.map((item) => item.message.token)), new Set(tokens));
      for (const item of lines) {
        assert.equal(item.message.data.notificationId, inboxEvent._id);
        assert.equal(item.message.data.channelId, channelId);
        assert.equal(item.message.data.messageId, sent._id);
        assert.ok(Object.values(item.message.data).every((value) => typeof value === 'string'));
        assert.equal(item.message.android.collapseKey, channelId);
        assert.equal(item.message.apns.payload.aps['thread-id'], channelId);
      }
      const deadline = Date.now() + 5000;
      let savedTokens;
      do {
        savedTokens = await db(async (connection) => (await connection.collection('users').findOne({ _id: new connection.base.Types.ObjectId(b.userId) })).fcmTokens);
        if (!savedTokens.includes(tokens[0])) break;
        await new Promise((resolve) => setTimeout(resolve, 25));
      } while (Date.now() < deadline);
      assert.deepEqual(new Set(savedTokens), new Set(tokens.slice(1)), 'Only the stale token must be removed');
      await db(async (connection) => {
        const stored = await connection.collection('notifications').find({ referenceId: new connection.base.Types.ObjectId(sent._id) }).toArray();
        assert.equal(stored.length, 1);
        assert.equal(String(stored[0].userId), b.userId);
      });
    } finally { socket.disconnect(); }
  },
}];

for (const item of cases) await runModule(`push-${item.id.slice(-2).toLowerCase()}`, [item]);
