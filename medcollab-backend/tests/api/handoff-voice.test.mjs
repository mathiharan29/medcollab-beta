// Issue 5 (beta 11-14): voice notes on handoffs — shift-level and per
// patient — with validation, multi-user access, stale/concurrent edits and
// the audit rules (audio never deleted).
import { api, doctor, ward, check, eq, ok, summary, BASE } from './lib.mjs';

const sender = await doctor('Priya Night');
const receiver = await doctor('Arjun Morning');
const outsider = await doctor('Out Sider');
const { spaceId, general } = await ward(sender, [receiver], 'Ward 9');

async function uploadAudio(who, name = 'handover.m4a') {
  const fd = new FormData();
  fd.append('context', 'handoff');
  // ~1 KB of fake AAC; the server stores what it is given (no transcoding).
  fd.append('file', new Blob([new Uint8Array(1024).fill(7)], { type: 'audio/mp4' }), name);
  const res = await fetch(`${BASE}/api/media/upload`, {
    method: 'POST',
    headers: { authorization: `Bearer ${who.token}` },
    body: fd,
  });
  const json = await res.json();
  if (res.status !== 200 && res.status !== 201) throw new Error(`upload ${res.status} ${JSON.stringify(json)}`);
  return json.data.url || json.data.file?.url;
}

const shiftAudio = await uploadAudio(sender, 'shift.m4a');
const bedAudio = await uploadAudio(sender, 'bed7.m4a');
const bedAudio2 = await uploadAudio(sender, 'bed7-v2.m4a');

// Stored URLs use the phone-facing host (10.0.2.2); fetch via this machine.
const local = (u) => (u.startsWith('http') ? u.replace(/^https?:\/\/[^/]+/, BASE) : `${BASE}${u}`);

const voice = (url, extra = {}) => ({ url, mimeType: 'audio/mp4', durationMs: 12_300, waveform: [5, 40, 90, 30], ...extra });
const base = {
  spaceId,
  channelId: general,
  toUserId: receiver.id,
  shiftDate: new Date().toISOString(),
  shiftType: 'night',
  shiftSummary: 'Quiet night',
};
const patient = (v) => ({ bedNumber: '7', clinicalAlias: 'Post-op lap chole', status: 'stable', ...(v ? { voiceNote: v } : {}) });

let handoffId;
let version = 0;

await check('5.1 create a handoff with a shift voice note and a patient voice note', async () => {
  const r = await api(sender.token, 'POST', '/api/handoffs', {
    ...base,
    voiceNote: voice(shiftAudio, { recordedBy: outsider.id }), // spoofed → ignored
    patients: [patient(voice(bedAudio))],
  });
  eq(r.status, 201, JSON.stringify(r.body));
  handoffId = r.data.handoff._id;
  eq(r.data.handoff.voiceNote.url, shiftAudio);
  eq(r.data.handoff.voiceNote.durationMs, 12300);
  eq(String(r.data.handoff.voiceNote.recordedBy), sender.id, 'recordedBy is the server user');
  eq(r.data.handoff.patients[0].voiceNote.url, bedAudio);
});

await check('5.2 invalid voice notes are rejected (host, type, length, waveform)', async () => {
  const bad = [
    voice('https://evil.example.com/a.m4a'),
    voice(shiftAudio, { mimeType: 'image/png' }),
    voice(shiftAudio, { durationMs: 100 }),
    voice(shiftAudio, { durationMs: 10 * 60 * 1000 }),
    voice(shiftAudio, { waveform: new Array(100).fill(1) }),
    voice(shiftAudio, { waveform: [300] }),
    'not-an-object',
  ];
  for (const v of bad) {
    const r = await api(sender.token, 'POST', '/api/handoffs', { ...base, voiceNote: v, patients: [patient()] });
    eq(r.status, 400, `accepted ${JSON.stringify(v)}`);
    const p = await api(sender.token, 'POST', '/api/handoffs', { ...base, patients: [patient(v)] });
    eq(p.status, 400, `patient accepted ${JSON.stringify(v)}`);
  }
});

await check('5.3 submit → receiver sees both voice notes and can fetch the audio', async () => {
  eq((await api(sender.token, 'POST', `/api/handoffs/${handoffId}/submit`)).status, 200);
  const r = await api(receiver.token, 'GET', `/api/handoffs/${handoffId}`);
  eq(r.status, 200);
  eq(r.data.handoff.voiceNote.url, shiftAudio);
  eq(r.data.handoff.patients[0].voiceNote.url, bedAudio);
  version = r.data.handoff.contentVersion ?? 0;
  const audio = await fetch(local(shiftAudio));
  eq(audio.status, 200, 'audio served');
});

await check('5.4 only the sender edits; outsiders cannot even read', async () => {
  const r = await api(receiver.token, 'PUT', `/api/handoffs/${handoffId}`, { voiceNote: null });
  eq(r.status, 403);
  eq((await api(outsider.token, 'GET', `/api/handoffs/${handoffId}`)).status, 403);
});

