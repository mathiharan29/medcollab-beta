import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';
import { DecisionPending } from '../src/runner.mjs';

const shiftDate = '2030-01-15T00:00:00.000Z';
const attachment = { url: 'https://res.cloudinary.com/synthetic/image/upload/handoff.png', fileName: 'handoff.png', mimeType: 'image/png' };
const patient = (bedNumber, alias) => ({ bedNumber, ward: 'Synthetic ICU', clinicalAlias: alias, diagnosis: 'Synthetic condition', status: 'monitoring', notes: 'Synthetic observations', pendingTasks: ['Synthetic check'], isFlagged: true, attachments: [attachment] });

async function fixture(identity, request, name) {
  const a = await identity('A'), b = await identity('B'), c = await identity('C');
  const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name, type: 'department' }, expectedStatus: 201 });
  for (const person of [b, c]) await request('/api/spaces/join', { method: 'POST', token: person.token, body: { inviteCode: created.data.space.inviteCode } });
  return { a, b, c, spaceId: created.data.space._id, channelId: created.data.channels.find((item) => item.name === 'general')._id };
}

function body(f, patients = [patient('H-01', 'Synthetic alpha')]) {
  return { spaceId: f.spaceId, channelId: f.channelId, toUserId: f.b.userId, shiftDate, shiftType: 'night', shiftSummary: 'Synthetic shift summary', patients };
}

async function draft(f, request, patients) {
  return (await request('/api/handoffs', { method: 'POST', token: f.a.token, body: body(f, patients), expectedStatus: 201 })).data.handoff;
}

async function stored(db, id) {
  return db((connection) => connection.collection('handoffs').findOne({ _id: new connection.base.Types.ObjectId(id) }));
}

