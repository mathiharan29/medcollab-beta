// Seeds a LOCAL backend for the on-device verification of the 11-14 round.
// Never production (lib.mjs refuses railway.app). Prints ids as JSON.
//
// Dr Meera (+919100000001) is the doctor on the phone.
import { api, doctor, send, BASE } from '../api/lib.mjs';

const T = (n, phone, extra = {}) => doctor(n, { phone, displayTitle: 'Dr', ...extra });
const meera = await T('Meera Iyer', '+919100000001', { institution: 'KEM Mumbai', speciality: 'Medicine' });
const arjun = await T('Arjun Rao', '+919100000002', { speciality: 'Surgery', role: 'junior_consultant' });
const bala = await T('Bala Krishnan', '+919100000003', { speciality: 'Anaesthesia' });
const chitra = await T('Chitra Nair', '+919100000004', { speciality: 'Paediatrics' });
const asha1 = await T('Asha Rao', '+919100000005', { speciality: 'Cardiology' });
const asha2 = await T('Asha Rao', '+919100000006', { speciality: 'Nephrology', role: 'consultant' });

// Accepted requests: Meera ↔ Arjun, Bala, Chitra.
const dms = {};
for (const peer of [arjun, bala, chitra]) {
  const r = await api(meera.token, 'POST', '/api/message-requests', { toUserId: peer.id, introMessage: 'Ward 5' });
  await api(peer.token, 'POST', `/api/message-requests/${r.data.request.id}/accept`);
  dms[peer.name] = (await api(meera.token, 'POST', '/api/channels/dm', { userId: peer.id })).data.channel._id;
}
for (let i = 1; i <= 14; i++) {
  await send(i % 2 ? arjun : meera, dms['Arjun Rao'], `Bed ${i} update: vitals stable`);
}
await send(bala, dms['Bala Krishnan'], 'Can you review the ABG?');

// Ward 5 group (Meera owner) — issues 9 / 10 / 11.
const s = await api(meera.token, 'POST', '/api/spaces', { name: 'Ward 5', type: 'department' });
const space = s.data.space;
const general = s.data.channels.find((c) => c.name === 'general')._id;
for (const w of [arjun, bala, asha1, asha2]) {
  await api(w.token, 'POST', '/api/spaces/join', { inviteCode: space.inviteCode });
}
const oldRoot = await send(arjun, general, 'Old plan: discharge bed 9 tomorrow');
await api(bala.token, 'POST', `/api/channels/${general}/messages/${oldRoot._id}/reply`, {
  type: 'text', content: { text: 'Pending labs for bed 9' },
});
await send(bala, general, 'Bed 12 for review');
const latest = await send(arjun, general, 'Evening handover moved to 7 pm');

// Needl Meera + Arjun + Bala (issue 8: Chitra gets added on the phone).
const needl = (await api(meera.token, 'POST', `/api/channels/${dms['Arjun Rao']}/expand`, {
  userIds: [bala.id], history: 'none',
})).data.channel._id;
await send(arjun, needl, 'Needl: ICU bed free at 6');

// A real, playable 3 s WAV (two soft tones) for handoff voice notes.
function wav(seconds = 3, rate = 8000) {
  const n = seconds * rate;
  const buf = Buffer.alloc(44 + n * 2);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write('WAVE', 8);
  buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(rate, 24); buf.writeUInt32LE(rate * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
  buf.write('data', 36); buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    const f = i < n / 2 ? 330 : 440;
    buf.writeInt16LE(Math.round(Math.sin((2 * Math.PI * f * i) / rate) * 6000), 44 + i * 2);
  }
  return buf;
}
async function upload(who, name) {
  const fd = new FormData();
  fd.append('context', 'handoff');
  fd.append('file', new Blob([wav()], { type: 'audio/wav' }), name);
  const r = await fetch(`${BASE}/api/media/upload`, { method: 'POST', headers: { authorization: `Bearer ${who.token}` }, body: fd });
  const j = await r.json();
  return j.data.url;
}
const bars = Array.from({ length: 32 }, (_, i) => 20 + ((i * 37) % 70));
const handoff = await api(arjun.token, 'POST', '/api/handoffs', {
  spaceId: space._id,
  channelId: general,
  toUserId: meera.id,
  shiftDate: new Date().toISOString(),
  shiftType: 'night',
  shiftSummary: 'Two admissions; bed 7 needs a repeat Hb.',
  voiceNote: { url: await upload(arjun, 'shift.wav'), mimeType: 'audio/wav', durationMs: 3000, waveform: bars },
  patients: [{
    bedNumber: '7', clinicalAlias: 'Post-op lap chole', status: 'monitoring',
    pendingTasks: ['Repeat Hb at 6 am'],
    voiceNote: { url: await upload(arjun, 'bed7.wav'), mimeType: 'audio/wav', durationMs: 3000, waveform: bars },
  }],
});
await api(arjun.token, 'POST', `/api/handoffs/${handoff.data.handoff._id}/submit`);

console.log(JSON.stringify({
  meera: meera.id, arjun: arjun.id, bala: bala.id, chitra: chitra.id, asha1: asha1.id, asha2: asha2.id,
  dmArjun: dms['Arjun Rao'], dmBala: dms['Bala Krishnan'], dmChitra: dms['Chitra Nair'],
  space: space._id, general, latest: latest._id, oldRoot: oldRoot._id, needl,
  handoff: handoff.data.handoff._id,
}));
