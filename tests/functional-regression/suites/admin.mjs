import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';

const overview = '/api/admin/overview';
const feedback = '/api/admin/support';

const cases = [{
  id: 'FR-ADM-01', module: 'ADM',
  run: async ({ identity, request, db, restartBackend }) => {
    const admin = await identity('A');
    const doctor = await identity('B');
    await request('/api/spaces', {
      method: 'POST', token: doctor.token, expectedStatus: 201,
      body: { name: 'Synthetic space owned by B', type: 'department' },
    });
    await restartBackend({ ADMIN_USER_IDS: admin.userId });
    await request(overview, { expectedStatus: 401 });
    await request(overview, { token: doctor.token, expectedStatus: 403 });

    const before = (await request(overview, { token: admin.token })).data;
    await db(async (connection) => {
      // Seed legacy and current rows to exercise the real aggregation filters.
      // Audio content is unused by these counts, so no media provider is needed.
      const deletedAt = new Date('2026-11-10T12:00:00Z');
      await connection.collection('messages').insertMany([
        { type: 'text' }, { type: 'video' }, { type: 'audio' },
        { type: 'system' }, { type: 'audio', deletedAt }, { type: 'video', deletedAt },
      ]);
      const voiceNote = { url: 'https://res.cloudinary.com/synthetic/video/upload/voice.wav', durationMs: 1000 };
      await connection.collection('handoffs').insertMany([
        { status: 'draft', voiceNote },
        { status: 'submitted', voiceNote, writeBackNotes: [{ text: 'Synthetic note' }] },
        { status: 'acknowledged', voiceNote: null },
        { status: 'submitted' },
      ]);
    });

    const after = (await request(overview, { token: admin.token })).data;
    assert.deepEqual(after.messages, {
      total: before.messages.total + 3,
      videos: before.messages.videos + 1,
      voiceNotes: before.messages.voiceNotes + 1,
    });
    assert.deepEqual(after.handoffs, {
      total: before.handoffs.total + 3,
      acknowledged: before.handoffs.acknowledged + 1,
      ackRatePercent: Math.round(100 * (before.handoffs.acknowledged + 1) / (before.handoffs.total + 3)),
      withWriteBack: before.handoffs.withWriteBack + 1,
      withVoiceNote: before.handoffs.withVoiceNote + 1,
    });
  },
}, {
  id: 'FR-ADM-02', module: 'ADM',
  run: async ({ identity, request, db, restartBackend }) => {
    const admin = await identity('A');
    const doctor = await identity('B');
    const colleague = await identity('C');
    await restartBackend({ ADMIN_USER_IDS: admin.userId });
    const before = (await request(overview, { token: admin.token })).data;

    await db(async (connection) => {
      const ids = [admin, doctor, colleague].map(({ userId }) => new connection.base.Types.ObjectId(userId));
      await connection.collection('channels').insertMany([
        { name: 'Self notes', type: 'direct', members: ids.slice(0, 1) },
        { name: 'DM', type: 'direct', members: ids.slice(0, 2) },
        { name: 'Needl', type: 'direct', members: ids },
        { name: 'Archived Needl', type: 'direct', members: ids, isArchived: true },
      ]);
      await connection.collection('users').updateOne({ _id: ids[0] }, { $set: { 'availability.status': 'on_call' } });
      await connection.collection('users').updateOne({ _id: ids[2] }, { $set: { isActive: false, 'availability.status': 'on_call' } });
    });

    const ticket = (await request('/api/support/feedback', {
      method: 'POST', token: doctor.token, expectedStatus: 201,
      body: { title: 'Synthetic ops feedback', description: 'Synthetic notes for ops review' },
    })).data;
    await request(feedback, { token: doctor.token, expectedStatus: 403 });
    const { tickets } = (await request(feedback, { token: admin.token })).data;
    const listed = tickets.find((item) => item.id === ticket.ticketId);
    assert.equal(listed?.type, 'feedback');
    assert.equal(listed.title, 'Synthetic ops feedback');
    assert.equal(listed.description, 'Synthetic notes for ops review');
    assert.equal(listed.status, 'open');

    const after = (await request(overview, { token: admin.token })).data;
    assert.deepEqual(after.conversations, {
      selfNotes: before.conversations.selfNotes + 1,
      dms: before.conversations.dms + 1,
      needls: before.conversations.needls + 1,
    });
    assert.equal(after.availability.on_call, (before.availability.on_call ?? 0) + 1);
    assert.equal(after.support.openTickets, before.support.openTickets + 1);
  },
}];

await runModule('admin', cases);
