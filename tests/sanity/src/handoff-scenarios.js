import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createFixtureUsers } from './fixtures.js';
import { closeDatabase, connectDatabase, handoffById, notificationFor } from './database.js';
import { expectSuccess, request } from './http.js';
import { closeRealtime, connectRealtime, waitFor } from './socket-client.js';

const results = [];
const assert = (value, message) => { if (!value) throw new Error(message); };
const marker = (name) => `sanity-handoff-${name}`;
const patient = (attachments = []) => ({ bedNumber: 'S-07', ward: 'Sanity ICU', clinicalAlias: 'Synthetic ACS case', diagnosis: 'Synthetic diagnosis', status: 'monitoring', notes: marker('patient-notes'), pendingTasks: ['Synthetic ECG review'], isFlagged: true, attachments });
async function scenario(id, action) {
  const startedAt = Date.now();
  try { await action(); results.push({ id, status: 'passed', durationMs: Date.now() - startedAt }); }
  catch (error) { results.push({ id, status: 'failed', durationMs: Date.now() - startedAt, error: error.message }); throw error; }
}
async function eventually(label, condition) {
  const deadline = Date.now() + 10_000;
  while (Date.now() < deadline) { const result = await condition(); if (result) return result; await new Promise((resolvePromise) => setTimeout(resolvePromise, 100)); }
  throw new Error(`Timed out waiting for ${label}.`);
}