await check('5.5 re-record one patient: new file, shift note untouched, version +1, receiver told', async () => {
  const before = (await api(sender.token, 'GET', `/api/handoffs/${handoffId}`)).data.handoff;
  const r = await api(sender.token, 'PUT', `/api/handoffs/${handoffId}`, {
    baseContentVersion: version,
    voiceNote: before.voiceNote, // unchanged
    patients: [{ ...before.patients[0], voiceNote: voice(bedAudio2, { durationMs: 8000 }) }],
  });
  eq(r.status, 200, JSON.stringify(r.body));
  const h = r.data.handoff;
  eq(h.patients[0].voiceNote.url, bedAudio2);
  eq(h.voiceNote.recordedAt, before.voiceNote.recordedAt, 'unchanged note keeps its time');
  eq(h.contentVersion, version + 1);
  ok(h.editHistory.at(-1).fields.includes('patients'), 'edit recorded');
  ok(h.writeBackNotes.some((n) => /edited/.test(n.text)), 'receiver note');
  version = h.contentVersion;
});

await check('5.6 an edit made on an older copy is refused with 409 + latest handoff', async () => {
  const r = await api(sender.token, 'PUT', `/api/handoffs/${handoffId}`, {
    baseContentVersion: version - 1,
    voiceNote: null,
  });
  eq(r.status, 409);
  eq(r.data.handoff.contentVersion, version, 'latest version returned');
  const still = (await api(sender.token, 'GET', `/api/handoffs/${handoffId}`)).data.handoff;
  eq(still.voiceNote.url, shiftAudio, 'nothing overwritten');
});

await check('5.7 two simultaneous edits on the same version: exactly one wins', async () => {
  const [a, b] = await Promise.all([
    api(sender.token, 'PUT', `/api/handoffs/${handoffId}`, { baseContentVersion: version, shiftSummary: 'Edit A' }),
    api(sender.token, 'PUT', `/api/handoffs/${handoffId}`, { baseContentVersion: version, shiftSummary: 'Edit B' }),
  ]);
  const codes = [a.status, b.status].sort();
  eq(codes, [200, 409]);
  const winner = a.status === 200 ? 'Edit A' : 'Edit B';
  const h = (await api(sender.token, 'GET', `/api/handoffs/${handoffId}`)).data.handoff;
  eq(h.shiftSummary, winner);
  eq(h.contentVersion, version + 1);
  version = h.contentVersion;
});

await check('5.8 receiver notes / acknowledgement never block the sender\'s edit', async () => {
  const note = await api(receiver.token, 'POST', `/api/handoffs/${handoffId}/notes`, { text: 'Seen bed 7' });
  ok(note.status === 200 || note.status === 201, `note ${note.status}`);
  eq((await api(receiver.token, 'POST', `/api/handoffs/${handoffId}/acknowledge`, { note: 'Ok' })).status, 200);
  const r = await api(sender.token, 'PUT', `/api/handoffs/${handoffId}`, { baseContentVersion: version, voiceNote: null });
  eq(r.status, 200, JSON.stringify(r.body));
  eq(r.data.handoff.voiceNote ?? null, null, 'shift voice removed');
  eq(r.data.handoff.status, 'submitted', 'acknowledged handoff needs re-acknowledgement');
  ok(r.data.handoff.writeBackNotes.some((n) => n.text === 'Seen bed 7'), 'receiver note kept');
  version = r.data.handoff.contentVersion;
});

await check('5.9 older apps without baseContentVersion still save', async () => {
  const r = await api(sender.token, 'PUT', `/api/handoffs/${handoffId}`, { voiceNote: voice(shiftAudio) });
  eq(r.status, 200);
  eq(r.data.handoff.contentVersion, version + 1);
});

await check('5.10 voice audio cannot be deleted (audit), even by the sender', async () => {
  const m = String(bedAudio).match(/\/uploads\/(.+)$/) || String(bedAudio).match(/(medcollab\/handoffs\/[^.?#]+)/);
  ok(m, `unexpected url ${bedAudio}`);
  const r = await api(sender.token, 'DELETE', `/api/media/${encodeURIComponent(decodeURIComponent(m[1]))}`);
  ok(r.status === 403 || r.status === 404, `got ${r.status}`);
  eq((await fetch(local(bedAudio))).status, 200, 'file still there');
});

await check('5.11 draft edits are version-guarded too', async () => {
  const d = await api(sender.token, 'POST', '/api/handoffs', { ...base, patients: [patient()] });
  const id = d.data.handoff._id;
  const ok1 = await api(sender.token, 'PUT', `/api/handoffs/${id}`, { baseContentVersion: 0, voiceNote: voice(shiftAudio) });
  eq(ok1.status, 200);
  eq(ok1.data.handoff.voiceNote.url, shiftAudio);
  const stale = await api(sender.token, 'PUT', `/api/handoffs/${id}`, { baseContentVersion: 0, voiceNote: null });
  eq(stale.status, 409);
});

summary('Issue 5 handoff voice notes');
