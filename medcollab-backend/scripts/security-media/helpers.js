'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { BASE, contained } = require('./guard');
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jWZkAAAAASUVORK5CYII=', 'base64');
// Authored one-page, inert PDF with valid xref offsets, and versioned black MP4.
const pdfObjects = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R] /Count 1 >>', '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] /Resources << >> >>'];
let pdfText = '%PDF-1.4\n', offsets = [0];
pdfObjects.forEach((body, i) => { offsets.push(Buffer.byteLength(pdfText)); pdfText += `${i + 1} 0 obj\n${body}\nendobj\n`; });
const xref = Buffer.byteLength(pdfText); pdfText += `xref\n0 4\n0000000000 65535 f \n${offsets.slice(1).map(n => `${String(n).padStart(10, '0')} 00000 n \n`).join('')}trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
const pdf = Buffer.from(pdfText);
const videoPath = path.join(__dirname, 'fixtures/canary.mp4');
const video = fs.readFileSync(videoPath);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
assert.equal(hash(video), 'd52c25883ebab2b9d7a9f416f4a7e7d118ff429eb68e85bbf295f34d99c70ae7', 'Synthetic MP4 fixture changed');
const file = id => contained(path.resolve('uploads'), path.resolve('uploads', id));
function files() {
  const root = path.resolve('uploads');
  const walk = p => !fs.existsSync(p) ? [] : fs.readdirSync(p, { withFileTypes: true }).flatMap(e => {
    const target = contained(root, path.join(p, e.name));
    return e.isDirectory() ? walk(target) : [{ id: path.relative(root, target).replace(/\\/g, '/'), sha256: hash(fs.readFileSync(target)), bytes: fs.statSync(target).size }];
  });
  return walk(root).sort((a, b) => a.id.localeCompare(b.id));
}
async function upload(c, actor = 'A', { context = 'message', mime = 'image/png', name = 'synthetic.png', bytes = png, fields = {}, header } = {}) {
  const form = new FormData(); form.set('context', context);
  for (const [key, value] of Object.entries(fields)) form.set(key, String(value));
  form.append('file', new Blob([bytes], { type: mime }), name);
  const headers = {}; if (actor !== 'anonymous') headers.Authorization = header || `Bearer ${c.tokens[actor]}`;
  const response = await fetch(BASE + '/api/media/upload', { method: 'POST', headers, body: form, redirect: 'error', signal: AbortSignal.timeout(15000) });
  const data = await response.json();
  assert.notEqual(response.status, 429, 'Upload limiter prevented intended execution');
  c.evidence.uploadStatus = response.status;
  return { status: response.status, data };
}
async function own(c, actor = 'A', options) {
  const response = await upload(c, actor, options); assert.equal(response.status, 200, 'Valid upload control failed');
  const media = response.data.data; assert.ok(media.publicId && media.url);
  if (c.mode === 'local') assert.equal(hash(fs.readFileSync(file(media.publicId))), hash(options?.bytes || png));
  else { const state = await c.state(); assert.ok(state.calls.some(call => call.operation === 'upload_stream' && call.sha256 === hash(options?.bytes || png))); assert.ok(state.assets.some(a => a.publicId === media.publicId)); }
  return media;
}
const destroy = (c, actor, id) => c.http(actor, 'DELETE', '/api/media/' + encodeURIComponent(id));
const patient = url => [{ bedNumber: 'CI', clinicalAlias: 'Synthetic', attachments: [{ url, fileName: 'synthetic.png', mimeType: 'image/png' }] }];
async function attach(c, url) {
  const r = await c.http('A', 'PUT', `/api/handoffs/${c.ids.handoff}`, { patients: patient(url) }); assert.equal(r.status, 200);
  assert.equal((await c.models.Handoff.findById(c.ids.handoff)).patients[0].attachments[0].url, url); return r;
}
const operations = (state, name) => state.calls.filter(call => call.operation === name);
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
module.exports = { png, pdf, video, videoPath, hash, file, files, upload, own, destroy, patient, attach, operations, same };
