'use strict';
const fs = require('node:fs'); const path = require('node:path'); const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const hash = b => createHash('sha256').update(b).digest('hex');
// Author a decoder-valid 1x1 opaque black PNG; do not reuse the offline-only
// fixture's invalid IDAT CRC or rewrite its historical evidence.
function crc32(bytes) { let c = 0xffffffff; for (const byte of bytes) { c ^= byte; for (let i = 0; i < 8; i++) c = c & 1 ? (c >>> 1) ^ 0xedb88320 : c >>> 1; } return (c ^ 0xffffffff) >>> 0; }
function chunk(type, bytes) { const body = Buffer.concat([Buffer.from(type), bytes]); const out = Buffer.alloc(body.length + 8); out.writeUInt32BE(bytes.length); body.copy(out, 4); out.writeUInt32BE(crc32(body), out.length - 4); return out; }
const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(1); ihdr.writeUInt32BE(1, 4); ihdr[8] = 8; ihdr[9] = 6;
const pixelPNG = pixel => Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), chunk('IHDR', ihdr), chunk('IDAT', require('node:zlib').deflateSync(Buffer.from([0, ...pixel]))), chunk('IEND', Buffer.alloc(0))]);
const png = pixelPNG([0, 0, 0, 255]); const alternatePNG = pixelPNG([255, 255, 255, 255]);
const objects = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R] /Count 1 >>', '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] /Resources << >> >>'];
let text = '%PDF-1.4\n'; const offsets = [];
objects.forEach((o, i) => { offsets.push(Buffer.byteLength(text)); text += `${i + 1} 0 obj\n${o}\nendobj\n`; });
const xref = Buffer.byteLength(text); text += `xref\n0 4\n0000000000 65535 f \n${offsets.map(n => `${String(n).padStart(10, '0')} 00000 n \n`).join('')}trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
const pdf = Buffer.from(text); const video = fs.readFileSync(path.join(__dirname, '../security-media/fixtures/canary.mp4'));
assert.equal(hash(video), 'd52c25883ebab2b9d7a9f416f4a7e7d118ff429eb68e85bbf295f34d99c70ae7');
module.exports = { png, alternatePNG, pdf, video, hash };
