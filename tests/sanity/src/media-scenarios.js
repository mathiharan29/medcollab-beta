import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createFixtureUsers } from './fixtures.js';
import { closeDatabase, connectDatabase } from './database.js';
import { download, expectSuccess, request } from './http.js';

const results = [];
const assert = (value, message) => { if (!value) throw new Error(message); };
const bytes = (values) => new Uint8Array(values);
async function scenario(id, action) {
  const startedAt = Date.now();
  try { await action(); results.push({ id, status: 'passed', durationMs: Date.now() - startedAt }); }
  catch (error) { results.push({ id, status: 'failed', durationMs: Date.now() - startedAt, error: error.message }); throw error; }
}
async function upload(token, name, mimeType, value, context = 'message') {
  const formData = new FormData();
  formData.set('context', context);
  formData.set('file', new File([value], name, { type: mimeType }));
  return expectSuccess(await request('/api/media/upload', { method: 'POST', token, formData }), `upload ${name}`);
}
function localPath(url) {
  const parsed = new URL(url);
  if (parsed.origin !== 'http://127.0.0.1:5000') throw new Error(`Upload returned non-local URL: ${url}`);
  return `${parsed.pathname}${parsed.search}`;
}

async function run() {
  await connectDatabase();
  const people = await createFixtureUsers();
  let space; let channel;
  try {
    const created = expectSuccess(await request('/api/spaces', { method: 'POST', token: people.A.token, expectedStatus: 201, body: { name: 'Sanity Media Space', type: 'department', description: 'Media fixture' } }), 'create media space');
    space = created.space; channel = created.channels.find((item) => item.name === 'general');
    await request('/api/spaces/join', { method: 'POST', token: people.B.token, body: { inviteCode: space.inviteCode } });

    await scenario('media-01', async () => {
      const png = bytes([137, 80, 78, 71, 13, 10, 26, 10, 0, 1, 2, 3]);
      const uploaded = await upload(people.A.token, 'sanity.png', 'image/png', png);
      const downloaded = await download(localPath(uploaded.url), people.A.token);
      assert(uploaded.storage === 'local' && downloaded.length === png.length && downloaded.every((value, index) => value === png[index]), 'PNG upload/download bytes were not exact.');
      await request(`/api/media/${encodeURIComponent(uploaded.publicId)}`, { method: 'DELETE', token: people.A.token });
      await request(localPath(uploaded.url), { token: people.A.token, expectedStatus: 404 });
    });

    await scenario('media-02', async () => {
      const pdf = bytes([37, 80, 68, 70, 45, 49, 46, 52, 10, 37, 0, 1, 2]);
      const uploaded = await upload(people.A.token, 'sanity.pdf', 'application/pdf', pdf, 'message');
      const downloaded = await download(localPath(uploaded.url), people.A.token);
      const handoff = expectSuccess(await request('/api/handoffs', { method: 'POST', token: people.A.token, expectedStatus: 201, body: {
        spaceId: space._id, channelId: channel._id, toUserId: people.B.userId, shiftDate: '2030-01-15T00:00:00.000Z', shiftType: 'night', shiftSummary: 'media attachment fixture',
        patients: [{ bedNumber: 'M-01', clinicalAlias: 'Synthetic media patient', attachments: [{ url: uploaded.url, thumbnailUrl: uploaded.thumbnailUrl, fileName: uploaded.fileName, mimeType: uploaded.mimeType }] }],
      } }), 'create PDF handoff').handoff;
      const detail = expectSuccess(await request(`/api/handoffs/${handoff._id}`, { token: people.A.token }), 'read PDF handoff').handoff;
      assert(downloaded.length === pdf.length && downloaded.every((value, index) => value === pdf[index]), 'PDF upload/download bytes were not exact.');
      assert(detail.patients[0].attachments[0].fileName === 'sanity.pdf' && detail.patients[0].attachments[0].mimeType === 'application/pdf', 'PDF attachment metadata was not persisted in handoff.');
    });

    await scenario('media-03', async () => {
      const media = [
        ['image', 'https://res.cloudinary.com/sanity/image/upload/sanity-image.png', 'sanity-image.png', 'image/png'],
        ['ecg', 'https://res.cloudinary.com/sanity/image/upload/sanity-ecg.png', 'sanity-ecg.png', 'image/png'],
        ['document', 'https://res.cloudinary.com/sanity/raw/upload/sanity-document.pdf', 'sanity-document.pdf', 'application/pdf'],
      ];
      const sent = [];
      for (const [type, mediaUrl, fileName, mimeType] of media) {
        sent.push(expectSuccess(await request(`/api/channels/${channel._id}/messages`, { method: 'POST', token: people.A.token, expectedStatus: 201, body: { type, content: { mediaUrl, fileName, mimeType, fileSize: 42 } } }), `send inert ${type}`).message);
      }
      const messages = expectSuccess(await request(`/api/channels/${channel._id}/messages?limit=20`, { token: people.B.token }), 'read media messages').messages;
      for (const message of sent) {
        const persisted = messages.find((item) => item._id === message._id);
        assert(persisted?.content?.mediaUrl === message.content.mediaUrl && persisted.content.fileName === message.content.fileName, `Media metadata did not persist for ${message.type}.`);
      }
      const detail = expectSuccess(await request(`/api/channels/${channel._id}`, { token: people.A.token }), 'read media sidebar preview').channel;
      assert(detail.lastMessage?.text === '📎 Document', 'Document message did not produce the expected sidebar preview.');
    });
  } finally {
    await closeDatabase();
    const output = resolve(process.env.SANITY_OUTPUT_DIR || 'output'); await mkdir(output, { recursive: true });
    await writeFile(resolve(output, 'media-results.json'), `${JSON.stringify({ expected: 3, results }, null, 2)}\n`);
  }
  console.log('Media scenarios passed: 3/3.');
}
run().catch(async (error) => { console.error(error.stack || error.message); await closeDatabase(); process.exitCode = 1; });
