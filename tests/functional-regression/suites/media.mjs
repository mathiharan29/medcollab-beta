import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { runModule } from '../src/module-runner.mjs';
import { DecisionPending } from '../src/runner.mjs';

const png = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10, 0, 1, 2, 3]);
const pdf = Buffer.from('%PDF-1.4\n% Synthetic document\n');
const mp4 = Buffer.from([0, 0, 0, 24, 102, 116, 121, 112, 105, 115, 111, 109, 0, 0, 0, 1]);

async function upload(request, token, name, mimeType, bytes, context = 'message', expectedStatus = 200, timeoutMs = 10000) {
  const formData = new FormData();
  formData.set('context', context);
  if (bytes !== null) formData.set('file', new Blob([bytes], { type: mimeType }), name);
  return request('/api/media/upload', { method: 'POST', token, formData, expectedStatus, timeoutMs });
}

async function download(url, origin, token, expectedStatus = 200) {
  const parsed = new URL(url);
  assert.equal(parsed.origin, origin, 'Media URL must remain on disposable loopback backend');
  const response = await fetch(parsed, { headers: { Authorization: `Bearer ${token}` }, signal: AbortSignal.timeout(20000) });
  assert.equal(response.status, expectedStatus);
  return Buffer.from(await response.arrayBuffer());
}

async function fixture(identity, request) {
  const a = await identity('A'), b = await identity('B');
  const created = await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Media Space', type: 'department' }, expectedStatus: 201 });
  await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: created.data.space.inviteCode } });
  return { a, b, spaceId: created.data.space._id, channelId: created.data.channels.find((item) => item.name === 'general')._id };
}

