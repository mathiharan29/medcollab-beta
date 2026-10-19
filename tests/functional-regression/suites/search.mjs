import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';

async function createSpace(identity, request, name, withB = false) {
  const a = await identity('A');
  const b = withB ? await identity('B') : null;
  const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name, type: 'department' }, expectedStatus: 201 });
  if (b) await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
  return { a, b, space: created.data.space, channelId: created.data.channels.find((item) => item.name === 'general')._id };
}

const cases = [{
  id: 'FR-SRCH-01', module: 'SRCH',
  run: async ({ identity, request, db }) => {
    const { a, b, space, channelId } = await createSpace(identity, request, 'Synthetic Search Types', true);
    await request('/api/users/me', { method: 'PUT', token: b.token, body: { name: 'Dr Atlasprobe B' } });
    const channel = (await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: a.token, body: { name: 'atlasprobe-channel' }, expectedStatus: 201 })).data.channel;
    const message = (await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body: { content: { text: 'Atlasprobe message ab a+b' } }, expectedStatus: 201 })).data.message;
    const punctuationOther = (await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body: { content: { text: 'aaab unrelated literal' } }, expectedStatus: 201 })).data.message;
    const attachment = (await request(`/api/channels/${channelId}/messages`, { method: 'POST', token: a.token, body: { type: 'document', content: { mediaUrl: 'https://res.cloudinary.com/synthetic-test/atlasprobe.pdf', fileName: 'atlasprobe.pdf', mimeType: 'application/pdf' } }, expectedStatus: 201 })).data.message;
    const handoff = (await request('/api/handoffs', { method: 'POST', token: a.token, body: {
      spaceId: space._id, channelId, toUserId: b.userId, shiftDate: '2030-01-15T00:00:00.000Z', shiftType: 'night',
      shiftSummary: 'Atlasprobe handoff', patients: [{ bedNumber: 'S-07', ward: 'Synthetic ICU', clinicalAlias: 'Atlasprobe patient', diagnosis: 'Synthetic', status: 'monitoring' }],
    }, expectedStatus: 201 })).data.handoff;
    const arrays = ['messages', 'doctors', 'channels', 'attachments', 'handoffs'];
    const all = await request('/api/search?q=%20aTlAsPrObE%20&type=all', { token: a.token });
    assert.equal(all.data.query, 'aTlAsPrObE');
    assert.ok(all.data.messages.some((item) => item._id === message._id));
    assert.ok(all.data.doctors.some((item) => item._id === b.userId));
    assert.ok(all.data.channels.some((item) => item._id === channel._id));
    assert.ok(all.data.attachments.some((item) => item._id === attachment._id));
    assert.ok(all.data.handoffs.some((item) => item._id === handoff._id));
    for (const type of arrays) {
      const result = await request(`/api/search?q=atlasprobe&type=${type}`, { token: a.token });
      assert.ok(result.data[type].length > 0, `${type} query must return its matching resource`);
      assert.ok(arrays.filter((item) => item !== type).every((item) => result.data[item].length === 0), `${type} query must not populate unrelated categories`);
    }
    for (const query of ['', 'a']) await request(`/api/search?q=${query}`, { token: a.token, expectedStatus: 400 });
    const two = await request('/api/search?q=ab&type=messages', { token: a.token });
    assert.ok(two.data.messages.some((item) => item._id === message._id));
    const literal = await request('/api/search?q=a%2Bb&type=messages', { token: a.token });
    assert.deepEqual(literal.data.messages.map((item) => item._id), [message._id]);
    assert.ok(!literal.data.messages.some((item) => item._id === punctuationOther._id));
    const empty = await request('/api/search?q=zzzz-synthetic-no-match', { token: a.token });
    assert.ok(arrays.every((item) => empty.data[item].length === 0));
    await db(async (connection) => {
      assert.equal(await connection.collection('messages').countDocuments({ _id: { $in: [message, punctuationOther, attachment].map((item) => new connection.base.Types.ObjectId(item._id)) } }), 3);
      assert.equal(await connection.collection('handoffs').countDocuments({ _id: new connection.base.Types.ObjectId(handoff._id) }), 1);
    });
  },
}, {
  id: 'FR-SRCH-02', module: 'SRCH',
  prerequisiteSeed: '51 matching text roots and 51 matching document attachments inserted directly with deterministic timestamps, plus two records in an archivable channel',
  run: async ({ identity, request, db }) => {
    const { a, space, channelId } = await createSpace(identity, request, 'Synthetic Search Caps');
    const archived = (await request(`/api/spaces/${space._id}/channels`, { method: 'POST', token: a.token, body: { name: 'archived-search' }, expectedStatus: 201 })).data.channel;
    const messageIds = Array.from({ length: 51 }, (_, index) => `6ac8f700000000000000${(index + 1).toString(16).padStart(4, '0')}`);
    const attachmentIds = Array.from({ length: 51 }, (_, index) => `6ac8f710000000000000${(index + 1).toString(16).padStart(4, '0')}`);
    await db(async (connection) => {
      const objectId = (value) => new connection.base.Types.ObjectId(value);
      const base = (id, channel, index) => ({ _id: objectId(id), channelId: objectId(channel), spaceId: objectId(space._id), senderId: objectId(a.userId), threadId: null, isDeleted: false, deletedAt: null, priority: 'normal', createdAt: new Date(Date.UTC(2026, 0, 1) + index * 1000), updatedAt: new Date(Date.UTC(2026, 0, 1) + index * 1000) });
      const textRows = messageIds.map((id, index) => ({ ...base(id, channelId, index), type: 'text', content: { text: `syntheticbulk message ${index}` } }));
      const attachmentRows = attachmentIds.map((id, index) => ({ ...base(id, channelId, index), type: 'document', content: { text: null, fileName: `syntheticbulk-${index}.pdf`, mediaUrl: `https://res.cloudinary.com/synthetic-test/syntheticbulk-${index}.pdf`, mimeType: 'application/pdf' } }));
      const archivedRows = [
        { ...base('6ac8f7200000000000000001', archived._id, 100), type: 'text', content: { text: 'syntheticbulk archived message' } },
        { ...base('6ac8f7200000000000000002', archived._id, 101), type: 'document', content: { fileName: 'syntheticbulk-archived.pdf', mediaUrl: 'https://res.cloudinary.com/synthetic-test/archived.pdf', mimeType: 'application/pdf' } },
      ];
      assert.equal((await connection.collection('messages').insertMany([...textRows, ...attachmentRows, ...archivedRows])).insertedCount, 104);
    });
    const one = await request('/api/search?q=syntheticbulk&limit=1', { token: a.token });
    assert.deepEqual(one.data.messages.map((item) => item._id), ['6ac8f7200000000000000001']);
    assert.deepEqual(one.data.attachments.map((item) => item._id), ['6ac8f7200000000000000002']);
    await request(`/api/channels/${archived._id}`, { method: 'DELETE', token: a.token });
    const fifty = await request('/api/search?q=syntheticbulk&limit=50', { token: a.token });
    assert.equal(fifty.data.messages.length, 50);
    assert.equal(fifty.data.attachments.length, 50);
    assert.deepEqual(fifty.data.messages.map((item) => item._id), messageIds.slice(1).reverse());
    assert.deepEqual(fifty.data.attachments.map((item) => item._id), attachmentIds.slice(1).reverse());
    const capped = await request('/api/search?q=syntheticbulk&limit=51', { token: a.token });
    assert.equal(capped.data.messages.length, 50);
    assert.equal(capped.data.attachments.length, 50);
    const oneAfterArchive = await request('/api/search?q=syntheticbulk&limit=1', { token: a.token });
    assert.deepEqual(oneAfterArchive.data.messages.map((item) => item._id), [messageIds[50]]);
    assert.deepEqual(oneAfterArchive.data.attachments.map((item) => item._id), [attachmentIds[50]]);
    await db(async (connection) => {
      assert.equal(await connection.collection('messages').countDocuments({ channelId: new connection.base.Types.ObjectId(channelId) }), 102);
      assert.equal((await connection.collection('channels').findOne({ _id: new connection.base.Types.ObjectId(archived._id) })).isArchived, true);
    });
  },
}, {
  id: 'FR-SRCH-03', module: 'SRCH',
  run: async ({ identity, request, db }) => {
    const { a, b, space, channelId } = await createSpace(identity, request, 'Synthetic Patient Search', true);
    const handoff = (await request('/api/handoffs', { method: 'POST', token: a.token, body: {
      spaceId: space._id, channelId, toUserId: b.userId, shiftDate: '2030-01-15T00:00:00.000Z', shiftType: 'night', shiftSummary: 'Synthetic summarymarker handoff',
      patients: [{ bedNumber: 'S-07', ward: 'Synthetic wardmarker ICU', clinicalAlias: 'Synthetic aliasmarker', diagnosis: 'Synthetic diagnosismarker', notes: 'Synthetic notesmarker', status: 'monitoring' }],
    }, expectedStatus: 201 })).data.handoff;
    const expectedTitle = 'Synthetic wardmarker ICU · Bed S-07 · Synthetic aliasmarker';
    for (const query of ['aliasmarker', 'wardmarker', 'S-07', 'diagnosismarker', 'notesmarker']) {
      const found = await request(`/api/search?q=${encodeURIComponent(query)}&type=handoffs`, { token: a.token });
      assert.equal(found.data.handoffs.find((item) => item._id === handoff._id)?.title, expectedTitle, `Patient match ${query} must use patient-specific title`);
      assert.equal(found.data.handoffs.find((item) => item._id === handoff._id)?.shiftSummary, 'Synthetic summarymarker handoff');
    }
    const summary = await request('/api/search?q=summarymarker&type=handoffs', { token: a.token });
    assert.equal(summary.data.handoffs.find((item) => item._id === handoff._id)?.title, 'Synthetic summarymarker handoff');
    assert.equal(summary.data.handoffs.find((item) => item._id === handoff._id)?.spaceId, space._id);
    const detail = await request(`/api/handoffs/${handoff._id}`, { token: a.token });
    assert.equal(detail.data.handoff.patients[0].clinicalAlias, 'Synthetic aliasmarker');
    await db(async (connection) => {
      const stored = await connection.collection('handoffs').findOne({ _id: new connection.base.Types.ObjectId(handoff._id) });
      assert.equal(stored.patients[0].ward, 'Synthetic wardmarker ICU');
      assert.equal(stored.shiftSummary, 'Synthetic summarymarker handoff');
    });
  },
}];

for (const item of cases) await runModule(`search-${item.id.slice(-2).toLowerCase()}`, [item]);
