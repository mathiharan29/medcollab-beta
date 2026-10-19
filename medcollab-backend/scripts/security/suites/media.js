'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const BASE = 'http://127.0.0.1:5000';
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jWZkAAAAASUVORK5CYII=', 'base64');
const root = () => path.resolve('uploads');
function safeFile(id) { const p = path.resolve(root(), id); assert.ok(p.startsWith(root() + path.sep)); return p; }
function disk() {
  const walk = p => !fs.existsSync(p) ? [] : fs.readdirSync(p, { withFileTypes: true }).flatMap(d => d.isDirectory() ? walk(path.join(p, d.name)) : [path.relative(root(), path.join(p, d.name))]);
  return walk(root()).sort();
}
async function upload(c, actor, { context = 'message', mime = 'image/png', name = 'canary.png', bytes = png, field = 'file', missing = false, twice = false } = {}) {
  const before = disk();
  const form = new FormData(); form.set('context', context); form.set('userId', String(c.users.C._id));
  if (!missing) form.append(field, new Blob([bytes], { type: mime }), name);
  if (twice) form.append('file', new Blob([bytes], { type: mime }), name);
  const r = await fetch(BASE + '/api/media/upload', { method: 'POST', headers: actor === 'anonymous' ? {} : { Authorization: `Bearer ${c.tokens[actor]}` }, body: form, redirect: 'error', signal: AbortSignal.timeout(15000) });
  const data = await r.json();
  const added = disk().filter(p => !before.includes(p));
  for (const id of added) c.cleanup.push(() => { const p = safeFile(id); if (fs.existsSync(p)) fs.unlinkSync(p); });
  c.evidence.filesAdded = added.length;
  c.evidence.uploadStatus = r.status;
  if (r.status === 429) throw new Error('Upload limiter prevented test execution');
  return { status: r.status, data };
}
async function prepareUpload(c) {
  const r = await upload(c, 'A'); assert.equal(r.status, 200); c.media = r.data.data;
  assert.equal(c.media.storage, 'local'); assert.deepEqual(fs.readFileSync(safeFile(c.media.publicId)), png);
}
module.exports = ({ add, ids }) => {
  const reg = (name, actor, method, endpoint, statuses, body, extra = {}) => add(name, actor, method, endpoint, statuses, body, { module: 'Media', sources: ['src/features/media/media.routes.js', 'src/features/media/media.controller.js', 'src/utils/localMediaStorage.js'], context: 'Real local multipart upload and filesystem; no external media URL is fetched.', ...extra });
  for (const context of ['message', 'avatar', 'handoff', 'unknown']) reg('local upload context ' + context, 'A', 'POST', '/api/media/upload', [200], undefined, {
    run: c => upload(c, 'A', { context }), check: (b, c) => { const m = b.data; const folder = context === 'handoff' ? 'medcollab/handoffs/' : `medcollab/${context === 'avatar' ? 'avatars' : 'messages'}/${c.users.A._id}/`; return m.storage === 'local' && m.publicId.startsWith(folder) && fs.readFileSync(safeFile(m.publicId)).equals(png); },
  });
  for (const [name, actor, config, statuses] of [
    ['anonymous', 'anonymous', {}, [401]], ['missing file', 'B', { missing: true }, [400]],
    ['wrong field', 'B', { field: 'other' }, [400]], ['multiple files', 'B', { twice: true }, [400]],
    ['forbidden MIME', 'B', { mime: 'text/plain', name: 'canary.txt' }, [400]],
    ['octet forbidden suffix', 'B', { mime: 'application/octet-stream', name: 'canary.txt' }, [400]],
    ['oversized', 'B', { bytes: Buffer.alloc(25 * 1024 * 1024 + 1) }, [400]],
    ['empty bytes', 'B', { bytes: Buffer.alloc(0) }, [400]],
    ['inert MIME extension mismatch', 'B', { name: 'canary.html', bytes: Buffer.from('inert security canary') }, [400]],
  ]) reg('upload rejects ' + name, actor, 'POST', '/api/media/upload', statuses, undefined, { category: 'media-schema', run: c => upload(c, actor, config), check: (_, c) => c.evidence.filesAdded === 0 });
  for (const actor of ['A', 'B', 'C', 'anonymous']) reg('media deletion ownership ' + actor, actor, 'DELETE', c => '/api/media/' + encodeURIComponent(c.media.publicId), [actor === 'A' ? 200 : actor === 'anonymous' ? 401 : 403], undefined, {
    prepare: prepareUpload, check: (_, c) => fs.existsSync(safeFile(c.media.publicId)) === (actor !== 'A'),
  });
  reg('media deletion replay', 'A', 'DELETE', c => '/api/media/' + encodeURIComponent(c.media.publicId), [404], undefined, { prepare: async c => { await prepareUpload(c); assert.equal((await c.http('A', 'DELETE', '/api/media/' + encodeURIComponent(c.media.publicId))).status, 200); }, check: (_, c) => !fs.existsSync(safeFile(c.media.publicId)) });
  for (const double of [false, true]) reg('media canonical owner containment ' + (double ? 'double' : 'single'), 'A', 'DELETE', c => c.attackPath, [400, 403, 404], undefined, {
    prepare: async c => {
      await prepareUpload(c);
      const r = await upload(c, 'C'); assert.equal(r.status, 200); c.foreign = r.data.data.publicId;
      assert.ok(fs.readFileSync(safeFile(c.foreign)).equals(png));
      const attack = `medcollab/messages/${c.users.A._id}/../${c.users.C._id}/${path.posix.basename(c.foreign)}`;
      assert.equal(safeFile(attack), safeFile(c.foreign));
      c.attackPath = '/api/media/' + encodeURIComponent(double ? encodeURIComponent(attack) : attack);
    }, check: (_, c) => { c.evidence.foreignFileSurvived = fs.existsSync(safeFile(c.foreign)); return c.evidence.foreignFileSurvived; },
  });
  reg('anonymous static media and owner revocation', 'A', 'DELETE', c => '/api/media/' + encodeURIComponent(c.media.publicId), [200], undefined, {
    prepare: async c => { await prepareUpload(c); const url = new URL(c.media.url); assert.equal(url.origin, BASE); const r = await fetch(url, { redirect: 'error' }); assert.equal(r.status, 200); assert.deepEqual(Buffer.from(await r.arrayBuffer()), png); c.evidence.publicStaticControl = true; },
    check: async (_, c) => (await fetch(c.media.url, { redirect: 'error' })).status === 404 && !fs.existsSync(safeFile(c.media.publicId)),
  });
  for (const [label, url, status] of [
    ['trusted HTTPS', 'https://res.cloudinary.com/ci-only/image/upload/canary.png', 201],
    ['foreign host', 'https://example.invalid/canary.png', 400],
    ['host suffix lookalike', 'https://res.cloudinary.com.example.invalid/a.png', 400],
    ['invalid URL', 'not-a-url', 400], ['protocol relative', '//res.cloudinary.com/a.png', 400],
    ['FTP trusted host', 'ftp://res.cloudinary.com/a.png', 400], ['HTTP trusted host', 'http://res.cloudinary.com/a.png', 400],
  ]) reg('message media URL ' + label, 'A', 'POST', `/api/channels/${ids.channel}/messages`, [status], { type: 'image', content: { mediaUrl: url } }, { category: 'media-schema', check: status === 201 ? async (b, c) => (await c.models.Message.findById(b.data.message._id)).content.mediaUrl === url : undefined });
  reg('local upload to authorized message integration', 'A', 'POST', `/api/channels/${ids.channel}/messages`, [201], c => ({ type: 'image', content: { mediaUrl: c.media.url } }), { prepare: prepareUpload, check: async (b, c) => !!b.data?.message?._id && (await c.models.Message.findById(b.data.message._id)).content.mediaUrl === c.media.url });
  for (const channel of [ids.otherChannel, ids.dmOther]) reg('uploaded media does not grant foreign channel access ' + channel, 'A', 'POST', `/api/channels/${channel}/messages`, [403], c => ({ type: 'image', content: { mediaUrl: c.media.url } }), { module: 'Cross-module', prepare: prepareUpload, check: (_, c) => fs.readFileSync(safeFile(c.media.publicId)).equals(png) });
  for (const actor of ['A', 'B', 'C', 'anonymous']) reg('handoff attachment sender ownership ' + actor, actor, 'PUT', `/api/handoffs/${ids.handoff}`, [actor === 'A' ? 200 : actor === 'anonymous' ? 401 : 403], c => ({ patients: [{ bedNumber: 'CI', clinicalAlias: 'Synthetic', attachments: [{ url: c.media.url, fileName: 'canary.png', mimeType: 'image/png' }] }] }), {
    module: 'Cross-module', prepare: async c => { await prepareUpload(c); await c.models.Handoff.findByIdAndUpdate(ids.handoff, { status: 'draft', submittedAt: null }); },
    check: async (_, c) => { const d = await c.models.Handoff.findById(ids.handoff).lean(); return String(d.fromUserId) === String(c.users.A._id) && (actor === 'A' ? d.patients[0].attachments[0]?.url === c.media.url : !d.patients[0].attachments?.length) && fs.existsSync(safeFile(c.media.publicId)); },
  });
  const pdf = Buffer.from('%PDF-1.1\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Count 0 /Kids [] >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF');
  for (const mime of ['application/pdf', 'application/octet-stream']) reg('local PDF bytes retained ' + mime, 'C', 'POST', '/api/media/upload', [200], undefined, {
    run: c => upload(c, 'C', { mime, name: 'canary.pdf', bytes: pdf }), check: (b, c) => b.data?.publicId?.startsWith(`medcollab/messages/${c.users.C._id}/`) && fs.readFileSync(safeFile(b.data.publicId)).equals(pdf),
  });
};