const cases = [{
  id: 'FR-MED-01', module: 'MED', timeoutMs: 90000,
  run: async ({ identity, request, origin }) => {
    const a = await identity('A');
    await upload(request, a.token, 'missing', 'application/octet-stream', null, 'message', 400);
    for (const [name, mime, bytes] of [['synthetic.png', 'image/png', png], ['synthetic.pdf', 'application/pdf', pdf], ['synthetic.mp4', 'video/mp4', mp4]]) {
      const item = (await upload(request, a.token, name, mime, bytes)).data;
      assert.equal(item.fileName, name);
      assert.equal(item.fileSize, bytes.length);
      assert.equal(item.mimeType, mime);
      assert.equal(item.storage, 'local');
      assert.deepEqual(await download(item.url, origin, a.token), bytes);
    }
    const exactly25MiB = Buffer.alloc(25 * 1024 * 1024, 0x41);
    const at25 = (await upload(request, a.token, 'at25.pdf', 'application/pdf', exactly25MiB, 'message', 200, 30000)).data;
    assert.equal(at25.fileSize, exactly25MiB.length);
    const above25MiB = Buffer.alloc(25 * 1024 * 1024 + 1, 0x42);
    const above25 = (await upload(request, a.token, 'above25.pdf', 'application/pdf', above25MiB, 'message', 200, 30000)).data;
    assert.equal(above25.fileSize, above25MiB.length);
    // The pinned source declares MEDIA.MAX_FILE_SIZE_BYTES = 50 MiB, whereas the catalog's input table names 25 MiB.
    const above50MiB = Buffer.alloc(50 * 1024 * 1024 + 1, 0x43);
    const rejectedSize = await upload(request, a.token, 'above50.pdf', 'application/pdf', above50MiB, 'message', 400, 30000);
    assert.equal(rejectedSize.payload.success, false);
    const unsupportedStatuses = [];
    for (const [name, mime] of [['synthetic.txt', 'text/plain'], ['synthetic.doc', 'application/msword']]) {
      let rejected;
      try { rejected = await upload(request, a.token, name, mime, Buffer.from('Synthetic unsupported file'), 'message', 400); }
      catch (error) { if (error.detail?.status !== 500) throw error; rejected = { status: 500, payload: error.detail.payload }; }
      assert.equal(rejected.payload.success, false);
      unsupportedStatuses.push(rejected.status);
    }
    assert.deepEqual(unsupportedStatuses, [400, 400], 'Unsupported files must be client errors, not HTTP 500');
  },
}, {
  id: 'FR-MED-02', module: 'MED',
  run: async ({ identity, request, origin }) => {
    const a = await identity('A');
    const observations = [];
    for (const [name, bytes, format] of [['synthetic-octet.pdf', pdf, 'pdf'], ['synthetic-octet.mp4', mp4, 'video']]) {
      const uploaded = (await upload(request, a.token, name, 'application/octet-stream', bytes)).data;
      assert.equal(uploaded.storage, 'local');
      assert.equal(uploaded.format, format);
      assert.equal(uploaded.mimeType, 'application/octet-stream');
      assert.deepEqual(await download(uploaded.url, origin, a.token), bytes);
      observations.push(`${name}:${uploaded.format}/${uploaded.mimeType}`);
    }
    throw new DecisionPending(`Q5: octet-stream upload format/MIME contract pending; ${observations.join(', ')}`, ['Extension fallback accepted PDF and MP4', 'Returned format and MIME captured', 'Local delivered bytes exact']);
  },
}, {
  id: 'FR-MED-03', module: 'MED',
  run: async ({ identity, request, db, origin }) => {
    const f = await fixture(identity, request);
    const uploaded = (await upload(request, f.a.token, 'synthetic-message.png', 'image/png', png)).data;
    assert.deepEqual(await download(uploaded.url, origin, f.a.token), png);
    const rejected = await request(`/api/channels/${f.channelId}/messages`, { method: 'POST', token: f.a.token, body: { type: 'image', content: { mediaUrl: uploaded.url, fileName: uploaded.fileName, mimeType: uploaded.mimeType, fileSize: uploaded.fileSize } }, expectedStatus: 400 });
    assert.equal(rejected.payload.success, false);
    await db(async (connection) => assert.equal(await connection.collection('messages').countDocuments({ channelId: new connection.base.Types.ObjectId(f.channelId) }), 0));
    throw new DecisionPending('Q5: local upload URL is rejected by image-message policy; full upload→message pipeline has no successful local path', ['Upload bytes and metadata verified', 'Actual returned URL rejected by message route', 'No message persisted']);
  },
}, {
  id: 'FR-MED-04', module: 'MED',
  run: async ({ identity, request, db }) => {
    const f = await fixture(identity, request);
    const uploaded = (await upload(request, f.a.token, 'synthetic-video.mp4', 'video/mp4', mp4)).data;
    assert.equal(uploaded.format, 'video');
    const rejected = await request(`/api/channels/${f.channelId}/messages`, { method: 'POST', token: f.a.token, body: { type: 'video', content: { mediaUrl: uploaded.url, fileName: uploaded.fileName, mimeType: uploaded.mimeType, fileSize: uploaded.fileSize } }, expectedStatus: 400 });
    assert.equal(rejected.payload.success, false);
    await db(async (connection) => assert.equal(await connection.collection('messages').countDocuments({ channelId: new connection.base.Types.ObjectId(f.channelId) }), 0));
    throw new DecisionPending('Q5: video upload succeeds, but video message type is rejected by the pinned source', ['Video upload format verified', 'Actual send rejected', 'No message persisted']);
  },
}, {
  id: 'FR-MED-05', module: 'MED', fakeCloudinary: true,
  run: async ({ identity, request, db, inbox }) => {
    const a = await identity('A');
    const modePath = join(inbox, 'cloudinary-mode.json');
    try {
      await writeFile(modePath, JSON.stringify({ enabled: true, outcome: 'success' }));
      const cases = [
        ['synthetic-image.png', 'image/png', png, 'message', 'image', `medcollab/messages/${a.userId}`],
        ['synthetic-report.pdf', 'application/pdf', pdf, 'handoff', 'raw', 'medcollab/handoffs'],
        ['synthetic-video.mp4', 'video/mp4', mp4, 'avatar', 'video', `medcollab/avatars/${a.userId}`],
      ];
      for (const [name, mime, bytes, context, resourceType, folder] of cases) {
        const uploaded = (await upload(request, a.token, name, mime, bytes, context)).data;
        assert.equal(uploaded.storage, 'cloudinary');
        assert.equal(uploaded.fileName, name);
        assert.equal(uploaded.fileSize, bytes.length);
        assert.equal(uploaded.mimeType, mime);
        assert.equal(uploaded.publicId, `${folder}/${name.replace(/\.[^.]+$/, '')}`);
        assert.ok(uploaded.url.startsWith('https://res.cloudinary.com/synthetic/'));
        assert.equal(uploaded.thumbnailUrl === null, resourceType === 'raw');
      }
      const captures = (await readFile(join(inbox, 'cloudinary-capture.ndjson'), 'utf8')).trim().split(/\r?\n/).map(JSON.parse);
      assert.equal(captures.length, 3);
      for (let index = 0; index < captures.length; index++) {
        assert.equal(captures[index].options.resource_type, cases[index][4]);
        assert.equal(captures[index].options.folder, cases[index][5]);
        assert.equal(captures[index].size, cases[index][2].length);
        assert.equal(captures[index].firstBytes, cases[index][2].subarray(0, 16).toString('hex'));
      }
      await writeFile(modePath, JSON.stringify({ enabled: true, outcome: 'fail' }));
      const failed = await upload(request, a.token, 'synthetic-fail.png', 'image/png', png, 'message', 500);
      assert.equal(failed.payload.success, false);
      await db(async (connection) => assert.equal(await connection.collection('messages').countDocuments({}), 0));
    } finally { await writeFile(modePath, JSON.stringify({ enabled: false })); }
  },
}, {
  id: 'FR-MED-06', module: 'MED',
  run: async ({ identity, request, origin }) => {
    const a = await identity('A');
    const first = (await upload(request, a.token, 'synthetic-avatar-a.png', 'image/png', png, 'avatar')).data;
    const replacementBytes = Buffer.from([...png, 9, 8, 7]);
    const second = (await upload(request, a.token, 'synthetic-avatar-b.png', 'image/png', replacementBytes, 'avatar')).data;
    assert.deepEqual(await download(first.url, origin, a.token), png);
    await request('/api/users/me', { method: 'PUT', token: a.token, body: { avatarUrl: first.url } });
    const updated = await request('/api/users/me', { method: 'PUT', token: a.token, body: { avatarUrl: second.url } });
    assert.equal(updated.data.user.avatarUrl, second.url);
    await request(`/api/media/${encodeURIComponent(first.publicId)}`, { method: 'DELETE', token: a.token });
    await download(first.url, origin, a.token, 404);
    assert.deepEqual(await download(second.url, origin, a.token), replacementBytes);
    const profile = (await request('/api/users/me', { token: a.token })).data.user;
    assert.equal(profile.avatarUrl, second.url);
    throw new DecisionPending('Q6: profile points to replacement avatar; old file was deleted explicitly, automatic old-file lifecycle remains undecided', ['Profile references B after reload', 'A deletion and B bytes verified']);
  },
}, {
  id: 'FR-MED-07', module: 'MED',
  run: async ({ identity, request, origin, db }) => {
    const f = await fixture(identity, request);
    const image = (await upload(request, f.a.token, 'synthetic-reference.png', 'image/png', png)).data;
    const video = (await upload(request, f.a.token, 'synthetic-reference.mp4', 'video/mp4', mp4)).data;
    const handoffFile = (await upload(request, f.a.token, 'synthetic-handoff.pdf', 'application/pdf', pdf, 'handoff')).data;
    const handoff = (await request('/api/handoffs', { method: 'POST', token: f.a.token, body: { spaceId: f.spaceId, channelId: f.channelId, toUserId: f.b.userId, shiftDate: '2030-01-15T00:00:00.000Z', shiftType: 'night', patients: [{ bedNumber: 'M-01', clinicalAlias: 'Synthetic media patient', attachments: [{ url: image.url, fileName: image.fileName, mimeType: image.mimeType }, { url: handoffFile.url, fileName: handoffFile.fileName, mimeType: handoffFile.mimeType }] }] }, expectedStatus: 201 })).data.handoff;
    await request(`/api/media/${encodeURIComponent(image.publicId)}`, { method: 'DELETE', token: f.a.token });
    await request(`/api/media/${encodeURIComponent(video.publicId)}`, { method: 'DELETE', token: f.a.token });
    await download(image.url, origin, f.a.token, 404);
    await download(video.url, origin, f.a.token, 404);
    await request(`/api/media/${encodeURIComponent(handoffFile.publicId)}`, { method: 'DELETE', token: f.a.token, expectedStatus: 403 });
    assert.deepEqual(await download(handoffFile.url, origin, f.a.token), pdf);
    const detail = (await request(`/api/handoffs/${handoff._id}`, { token: f.a.token })).data.handoff;
    assert.deepEqual(detail.patients[0].attachments.map((item) => item.url), [image.url, handoffFile.url]);
    const row = await db((connection) => connection.collection('handoffs').findOne({ _id: new connection.base.Types.ObjectId(handoff._id) }));
    assert.equal(row.patients[0].attachments[0].url, image.url);
    throw new DecisionPending('Q6: referenced local image/video bytes delete, handoff-context deletion is unsupported, and handoff attachment references remain', ['Supported local file bytes removed', 'Handoff-context delete refused', 'Consumer retains stale reference']);
  },
}];

const selected = process.env.VOCLE_CASE_IDS?.split(',').filter(Boolean);
await runModule('media', selected ? cases.filter((item) => selected.includes(item.id)) : cases);