async function run() {
  await connectDatabase();
  const people = await createFixtureUsers();
  let space; let channel; let handoff; let clientA; let clientB; let clientC;
  const base = (toUserId, patients = [patient()]) => ({ spaceId: space._id, channelId: channel._id, toUserId, shiftDate: '2030-01-15T00:00:00.000Z', shiftType: 'night', shiftSummary: marker('summary'), patients });
  try {
    const created = expectSuccess(await request('/api/spaces', { method: 'POST', token: people.A.token, expectedStatus: 201, body: { name: 'Sanity Handoff Space', type: 'department', description: 'Handoff fixture' } }), 'create handoff space');
    space = created.space; channel = created.channels.find((item) => item.name === 'general');
    await request('/api/spaces/join', { method: 'POST', token: people.B.token, body: { inviteCode: space.inviteCode } });
    await request('/api/spaces/join', { method: 'POST', token: people.C.token, body: { inviteCode: space.inviteCode } });
    clientA = await connectRealtime(people.A.token); clientB = await connectRealtime(people.B.token); clientC = await connectRealtime(people.C.token);

    await scenario('handoffs-01', async () => {
      const createdDraft = expectSuccess(await request('/api/handoffs', { method: 'POST', token: people.A.token, expectedStatus: 201, body: base(people.B.userId, [patient([{ url: 'https://res.cloudinary.com/sanity/image/upload/handoff.png', fileName: 'handoff.png', mimeType: 'image/png' }])]) }), 'create handoff draft').handoff;
      const updated = expectSuccess(await request(`/api/handoffs/${createdDraft._id}`, { method: 'PUT', token: people.A.token, body: { shiftSummary: marker('updated-summary') } }), 'edit handoff draft').handoff;
      const detail = expectSuccess(await request(`/api/handoffs/${createdDraft._id}`, { token: people.A.token }), 'read handoff draft').handoff;
      assert(updated.status === 'draft' && detail.patients[0].attachments[0].fileName === 'handoff.png' && detail.shiftSummary === marker('updated-summary'), 'Draft handoff edit/read did not preserve patient attachment data.');
    });

    await scenario('handoffs-02', async () => {
      const empty = expectSuccess(await request('/api/handoffs', { method: 'POST', token: people.A.token, expectedStatus: 201, body: base(people.B.userId, []) }), 'create empty handoff').handoff;
      await request(`/api/handoffs/${empty._id}/submit`, { method: 'POST', token: people.A.token, expectedStatus: 400 });
      await request(`/api/handoffs/${empty._id}`, { method: 'DELETE', token: people.A.token });
      await request(`/api/handoffs/${empty._id}`, { token: people.A.token, expectedStatus: 404 });
    });

    await scenario('handoffs-03', async () => {
      handoff = expectSuccess(await request('/api/handoffs', { method: 'POST', token: people.A.token, expectedStatus: 201, body: base(people.B.userId) }), 'create populated handoff').handoff;
      const event = waitFor(clientB.socket, 'handoff_submitted', (payload) => payload?.handoffId === handoff._id);
      const submitted = expectSuccess(await request(`/api/handoffs/${handoff._id}/submit`, { method: 'POST', token: people.A.token }), 'submit handoff').handoff;
      await event;
      const [inbox, history] = await Promise.all([request('/api/handoffs?type=received', { token: people.B.token }), request(`/api/spaces/${space._id}/handoffs`, { token: people.B.token })]);
      const notification = await eventually('handoff recipient notification', () => notificationFor(people.B.userId, handoff._id));
      await request(`/api/handoffs/${handoff._id}`, { method: 'PUT', token: people.A.token, expectedStatus: 400, body: { shiftSummary: marker('forbidden-edit') } });
      await request(`/api/handoffs/${handoff._id}`, { method: 'DELETE', token: people.A.token, expectedStatus: 400 });
      assert(submitted.status === 'submitted' && expectSuccess(inbox, 'handoff inbox').handoffs.some((item) => item._id === handoff._id), 'Submitted handoff was absent from recipient inbox.');
      assert(expectSuccess(history, 'handoff history').handoffs.some((item) => item._id === handoff._id) && notification.type === 'handoff_received', 'Submitted handoff history or notification was missing.');
    });

    await scenario('handoffs-04', async () => {
      const event = waitFor(clientA.socket, 'handoff_acknowledged', (payload) => payload?.handoffId === handoff._id);
      const acknowledged = expectSuccess(await request(`/api/handoffs/${handoff._id}/acknowledge`, { method: 'POST', token: people.B.token, body: { note: marker('acknowledged') } }), 'acknowledge handoff').handoff;
      await event;
      const notification = await eventually('handoff sender acknowledgement notification', () => notificationFor(people.A.userId, handoff._id));
      await request(`/api/handoffs/${handoff._id}/acknowledge`, { method: 'POST', token: people.B.token, expectedStatus: 400, body: { note: marker('duplicate') } });
      assert(acknowledged.status === 'acknowledged' && acknowledged.acknowledgedAt && acknowledged.acknowledgementNote === marker('acknowledged') && notification.type === 'handoff_acknowledged', 'Acknowledgement did not persist expected state or notification.');
    });

    await scenario('handoffs-05', async () => {
      const noted = expectSuccess(await request(`/api/handoffs/${handoff._id}/notes`, { method: 'POST', token: people.B.token, body: { text: marker('write-back'), kind: 'note' } }), 'add write-back note').handoff;
      const reassigned = expectSuccess(await request(`/api/handoffs/${handoff._id}/reassign`, { method: 'POST', token: people.B.token, body: { toUserId: people.C.userId, note: marker('reassign') } }), 'reassign handoff').handoff;
      const stored = await handoffById(handoff._id);
      const acknowledged = expectSuccess(await request(`/api/handoffs/${handoff._id}/acknowledge`, { method: 'POST', token: people.C.token, body: { note: marker('new-assignee-ack') } }), 'acknowledge reassigned handoff').handoff;
      assert(noted.writeBackNotes.some((note) => note.text === marker('write-back')) && reassigned.toUserId._id === people.C.userId, 'Write-back or reassignment was not persisted.');
      assert(stored.assignmentHistory.length === 1 && stored.status === 'submitted' && stored.acknowledgedAt === null, 'Reassignment did not reset acknowledgement or record history.');
      assert(acknowledged.status === 'acknowledged' && String(acknowledged.toUserId) === people.C.userId, 'New assignee could not acknowledge the handoff.');
    });
  } finally {
    closeRealtime(clientA); closeRealtime(clientB); closeRealtime(clientC); await closeDatabase();
    const output = resolve(process.env.SANITY_OUTPUT_DIR || 'output'); await mkdir(output, { recursive: true });
    await writeFile(resolve(output, 'handoff-results.json'), `${JSON.stringify({ expected: 5, results }, null, 2)}\n`);
  }
  console.log('Handoff scenarios passed: 5/5.');
}
run().catch(async (error) => { console.error(error.stack || error.message); await closeDatabase(); process.exitCode = 1; });