const cases = [{
  id: 'FR-HOF-01', module: 'HOF',
  run: async ({ identity, request, db }) => {
    const f = await fixture(identity, request, 'Synthetic Handoff Draft Editing');
    const created = await draft(f, request, [patient('H-01', 'Synthetic alpha'), patient('H-02', 'Synthetic beta')]);
    assert.equal(created.status, 'draft');
    assert.equal(created.patients.length, 2);
    const [alphaId, betaId] = created.patients.map((item) => item._id);
    const alpha = { ...created.patients[0], notes: 'Synthetic edited observations', pendingTasks: ['Synthetic ECG', 'Synthetic review'], isFlagged: false };
    const beta = { ...created.patients[1], bedNumber: 'H-03', clinicalAlias: 'Synthetic replacement' };
    const updated = (await request(`/api/handoffs/${created._id}`, { method: 'PUT', token: f.a.token, body: { patients: [alpha, beta], shiftSummary: 'Synthetic updated summary', shiftDate: '2030-01-16T00:00:00.000Z', shiftType: 'morning' } })).data.handoff;
    assert.deepEqual(updated.patients.map((item) => item._id), [alphaId, betaId]);
    assert.equal(updated.patients[0].notes, alpha.notes);
    const removed = (await request(`/api/handoffs/${created._id}`, { method: 'PUT', token: f.a.token, body: { patients: [alpha] } })).data.handoff;
    assert.deepEqual(removed.patients.map((item) => item._id), [alphaId]);
    const detail = (await request(`/api/handoffs/${created._id}`, { token: f.a.token })).data.handoff;
    assert.equal(detail.status, 'draft');
    assert.equal(detail.fromUserId._id, f.a.userId);
    assert.equal(detail.toUserId._id, f.b.userId);
    assert.equal(detail.shiftSummary, 'Synthetic updated summary');
    assert.equal(detail.shiftDate, '2030-01-16T00:00:00.000Z');
    assert.equal(detail.shiftType, 'morning');
    assert.deepEqual(detail.patients.map((item) => item._id), [alphaId]);
    assert.deepEqual(detail.patients[0].pendingTasks, alpha.pendingTasks);
    assert.equal(detail.patients[0].isFlagged, false);
    assert.equal(detail.patients[0].attachments[0].fileName, attachment.fileName);
    const row = await stored(db, created._id);
    assert.equal(row.patients.length, 1);
    assert.equal(String(row.patients[0]._id), alphaId);
    assert.equal(row.patients[0].notes, alpha.notes);
    assert.deepEqual(row.patients[0].pendingTasks, alpha.pendingTasks);
    assert.equal(row.patients[0].attachments[0].url, attachment.url);
  },
}, {
  id: 'FR-HOF-02', module: 'HOF',
  run: async ({ identity, request, db }) => {
    const f = await fixture(identity, request, 'Synthetic Handoff Boundaries');
    const valid = await draft(f, request, [{ ...patient('B'.repeat(20), 'A'.repeat(100)), notes: 'N'.repeat(2000) }]);
    assert.equal(valid.patients[0].bedNumber.length, 20);
    assert.equal(valid.patients[0].clinicalAlias.length, 100);
    assert.equal(valid.patients[0].notes.length, 2000);
    const summary = (await request(`/api/handoffs/${valid._id}`, { method: 'PUT', token: f.a.token, body: { shiftSummary: 'S'.repeat(2000) } })).data.handoff;
    assert.equal(summary.shiftSummary.length, 2000);
    for (const invalid of [
      { patients: [{ ...patient('', 'Synthetic alias') }] },
      { patients: [{ ...patient('H-01', '') }] },
      { patients: [{ ...patient('B'.repeat(21), 'Synthetic alias') }] },
      { patients: [{ ...patient('H-01', 'A'.repeat(101)) }] },
      { patients: [{ ...patient('H-01', 'Synthetic alias'), notes: 'N'.repeat(2001) }] },
      { shiftSummary: 'S'.repeat(2001) },
      { patients: [{ ...patient('H-01', 'Synthetic alias'), status: 'imaginary' }] },
      { shiftDate: 'not-a-date' },
      { shiftType: 'imaginary' },
    ]) {
      const rejected = await request(`/api/handoffs/${valid._id}`, { method: 'PUT', token: f.a.token, body: invalid, expectedStatus: 400 });
      assert.equal(rejected.payload.success, false);
      const current = (await request(`/api/handoffs/${valid._id}`, { token: f.a.token })).data.handoff;
      assert.equal(current.shiftSummary, summary.shiftSummary);
      assert.equal(current.patients[0].bedNumber.length, 20);
      assert.equal(current.patients[0].clinicalAlias.length, 100);
      assert.equal(current.patients[0].notes.length, 2000);
    }
    const row = await stored(db, valid._id);
    assert.equal(row.shiftSummary.length, 2000);
    assert.equal(row.patients[0].bedNumber.length, 20);
  },
}, {
  id: 'FR-HOF-03', module: 'HOF', timeoutMs: 30000,
  run: async ({ identity, request, db, origin }) => {
    const f = await fixture(identity, request, 'Synthetic Handoff Concurrent Transitions');
    const created = await draft(f, request);
    const socketB = await connectSocket(null, origin, f.b.token);
    const socketA = await connectSocket(null, origin, f.a.token);
    try {
      const submittedEvents = [], acknowledgedEvents = [];
      socketB.on('handoff_submitted', (event) => { if (event?.handoffId === created._id) submittedEvents.push(event); });
      socketA.on('handoff_acknowledged', (event) => { if (event?.handoffId === created._id) acknowledgedEvents.push(event); });
      const submission = waitFor(socketB, 'handoff_submitted', (event) => event?.handoffId === created._id);
      const submitResponses = await Promise.all([1, 2].map(async () => request(`/api/handoffs/${created._id}/submit`, { method: 'POST', token: f.a.token, expectedStatus: 200 }).catch((error) => error)));
      const submittedEvent = await submission;
      assert.equal(submittedEvent.status, 'submitted');
      assert.deepEqual(submitResponses.map((item) => item.status || item.detail?.status).sort(), [200, 400]);
      const submitted = await stored(db, created._id);
      assert.equal(submitted.status, 'submitted');
      assert.ok(submitted.submittedAt instanceof Date);
      assert.equal(submittedEvents.length, 1);
      const acknowledgement = waitFor(socketA, 'handoff_acknowledged', (event) => event?.handoffId === created._id);
      const ackResponses = await Promise.all([1, 2].map(async () => request(`/api/handoffs/${created._id}/acknowledge`, { method: 'POST', token: f.b.token, body: { note: 'Synthetic accepted' } }).catch((error) => error)));
      const acknowledgedEvent = await acknowledgement;
      assert.equal(acknowledgedEvent.status, 'acknowledged');
      assert.deepEqual(ackResponses.map((item) => item.status || item.detail?.status).sort(), [200, 400]);
      const final = await stored(db, created._id);
      assert.equal(final.status, 'acknowledged');
      assert.ok(final.acknowledgedAt instanceof Date);
      assert.equal(final.acknowledgementNote, 'Synthetic accepted');
      assert.equal(acknowledgedEvents.length, 1);
      const inboxB = await request('/api/notifications', { token: f.b.token });
      const inboxA = await request('/api/notifications', { token: f.a.token });
      assert.equal(inboxB.data.notifications.filter((item) => item.referenceId === created._id && item.type === 'handoff_received').length, 1);
      assert.equal(inboxA.data.notifications.filter((item) => item.referenceId === created._id && item.type === 'handoff_acknowledged').length, 1);
    } finally { socketB.disconnect(); socketA.disconnect(); }
  },
}, {
  id: 'FR-HOF-04', module: 'HOF',
  run: async ({ identity, request, db }) => {
    const f = await fixture(identity, request, 'Synthetic Handoff Invalid Lifecycle');
    const empty = await draft(f, request, []);
    const created = await draft(f, request);
    for (const [id, method, path, token, requestBody] of [
      [created._id, 'POST', 'acknowledge', f.b.token, { note: 'Too early' }],
      [created._id, 'POST', 'notes', f.a.token, { text: 'Too early' }],
      [created._id, 'POST', 'reassign', f.a.token, { toUserId: f.c.userId }],
      [empty._id, 'POST', 'submit', f.a.token, undefined],
    ]) await request(`/api/handoffs/${id}/${path}`, { method, token, body: requestBody, expectedStatus: 400 });
    assert.equal((await stored(db, created._id)).status, 'draft');
    assert.equal((await stored(db, empty._id)).status, 'draft');
    await request(`/api/handoffs/${created._id}/submit`, { method: 'POST', token: f.a.token });
    await request(`/api/handoffs/${created._id}`, { method: 'PUT', token: f.a.token, body: { patients: [] }, expectedStatus: 400 });
    await request(`/api/handoffs/${created._id}`, { method: 'DELETE', token: f.a.token, expectedStatus: 400 });
    const detail = (await request(`/api/handoffs/${created._id}`, { token: f.b.token })).data.handoff;
    assert.equal(detail.status, 'submitted');
    assert.equal(detail.patients.length, 1);
    assert.equal(detail.patients[0].clinicalAlias, 'Synthetic alpha');
    const row = await stored(db, created._id);
    assert.equal(row.status, 'submitted');
    assert.equal(row.patients.length, 1);
    assert.equal(row.writeBackNotes.length, 0);
    assert.equal(row.assignmentHistory.length, 0);
  },
}, {
  id: 'FR-HOF-05', module: 'HOF',
  run: async ({ identity, request, db }) => {
    const f = await fixture(identity, request, 'Synthetic Handoff Draft Audience');
    const d = await draft(f, request);
    const owner = (await request(`/api/handoffs/${d._id}`, { token: f.a.token })).data.handoff;
    assert.equal(owner.status, 'draft');
    assert.equal(owner.patients[0].clinicalAlias, 'Synthetic alpha');
    const received = await request('/api/handoffs?type=received&status=draft', { token: f.b.token });
    const receiverDetail = await request(`/api/handoffs/${d._id}`, { token: f.b.token, expectedStatus: 403 });
    const memberDetail = await request(`/api/handoffs/${d._id}`, { token: f.c.token, expectedStatus: 403 });
    const memberHistory = await request(`/api/spaces/${f.spaceId}/handoffs`, { token: f.c.token });
    const receiverSearch = await request('/api/search?q=Synthetic%20alpha', { token: f.b.token });
    assert.ok(!received.data.handoffs.some((item) => item._id === d._id));
    assert.ok(!memberHistory.data.handoffs.some((item) => item._id === d._id));
    assert.equal(receiverDetail.payload.success, false);
    assert.equal(memberDetail.payload.success, false);
    const row = await stored(db, d._id);
    assert.equal(row.status, 'draft');
    assert.equal(row.patients[0].clinicalAlias, 'Synthetic alpha');
    throw new DecisionPending(`Q3: draft audience policy pending; receiver search includes current draft ${Boolean(receiverSearch.data?.handoffs?.some((item) => item._id === d._id))}`, ['Owner draft detail and patient persisted', 'Receiver draft filter and detail excluded', 'Ordinary member detail/history excluded']);
  },
}, {
  id: 'FR-HOF-08', module: 'HOF',
  run: async ({ identity, request, db }) => {
    const f = await fixture(identity, request, 'Synthetic Handoff Notes');
    const d = await draft(f, request);
    await request(`/api/handoffs/${d._id}/submit`, { method: 'POST', token: f.a.token });
    const kinds = ['note', 'cant_cover', 'covered_late', 'reassign', 'missed'];
    for (const kind of kinds) {
      const text = kind === 'note' ? `  ${'N'.repeat(1000)}  ` : ` Synthetic ${kind} `;
      const saved = await request(`/api/handoffs/${d._id}/notes`, { method: 'POST', token: f.b.token, body: { text, kind } });
      const last = saved.data.handoff.writeBackNotes.at(-1);
      assert.equal(last.kind, kind);
      assert.equal(last.text, text.trim());
      assert.equal(last.authorId._id, f.b.userId);
      assert.ok(Date.parse(last.createdAt) > 0);
    }
    for (const text of ['', '   ', 'N'.repeat(1001)]) await request(`/api/handoffs/${d._id}/notes`, { method: 'POST', token: f.b.token, body: { text }, expectedStatus: 400 });
    const detail = (await request(`/api/handoffs/${d._id}`, { token: f.a.token })).data.handoff;
    assert.deepEqual(detail.writeBackNotes.map((item) => item.kind), kinds);
    assert.equal(detail.status, 'submitted');
    assert.equal(detail.patients[0].clinicalAlias, 'Synthetic alpha');
    const row = await stored(db, d._id);
    assert.equal(row.writeBackNotes.length, 5);
    assert.equal(row.status, 'submitted');
    assert.equal(row.patients.length, 1);
  },
}, {
  id: 'FR-HOF-06', module: 'HOF',
  run: async ({ identity, request, db }) => {
    const f = await fixture(identity, request, 'Synthetic Handoff Filters S');
    const second = await request('/api/spaces', { method: 'POST', token: f.a.token, body: { name: 'Synthetic Handoff Filters S2', type: 'department' }, expectedStatus: 201 });
    await request('/api/spaces/join', { method: 'POST', token: f.b.token, body: { inviteCode: second.data.space.inviteCode } });
    const s2 = { ...f, spaceId: second.data.space._id, channelId: second.data.channels.find((item) => item.name === 'general')._id };
    const d = await draft(f, request);
    const dayStart = await draft(f, request, [patient('H-02', 'Synthetic morning')]);
    const dayEnd = await draft(f, request, [patient('H-03', 'Synthetic end')]);
    const other = await draft(s2, request, [patient('H-04', 'Synthetic other space')]);
    await request(`/api/handoffs/${dayStart._id}`, { method: 'PUT', token: f.a.token, body: { shiftDate: '2030-01-16T00:00:00.000Z' } });
    await request(`/api/handoffs/${dayEnd._id}`, { method: 'PUT', token: f.a.token, body: { shiftDate: '2030-01-16T23:59:59.999Z' } });
    for (const id of [dayStart._id, dayEnd._id, other._id]) await request(`/api/handoffs/${id}/submit`, { method: 'POST', token: f.a.token });
    await request(`/api/handoffs/${dayEnd._id}/acknowledge`, { method: 'POST', token: f.b.token, body: {} });
    const ids = async (query, token) => (await request(`/api/handoffs?${query}`, { token })).data.handoffs.map((item) => item._id);
    assert.deepEqual(new Set(await ids('type=sent&status=draft&spaceId=' + f.spaceId, f.a.token)), new Set([d._id]));
    assert.deepEqual(new Set(await ids('type=received&status=submitted&spaceId=' + f.spaceId, f.b.token)), new Set([dayStart._id]));
    assert.deepEqual(new Set(await ids('type=received&status=acknowledged&spaceId=' + f.spaceId, f.b.token)), new Set([dayEnd._id]));
    assert.deepEqual(new Set(await ids('type=all&spaceId=' + f.spaceId, f.a.token)), new Set([d._id, dayStart._id, dayEnd._id]));
    assert.deepEqual(new Set(await ids('type=sent&spaceId=' + s2.spaceId, f.a.token)), new Set([other._id]));
    assert.deepEqual(new Set(await ids('type=received&date=2030-01-16&spaceId=' + f.spaceId, f.b.token)), new Set([dayStart._id, dayEnd._id]));
    assert.deepEqual(new Set(await ids('type=received&date=2030-01-15&spaceId=' + f.spaceId, f.b.token)), new Set());
    const populated = (await request('/api/handoffs?type=received&spaceId=' + f.spaceId, { token: f.b.token })).data.handoffs;
    assert.ok(populated.every((item) => item.fromUserId._id === f.a.userId && item.toUserId._id === f.b.userId));
    await db(async (connection) => {
      assert.equal(await connection.collection('handoffs').countDocuments({ spaceId: new connection.base.Types.ObjectId(f.spaceId) }), 3);
      assert.equal(await connection.collection('handoffs').countDocuments({ spaceId: new connection.base.Types.ObjectId(s2.spaceId) }), 1);
    });
  },
}, {
  id: 'FR-HOF-07', module: 'HOF',
  run: async ({ identity, request, db }) => {
    const f = await fixture(identity, request, 'Synthetic Handoff Cursor');
    const created = [];
    for (const alias of ['Synthetic first ID', 'Synthetic second ID', 'Synthetic third ID', 'Synthetic fourth ID']) {
      const d = await draft(f, request, [patient('H-01', alias)]);
      await request(`/api/handoffs/${d._id}/submit`, { method: 'POST', token: f.a.token });
      created.push(d._id);
    }
    const dates = ['2030-01-19', '2030-01-16', '2030-01-18', '2030-01-17'];
    await db(async (connection) => {
      for (let index = 0; index < created.length; index++) await connection.collection('handoffs').updateOne({ _id: new connection.base.Types.ObjectId(created[index]) }, { $set: { shiftDate: new Date(`${dates[index]}T00:00:00.000Z`) } });
      assert.equal(await connection.collection('handoffs').countDocuments({ spaceId: new connection.base.Types.ObjectId(f.spaceId) }), 4);
    });
    const ordered = [created[0], created[2], created[3], created[1]];
    const first = (await request(`/api/spaces/${f.spaceId}/handoffs?limit=2`, { token: f.b.token })).data;
    assert.deepEqual(first.handoffs.map((item) => item._id), ordered.slice(0, 2));
    assert.equal(first.hasMore, true);
    const second = (await request(`/api/spaces/${f.spaceId}/handoffs?limit=2&before=${first.handoffs.at(-1)._id}`, { token: f.b.token })).data;
    const observed = [...first.handoffs, ...second.handoffs].map((item) => item._id);
    assert.ok(observed.every((id) => created.includes(id)));
    throw new DecisionPending(`Q4: shiftDate sort with ID cursor; expected ${JSON.stringify(ordered)}, observed ${JSON.stringify(observed)}`, ['Four source handoffs persisted', 'First page follows shiftDate descending', 'Second page response captured']);
  },
}, {
  id: 'FR-HOF-09', module: 'HOF', timeoutMs: 30000,
  run: async ({ identity, request, db, origin }) => {
    const f = await fixture(identity, request, 'Synthetic Handoff Reassignment');
    const d = await draft(f, request);
    await request(`/api/handoffs/${d._id}/submit`, { method: 'POST', token: f.a.token });
    await request(`/api/handoffs/${d._id}/acknowledge`, { method: 'POST', token: f.b.token, body: { note: 'Synthetic first acknowledgement' } });
    const socket = await connectSocket(null, origin, f.c.token);
    const socketB = await connectSocket(null, origin, f.b.token);
    try {
      const firstEvent = waitFor(socket, 'handoff_reassigned', (event) => event?.handoffId === d._id && event?.toUserId === f.c.userId);
      const firstNotification = waitFor(socket, 'new_notification', (event) => event?.referenceId === d._id && event?.type === 'handoff_received');
      const first = (await request(`/api/handoffs/${d._id}/reassign`, { method: 'POST', token: f.b.token, body: { toUserId: f.c.userId, note: 'Synthetic B to C' } })).data.handoff;
      assert.equal((await firstEvent).previousToUserId, f.b.userId);
      assert.equal((await firstNotification).referenceId, d._id);
      assert.equal(first.status, 'submitted');
      assert.equal(first.toUserId._id, f.c.userId);
      assert.equal(first.acknowledgedAt, null);
      assert.equal(first.patients[0].clinicalAlias, 'Synthetic alpha');
      await request(`/api/handoffs/${d._id}/acknowledge`, { method: 'POST', token: f.c.token, body: { note: 'Synthetic C acknowledgement' } });
      const secondEvent = waitFor(socket, 'handoff_reassigned', (event) => event?.handoffId === d._id && event?.toUserId === f.b.userId);
      const secondNotification = waitFor(socketB, 'new_notification', (event) => event?.referenceId === d._id && event?.type === 'handoff_received');
      const second = (await request(`/api/handoffs/${d._id}/reassign`, { method: 'POST', token: f.c.token, body: { toUserId: f.b.userId, note: 'Synthetic C to B' } })).data.handoff;
      assert.equal((await secondEvent).previousToUserId, f.c.userId);
      assert.equal((await secondNotification).referenceId, d._id);
      assert.equal(second.status, 'submitted');
      assert.equal(second.toUserId._id, f.b.userId);
      assert.equal(second.acknowledgedAt, null);
      assert.deepEqual(second.assignmentHistory.map((item) => [item.fromUserId, item.toUserId].map((value) => typeof value === 'string' ? value : value?._id)), [[f.b.userId, f.c.userId], [f.c.userId, f.b.userId]]);
      const row = await stored(db, d._id);
      assert.equal(row.assignmentHistory.length, 2);
      assert.deepEqual(row.assignmentHistory.map((item) => [String(item.fromUserId), String(item.toUserId)]), [[f.b.userId, f.c.userId], [f.c.userId, f.b.userId]]);
      assert.equal(row.patients[0].clinicalAlias, 'Synthetic alpha');
      assert.equal(row.acknowledgementNote, '');
      const receivedB = (await request('/api/handoffs?type=received', { token: f.b.token })).data.handoffs;
      const receivedC = (await request('/api/handoffs?type=received', { token: f.c.token })).data.handoffs;
      assert.ok(receivedB.some((item) => item._id === d._id));
      assert.ok(!receivedC.some((item) => item._id === d._id));
      const inboxB = (await request('/api/notifications', { token: f.b.token })).data.notifications;
      const inboxC = (await request('/api/notifications', { token: f.c.token })).data.notifications;
      assert.ok(inboxB.some((item) => item.referenceId === d._id && item.type === 'handoff_received'));
      assert.ok(inboxC.some((item) => item.referenceId === d._id && item.type === 'handoff_received'));
    } finally { socket.disconnect(); socketB.disconnect(); }
  },
}, {
  id: 'FR-HOF-10', module: 'HOF',
  run: async ({ identity, request, db }) => {
    const f = await fixture(identity, request, 'Synthetic Handoff Invalid Reassignment');
    const outsider = await identity('D');
    const d = await draft(f, request);
    await request(`/api/handoffs/${d._id}/reassign`, { method: 'POST', token: f.a.token, body: { toUserId: f.c.userId }, expectedStatus: 400 });
    await request(`/api/handoffs/${d._id}/submit`, { method: 'POST', token: f.a.token });
    await request(`/api/handoffs/${d._id}/acknowledge`, { method: 'POST', token: f.b.token, body: { note: 'Synthetic acknowledged' } });
    const before = await stored(db, d._id);
    for (const toUserId of [f.b.userId, outsider.userId]) await request(`/api/handoffs/${d._id}/reassign`, { method: 'POST', token: f.b.token, body: { toUserId }, expectedStatus: 400 });
    const atLimit = await request(`/api/handoffs/${d._id}/notes`, { method: 'POST', token: f.b.token, body: { text: 'N'.repeat(1000), kind: 'note' } });
    assert.equal(atLimit.data.handoff.writeBackNotes.at(-1).text.length, 1000);
    await request(`/api/handoffs/${d._id}/notes`, { method: 'POST', token: f.b.token, body: { text: 'N'.repeat(1001) }, expectedStatus: 400 });
    const after = await stored(db, d._id);
    assert.equal(after.status, 'acknowledged');
    assert.equal(String(after.toUserId), f.b.userId);
    assert.equal(after.acknowledgedAt.getTime(), before.acknowledgedAt.getTime());
    assert.equal(after.assignmentHistory.length, 0);
    assert.equal(after.writeBackNotes.length, 1);
  },
}];

const selected = process.env.VOCLE_CASE_IDS?.split(',').filter(Boolean);
const ordered = cases.sort((left, right) => left.id.localeCompare(right.id));
await runModule('handoffs', selected ? ordered.filter((item) => selected.includes(item.id)) : ordered);
