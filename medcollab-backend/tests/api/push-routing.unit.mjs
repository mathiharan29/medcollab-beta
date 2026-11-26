// Beta 11-26, issue 5: a message must still be PUSHED to a phone the server
// thinks is "viewing" the chat (it may have just lost mobile data), without
// an Alerts entry; and pushes must not be collapsible.
// Runs without MongoDB / Firebase: dependencies are stubbed.
//   node --test tests/api/push-routing.unit.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const src = (p) => require.resolve(`../../src/${p}`);

const inbox = [];
const pushes = [];
const viewers = new Set();
const users = {
  viewer: { fcmTokens: ['tok-viewer'], notifications: {} },
  away: { fcmTokens: ['tok-away'], notifications: {} },
};
const stub = (path, exports) => { require.cache[src(path)] = { id: src(path), filename: src(path), loaded: true, exports }; };

stub('features/notifications/notification.model.js', {
  create: async (doc) => { inbox.push(doc); return { ...doc, _id: { toString: () => `n${inbox.length}` }, toObject: () => doc }; },
});
stub('features/users/user.model.js', {
  findById: (id) => ({ select: async () => users[id] || null }),
  find: () => ({ select: () => ({ lean: async () => [] }) }),
});
stub('socket/index.js', { emitNotification: () => {}, getIO: () => null });
stub('socket/channelViewers.js', { getUserIdsViewingChannel: async () => viewers });
stub('config/firebase.js', { getFirebaseMessaging: () => ({ send: async (m) => { pushes.push(m); return 'ok'; } }) });

const { notifyNewMessage } = require(src('services/notification.service.js'));
const channel = { _id: 'chat1', spaceId: null };
const sender = { _id: 'sender', name: 'Dr Bala' };

test('viewer whose phone may be offline still gets the push, but no Alerts entry', async () => {
  inbox.length = 0; pushes.length = 0; viewers.clear(); viewers.add('viewer');
  await notifyNewMessage({
    recipientIds: ['sender', 'viewer', 'away'],
    message: { _id: 'm1', priority: 'normal', type: 'text', content: { text: 'Can you see bed 7 now?' } },
    sender, channel,
  });
  assert.deepEqual(inbox.map((n) => n.userId).sort(), ['away'], 'Alerts entry only for the person not viewing');
  assert.deepEqual(pushes.map((p) => p.token).sort(), ['tok-away', 'tok-viewer'], 'both phones get the push');
  const viewerPush = pushes.find((p) => p.token === 'tok-viewer');
  assert.equal(viewerPush.data.body, 'Can you see bed 7 now?');
  assert.equal(viewerPush.data.channelId, 'chat1');
});

test('pushes are not collapsible and are kept while the phone is offline', async () => {
  for (const p of pushes) {
    assert.equal(p.android.collapseKey, undefined);
    assert.equal(p.android.priority, 'high');
    assert.ok(p.android.ttl >= 60 * 60 * 1000);
  }
});

test('emergency: viewers also get the Alerts entry (unchanged)', async () => {
  inbox.length = 0; pushes.length = 0; viewers.clear(); viewers.add('viewer');
  await notifyNewMessage({
    recipientIds: ['viewer'],
    message: { _id: 'm2', priority: 'emergency', type: 'text', content: { text: 'Code blue bed 4' } },
    sender, channel,
  });
  assert.deepEqual(inbox.map((n) => n.userId), ['viewer']);
  assert.equal(pushes.length, 1);
});
