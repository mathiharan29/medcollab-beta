'use strict';
const { requireSafe } = require('./guard'); const f = require('./fixtures');
const definitions = [
  ['Positive test-cloud binding and signed synthetic smoke', 'configuration', 'Exact positive allowlist match and signed PNG accepted only within this run'],
  ['Application PNG upload resource identity', 'image', 'Real controller PNG stored as image/upload under broker run namespace'],
  ['Image exact authenticated resource read', 'image', 'Exact provider metadata matches recorded public ID, asset ID and resource type'],
  ['Image HTTPS original retrieval', 'image', 'Approved-cloud HTTPS original returns image bytes'],
  ['Application safe image thumbnail transformation', 'image', 'Controller 400x400 limit WebP thumbnail retrieves successfully'],
  ['Image anonymous delivery characterization', 'image', 'Measure unsigned synthetic delivery; public access does not establish clinical policy'],
  ['Application MP4 upload resource identity', 'video', 'Real controller synthetic MP4 stored as video/upload'],
  ['Video exact authenticated resource read', 'video', 'Exact video metadata exists and matches this run'],
  ['Video HTTPS original retrieval', 'video', 'Synthetic video delivery returns video bytes'],
  ['Application video JPG thumbnail transformation', 'video', 'Controller video frame transformation retrieves image bytes'],
  ['Application owner video deletion limitation', 'video', 'Owner deletion should remove video; preserve existing VOCLE-736 finding if retained'],
  ['Independent explicit video deletion', 'video', 'Correct video resource type destroy returns ok'],
  ['Video origin disappearance', 'video', 'Exact authenticated video lookup returns 404 after deletion'],
  ['Video post-delete delivery behavior', 'video', 'Fresh original delivery should stop; report CDN persistence separately from origin absence'],
  ['Repeated video deletion semantics', 'video', 'Repeated exact video destroy returns not found'],
  ['Application PDF raw upload resource identity', 'raw', 'Real controller synthetic PDF stored as raw/upload'],
  ['Raw PDF exact authenticated resource read', 'raw', 'Exact raw PDF metadata exists and matches this run'],
  ['Raw PDF HTTPS original delivery', 'raw', 'Original synthetic PDF delivery returns exact fixture bytes'],
  ['Application raw PDF attachment delivery', 'raw', 'Controller attachment URL returns exact PDF bytes where account allows delivery'],
  ['Application raw PDF image preview compatibility', 'raw', 'Measure actual image preview; URL construction alone cannot establish support'],
  ['Application owner raw deletion', 'raw', 'Unchanged controller image-then-raw deletion removes owned PDF'],
  ['Raw origin disappearance and post-delete retrieval', 'raw', 'Exact authenticated raw lookup returns 404; measure original delivery separately for cache persistence'],
  ['Repeated raw deletion semantics', 'raw', 'Repeated exact raw destroy returns not found'],
  ['Application owner image deletion', 'image', 'Unchanged controller removes owned image'],
  ['Image origin disappearance, retrieval and repeated deletion', 'image', 'Image exact lookup absent, repeated destroy not found; measure original delivery separately'],
  ['Same-folder duplicate filenames and generated IDs', 'naming', 'Provider generates distinct IDs for duplicate synthetic filenames without overwriting'],
  ['Explicit overwrite false preserves original', 'naming', 'Second same-ID upload with overwrite false preserves original exact resource'],
  ['Explicit overwrite true characterization', 'naming', 'Bounded owned same-ID overwrite is accepted; record actual version and bytes'],
  ['Same public ID resource-type separation', 'naming', 'Image/raw same public ID remain independently typed resources'],
  ['Namespace and forged filename isolation', 'naming', 'Controller unsafe original filename cannot escape the broker run namespace'],
  ['Application octet-PDF provider dispatch', 'raw', 'Octet-PDF should select raw; actual image intent remains VOCLE-724 observation'],
  ['Application octet-MP4 provider dispatch', 'video', 'Octet-MP4 should select video; actual image intent remains VOCLE-725 observation'],
  ['Application shared handoff deletion limitation', 'image', 'Uploader should remove handoff asset; existing VOCLE-740 observation if forbidden'],
  ['Independent manifest cleanup and exact absence verification', 'cleanup', 'All recorded image/video/raw resources removed; no unresolved upload intents'],
];
const manifest = { baselineCatalogCount: 751, count: definitions.length, combinedCatalogCount: 751 + definitions.length, cases: definitions.map(([name, category, expected], index) => ({ caseId: `VOCLE-${752 + index}`, name, category, expected })) };
const owner = '7ec000000000000000000001';
async function invoke(handler, req) {
  return new Promise((resolve, reject) => {
    let status = 200; const res = { status(code) { status = code; return this; }, json(body) { resolve({ status, body }); return this; } };
    handler(req, res, reject);
  });
}
function context(b) {
  const controller = require('../../src/features/media/media.controller');
  return {
    b, controller, owner, media: {},
    async upload(mime, bytes, name = 'synthetic.png', context = 'message') {
      const before = b.journal.intents.length;
      const reply = await invoke(controller.uploadFile, { user: { _id: owner }, body: { context }, file: { mimetype: mime, buffer: bytes, originalname: name, size: bytes.length } });
      requireSafe(!b.infrastructureError, b.infrastructureError || 'BROKER_FAILURE');
      return { reply, intent: b.journal.intents[before], result: reply.status === 200 ? b.resource(reply.body.data.publicId) : null };
    },
    async delete(r) { const reply = await invoke(controller.deleteFile, { user: { _id: owner }, params: { publicId: encodeURIComponent(r.publicId) } }); requireSafe(!b.infrastructureError, b.infrastructureError || 'BROKER_FAILURE'); return reply; },
  };
}
const outcome = (pass, actual, classification = 'provider/configuration behavior', links = []) => ({ pass, actual, classification, relatedCases: links });
const okDelivery = (d, type) => d.status === 200 && d.contentType.startsWith(type + '/') && d.bytes > 0 && !d.redirected;
async function execute(index, c) {
  const b = c.b, m = c.media;
  switch (index) {
    case 0: { const r = await b.upload(f.png, { resource_type: 'image', use_filename: true, unique_filename: true }); requireSafe(!r.rejected, 'VALID_SMOKE_UPLOAD_FAILED'); m.smoke = b.resource(r.public_id); return outcome(true, { allowlistMatched: true, signedUploadAccepted: true, identity: b.evidence(m.smoke) }); }
    case 1: { const r = await c.upload('image/png', f.png); requireSafe(r.reply.status === 200 && r.result, 'VALID_IMAGE_CONTROL_FAILED'); m.image = r.result; m.imageReply = r.reply; return outcome(m.image.resourceType === 'image', { status: r.reply.status, identity: b.evidence(m.image), brokerFolderAdaptation: true }); }
    case 2: { const r = await b.read(m.image); return outcome(r.exists, r); }
    case 3: { const d = await b.retrieve(m.imageReply.body.data.url); return outcome(okDelivery(d, 'image'), d); }
    case 4: { const d = await b.retrieve(m.imageReply.body.data.thumbnailUrl); return outcome(okDelivery(d, 'image') && d.contentType === 'image/webp', d); }
    case 5: { const d = await b.retrieve(m.imageReply.body.data.url); return outcome([200, 401, 403, 404].includes(d.status), { ...d, unsignedDelivery: true, anonymouslyRetrievable: d.status === 200, policyApproval: false }); }
    case 6: { const r = await c.upload('video/mp4', f.video, 'synthetic.mp4'); requireSafe(r.reply.status === 200 && r.result, 'VALID_VIDEO_CONTROL_FAILED'); m.video = r.result; m.videoReply = r.reply; return outcome(m.video.resourceType === 'video', { status: r.reply.status, identity: b.evidence(m.video) }); }
    case 7: { const r = await b.read(m.video); return outcome(r.exists, r); }
    case 8: { const d = await b.retrieve(m.videoReply.body.data.url); return outcome(okDelivery(d, 'video'), d); }
    case 9: { const d = await b.retrieve(m.videoReply.body.data.thumbnailUrl); return outcome(okDelivery(d, 'image') && d.contentType === 'image/jpeg', d); }
    case 10: { const before = b.calls.length, reply = await c.delete(m.video), state = await b.read(m.video); return outcome(reply.status === 200 && !state.exists, { status: reply.status, videoRetained: state.exists, dispatch: b.calls.slice(before).filter(x => x.operation === 'application-destroy').map(x => x.resourceType) }, 'existing application deletion defect', ['VOCLE-736']); }
    case 11: { const d = await b.destroy(m.video); return outcome(d.result === 'ok', d); }
    case 12: { const r = await b.read(m.video); return outcome(!r.exists, r); }
    case 13: { const d = await b.retrieve(m.videoReply.body.data.url); return outcome([404, 410].includes(d.status), { ...d, appInvalidateOmitted: true, independentTestDeletionInvalidate: false }, 'provider CDN/cache behavior'); }
    case 14: { const d = await b.destroy(m.video); return outcome(d.result === 'not found', d); }
    case 15: { const r = await c.upload('application/pdf', f.pdf, 'synthetic.pdf'); requireSafe(r.reply.status === 200 && r.result, 'VALID_RAW_CONTROL_FAILED'); m.raw = r.result; m.rawReply = r.reply; m.rawURL = b.url(m.raw.publicId, { resource_type: 'raw', secure: true }); return outcome(m.raw.resourceType === 'raw', { status: r.reply.status, identity: b.evidence(m.raw) }); }
    case 16: { const r = await b.read(m.raw); return outcome(r.exists, r); }
    case 17: { const d = await b.retrieve(m.rawURL); return outcome(d.status === 200 && d.sha256 === f.hash(f.pdf), d); }
    case 18: { const d = await b.retrieve(m.rawReply.body.data.url); const control = await b.retrieve(b.url(m.raw.publicId, { resource_type: 'raw', flags: 'attachment', secure: true })); return outcome(d.status === 200 && d.sha256 === f.hash(f.pdf), { ...d, plainAttachmentControl: control, plainAttachmentSupported: control.status === 200 && control.sha256 === f.hash(f.pdf) }, 'application raw attachment URL/provider compatibility'); }
    case 19: { const thumbnailUrl = m.rawReply.body.data.thumbnailUrl; const d = thumbnailUrl ? await b.retrieve(thumbnailUrl) : null; const controlUpload = await b.upload(f.pdf, { resource_type: 'image', use_filename: true, unique_filename: true }); requireSafe(!controlUpload.rejected, 'IMAGE_PDF_CONTROL_FAILED'); const controlResource = b.resource(controlUpload.public_id); const metadata = await b.read(controlResource); const controlPreview = await b.retrieve(b.url(controlResource.publicId, { resource_type: 'image', format: 'webp', width: 400, height: 300, crop: 'fill', page: 1 })); const previewSupported = !!d && okDelivery(d, 'image'); return outcome(thumbnailUrl == null || previewSupported, { appThumbnailProvided: !!thumbnailUrl, appPreview: d, uploadedResourceType: 'raw', previewResourceType: 'image', previewSupported, imagePDFControl: { identity: b.evidence(controlResource), metadata, preview: controlPreview, previewSupported: okDelivery(controlPreview, 'image') } }, 'application raw/image preview compatibility or account configuration'); }
    case 20: { const reply = await c.delete(m.raw); const state = await b.read(m.raw); return outcome(reply.status === 200 && !state.exists, { status: reply.status, ...state }); }
    case 21: { const r = await b.read(m.raw); const delivery = await b.retrieve(m.rawURL); return outcome(!r.exists && [404, 410].includes(delivery.status), { ...r, delivery, originAbsenceIndependentOfCDN: true }, 'provider CDN/cache behavior'); }
    case 22: { const d = await b.destroy(m.raw); return outcome(d.result === 'not found', d); }
    case 23: { const reply = await c.delete(m.image); const state = await b.read(m.image); return outcome(reply.status === 200 && !state.exists, { status: reply.status, ...state }); }
    case 24: { const state = await b.read(m.image); const d = await b.destroy(m.image); const delivery = await b.retrieve(m.imageReply.body.data.url); return outcome(!state.exists && d.result === 'not found' && [404, 410].includes(delivery.status), { ...state, ...d, delivery, originAbsenceIndependentOfCDN: true }, 'provider CDN/cache behavior'); }
    case 25: { const folder = b.c.root + '/duplicate-names'; const options = { resource_type: 'image', use_filename: true, unique_filename: true, filename_override: 'synthetic-duplicate' }; const a = await b.upload(f.png, options, { folder }); const d = await b.upload(f.png, options, { folder }); requireSafe(!a.rejected && !d.rejected, 'NAMING_CONTROL_FAILED'); const ar = b.resource(a.public_id), dr = b.resource(d.public_id); return outcome(a.public_id !== d.public_id && (await b.read(ar)).exists && (await b.read(dr)).exists, { distinctIds: a.public_id !== d.public_id, first: b.evidence(ar), second: b.evidence(dr), filenameOverrideControlsID: a.public_id.includes('synthetic-duplicate') }); }
    case 26: { const folder = b.c.root + '/overwrite'; const options = { resource_type: 'image', overwrite: false }; const a = await b.upload(f.png, options, { folder, explicitId: 'synthetic' }); requireSafe(!a.rejected, 'OVERWRITE_CONTROL_FAILED'); const r = b.resource(a.public_id), old = { version: r.version, assetId: r.assetId }; const d = await b.upload(f.alternatePNG, options, { folder, explicitId: 'synthetic' }); const state = await b.read(r); const delivery = await b.retrieve(b.url(r.publicId, { secure: true, format: 'png' })); m.overwrite = r; const bytesPreserved = delivery.status === 200 && delivery.sha256 === f.hash(f.png); return outcome(state.exists && old.version === r.version && old.assetId === r.assetId && bytesPreserved, { secondRejected: !!d.rejected, existingReturned: !!d.existing, identityPreserved: old.assetId === r.assetId, versionPreserved: old.version === r.version, differentSyntheticBytesAttempted: true, originalBytesPreserved: bytesPreserved, delivery }); }
    case 27: { const oldVersion = m.overwrite.version; const result = await b.upload(f.alternatePNG, { resource_type: 'image', overwrite: true }, { folder: b.c.root + '/overwrite', explicitId: 'synthetic' }); requireSafe(!result.rejected, 'OVERWRITE_PROBE_FAILED'); const r = b.resource(result.public_id); const delivery = await b.retrieve(result.secure_url); const replacementVerified = delivery.status === 200 && delivery.sha256 === f.hash(f.alternatePNG); return outcome((await b.read(r)).exists && replacementVerified, { accepted: true, previousVersion: oldVersion, returnedVersion: r.version, differentSyntheticBytesOnly: true, replacementBytesVerified: replacementVerified, delivery, productionOverwritePolicyVerified: false }); }
    case 28: { const folder = b.c.root + '/type-separation'; const a = await b.upload(f.png, { resource_type: 'image', overwrite: false }, { folder, explicitId: 'synthetic' }); const d = await b.upload(f.pdf, { resource_type: 'raw', overwrite: false }, { folder, explicitId: 'synthetic' }); requireSafe(!a.rejected && !d.rejected, 'TYPE_SEPARATION_CONTROL_FAILED'); const ar = b.resource(a.public_id, 'image'), dr = b.resource(d.public_id, 'raw'); return outcome(a.public_id === d.public_id && (await b.read(ar)).exists && (await b.read(dr)).exists, { samePublicId: a.public_id === d.public_id, independentResourceTypes: ['image', 'raw'] }); }
    case 29: { const r = await c.upload('image/png', f.png, '../../synthetic-(canary).png'); requireSafe(r.result, 'NAME_ISOLATION_CONTROL_FAILED'); const expectedFolderMatched = r.result.publicId.startsWith(r.intent.folder + '/'); const canonicalSegmentsSafe = !r.result.publicId.split('/').some(s => s === '.' || s === '..'); return outcome(r.result.publicId.startsWith(b.c.root + '/') && expectedFolderMatched && canonicalSegmentsSafe, { identity: b.evidence(r.result), originalFilenameSanitized: r.intent.originalOptions.filename_override, normalAppFolderPreservedUnderRunRoot: true, expectedFolderMatched, canonicalSegmentsSafe }); }
    case 30: case 31: { const expectedType = index === 30 ? 'raw' : 'video'; const r = await c.upload('application/octet-stream', index === 30 ? f.pdf : f.video, index === 30 ? 'synthetic.pdf' : 'synthetic.mp4'); return outcome(r.intent.resourceType === expectedType && !!r.result && r.result.resourceType === expectedType, { requestedType: r.intent.resourceType, expectedType, appStatus: r.reply.status, providerAccepted: !!r.result, storedType: r.result?.resourceType || null, providerRejectionStatus: r.intent.providerStatus || null }, 'existing application MIME-only dispatch defect', [index === 30 ? 'VOCLE-724' : 'VOCLE-725']); }
    case 32: { const r = await c.upload('image/png', f.png, 'synthetic.png', 'handoff'); requireSafe(r.result, 'HANDOFF_CONTROL_FAILED'); const reply = await c.delete(r.result); const state = await b.read(r.result); return outcome(reply.status === 200 && !state.exists, { status: reply.status, retained: state.exists, originalFolder: r.intent.originalOptions.folder }, 'existing application handoff lifecycle limitation', ['VOCLE-740']); }
    default: requireSafe(false, 'CASE_INDEX_INVALID');
  }
}
module.exports = { manifest, context, execute };
