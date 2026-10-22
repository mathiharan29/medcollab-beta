import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createFixtureUsers } from './fixtures.js';
import { closeDatabase, connectDatabase } from './database.js';
import { expectSuccess, request } from './http.js';
import { closeRealtime, connectRealtime, joinChannel, waitFor } from './socket-client.js';

const results = [];
const assert = (value, message) => { if (!value) throw new Error(message); };
const marker = (name) => `sanity-notification-${name}`;
async function scenario(id, action) {
  const startedAt = Date.now();
  try { await action(); results.push({ id, status: 'passed', durationMs: Date.now() - startedAt }); }
  catch (error) { results.push({ id, status: 'failed', durationMs: Date.now() - startedAt, error: error.message }); throw error; }
}
async function eventually(label, action) {
  const deadline = Date.now() + 10_000;
  while (Date.now() < deadline) { const result = await action(); if (result) return result; await new Promise((resolvePromise) => setTimeout(resolvePromise, 100)); }
  throw new Error(`Timed out waiting for ${label}.`);
}
async function send(channelId, token, text, extra = {}) {
  return expectSuccess(await request(`/api/channels/${channelId}/messages`, { method: 'POST', token, expectedStatus: 201, body: { type: 'text', content: { text }, ...extra } }), `send ${text}`).message;
}
async function inbox(token) { return expectSuccess(await request('/api/notifications?limit=100', { token }), 'read notification inbox'); }

async function run() {
  await connectDatabase();
  const people = await createFixtureUsers();
  let general; let emergency; let clientB;
  try {
    const created = expectSuccess(await request('/api/spaces', { method: 'POST', token: people.A.token, expectedStatus: 201, body: { name: 'Sanity Notification Space', type: 'department', description: 'Notification fixture' } }), 'create notification space');
    general = created.channels.find((item) => item.name === 'general'); emergency = created.channels.find((item) => item.name === 'emergency');
    await request('/api/spaces/join', { method: 'POST', token: people.B.token, body: { inviteCode: created.space.inviteCode } });
    clientB = await connectRealtime(people.B.token);
    await Promise.all([joinChannel(clientB, general._id), joinChannel(clientB, emergency._id)]);

    await scenario('notifications-01', async () => {
      const event = waitFor(clientB.socket, 'new_notification', (payload) => payload?.type === 'new_message');
      const message = await send(general._id, people.A.token, marker('ordinary'));
      const delivered = await event;
      const current = await eventually('ordinary notification persistence', async () => (await inbox(people.B.token)).notifications.find((item) => String(item.referenceId) === message._id));
      const count = expectSuccess(await request('/api/notifications/unread-count', { token: people.B.token }), 'read notification count');
      assert(delivered.referenceId === message._id && current.type === 'new_message' && String(current.metadata?.channelId) === general._id, 'Ordinary message notification metadata or socket delivery was incorrect.');
      assert(count.count >= 1, 'Unread notification count did not include ordinary message.');
    });

    await scenario('notifications-02', async () => {
      const mentionEvent = waitFor(clientB.socket, 'new_notification', (payload) => payload?.type === 'mention');
      const mention = await send(general._id, people.A.token, marker('mention'), { mentions: [people.B.userId] });
      await mentionEvent;
      const emergencyEvent = waitFor(clientB.socket, 'new_notification', (payload) => payload?.type === 'emergency_alert');
      const emergencyMessage = await send(emergency._id, people.A.token, marker('emergency'));
      await emergencyEvent;
      const current = await eventually('mention and emergency persistence', async () => {
        const entries = (await inbox(people.B.token)).notifications;
        return entries.some((item) => item.type === 'mention' && String(item.referenceId) === mention._id) && entries.some((item) => item.type === 'emergency_alert' && String(item.referenceId) === emergencyMessage._id) ? entries : null;
      });
      const emergencyNotification = current.find((item) => item.type === 'emergency_alert' && String(item.referenceId) === emergencyMessage._id);
      assert(emergencyNotification.priority === 'emergency', 'Emergency notification priority was incorrect.');
    });

    await scenario('notifications-03', async () => {
      const initial = await inbox(people.B.token);
      const first = initial.notifications.find((item) => !item.read);
      assert(first, 'No unread notification was available for lifecycle checks.');
      await request(`/api/notifications/${first._id}/read`, { method: 'PUT', token: people.B.token });
      await request(`/api/notifications/${first._id}/unread`, { method: 'PUT', token: people.B.token });
      const channelRead = expectSuccess(await request(`/api/notifications/read-by-channel/${general._id}`, { method: 'PUT', token: people.B.token }), 'mark channel notifications read');
      const allRead = expectSuccess(await request('/api/notifications/read-all', { method: 'PUT', token: people.B.token }), 'mark all notifications read');
      const afterRead = await inbox(people.B.token);
      const deleted = afterRead.notifications[0];
      await request(`/api/notifications/${deleted._id}`, { method: 'DELETE', token: people.B.token });
      const final = await inbox(people.B.token);
      const count = expectSuccess(await request('/api/notifications/unread-count', { token: people.B.token }), 'read final notification count');
      assert(channelRead.unreadCount >= 0 && allRead.modifiedCount >= 0, 'Notification batch read endpoints returned invalid results.');
      assert(!final.notifications.some((item) => item._id === deleted._id) && count.count === 0, 'Notification delete/read state did not leave a consistent inbox.');
    });
  } finally {
    closeRealtime(clientB); await closeDatabase();
    const output = resolve(process.env.SANITY_OUTPUT_DIR || 'output'); await mkdir(output, { recursive: true });
    await writeFile(resolve(output, 'notification-results.json'), `${JSON.stringify({ expected: 3, results }, null, 2)}\n`);
  }
  console.log('Notification scenarios passed: 3/3.');
}
run().catch(async (error) => { console.error(error.stack || error.message); await closeDatabase(); process.exitCode = 1; });
