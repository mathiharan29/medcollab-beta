// Issues 13 + 14 (beta 11-14): Needl Voice transcripts and the voice bot's
// server half, plus the hardening done alongside (server-only content fields).
import { createRequire } from 'node:module';
import { api, doctor, dmBetween, send, check, eq, ok, sleep, summary, BASE } from './lib.mjs';

const require = createRequire(import.meta.url);
const { io } = require('socket.io-client');

const asha = await doctor('Asha Rao');
const bala = await doctor('Bala Krishnan');
const out = await doctor('Out Sider');
const dm = await dmBetween(asha, bala);

const fd = new FormData();
fd.append('context', 'message');
fd.append('file', new Blob([new Uint8Array(2048).fill(9)], { type: 'audio/wav' }), 'v.wav');
const up = await (await fetch(`${BASE}/api/media/upload`, {
  method: 'POST', headers: { authorization: `Bearer ${asha.token}` }, body: fd,
})).json();
const url = up.data.url;

const voice = async (extra = {}) => api(asha.token, 'POST', `/api/channels/${dm}/messages`, {
  type: 'audio',
  content: { mediaUrl: url, mimeType: 'audio/wav', durationMs: 2400, waveform: [10, 60, 30], ...extra },
});

let msgId;
await check('13.1 voice message is sent with transcript pending and voiceMode', async () => {
  const r = await voice({ transcriptStatus: 'pending', voiceMode: true });
  eq(r.status, 201, JSON.stringify(r.body));
  msgId = r.data.message._id;
  eq(r.data.message.content.transcriptStatus, 'pending');
  eq(r.data.message.content.voiceMode, true);
});

await check('13.2 the transcript arrives live for the other doctor (message_updated)', async () => {
  const got = [];
  const s = io(BASE, { auth: { token: bala.token }, transports: ['websocket'], reconnection: false });
  await new Promise((res, rej) => { s.on('authenticated', res); s.on('connect_error', rej); setTimeout(() => rej(new Error('socket')), 8000); });
  s.emit('join_channel', { channelId: dm });
  s.on('message_updated', (e) => got.push(e));
  await sleep(300);
  const r = await api(asha.token, 'PATCH', `/api/channels/${dm}/messages/${msgId}/transcript`, {
    status: 'done', transcript: 'Bed seven needs a repeat haemoglobin',
  });
  eq(r.status, 200, JSON.stringify(r.body));
  await sleep(600);
  s.close();
  const ev = got.find((e) => String(e.messageId) === String(msgId));
  ok(ev, 'no live update');
  eq(ev.content.transcript, 'Bed seven needs a repeat haemoglobin');
  eq(ev.content.transcriptStatus, 'done');
});

await check('13.3 stored: the other doctor reads the transcript on reload', async () => {
  const m = (await api(bala.token, 'GET', `/api/channels/${dm}/messages`)).data.messages.find((x) => x._id === msgId);
  eq(m.content.transcript, 'Bed seven needs a repeat haemoglobin');
});

await check('13.4 only the sender, only audio, only in its chat', async () => {
  eq((await api(bala.token, 'PATCH', `/api/channels/${dm}/messages/${msgId}/transcript`, { status: 'done', transcript: 'x' })).status, 403);
  const t = await send(asha, dm, 'plain text');
  eq((await api(asha.token, 'PATCH', `/api/channels/${dm}/messages/${t._id}/transcript`, { status: 'done', transcript: 'x' })).status, 400);
  const o = await api(out.token, 'PATCH', `/api/channels/${dm}/messages/${msgId}/transcript`, { status: 'done', transcript: 'x' });
  ok(o.status === 403 || o.status === 404, `outsider ${o.status}`);
  eq((await api(asha.token, 'PATCH', `/api/channels/${dm}/messages/${msgId}/transcript`, { status: 'bogus' })).status, 400);
  eq((await api(asha.token, 'PATCH', `/api/channels/${dm}/messages/${msgId}/transcript`, { status: 'done', transcript: 'x'.repeat(9000) })).status, 400);
});

await check('13.5 "unavailable" (old phone / no speech) is recorded, text cleared', async () => {
  const r = await voice({ transcriptStatus: 'pending' });
  const p = await api(asha.token, 'PATCH', `/api/channels/${dm}/messages/${r.data.message._id}/transcript`, { status: 'unavailable' });
  eq(p.data.message.content.transcriptStatus, 'unavailable');
  eq(p.data.message.content.transcript ?? null, null);
});

await check('13.6 transcripts are searchable (and respect delete-for-me)', async () => {
  const s = await api(bala.token, 'GET', '/api/search?q=haemoglobin');
  ok(JSON.stringify(s.body).includes(msgId), 'found by transcript');
  await api(bala.token, 'DELETE', `/api/channels/${dm}/messages/${msgId}?scope=me`);
  const s2 = await api(bala.token, 'GET', '/api/search?q=haemoglobin');
  ok(!JSON.stringify(s2.body).includes(msgId), 'hidden after delete for me');
});

await check('13.7 clients cannot forge server-only fields (activity / transcript on text)', async () => {
  const r = await api(asha.token, 'POST', `/api/channels/${dm}/messages`, {
    type: 'text',
    content: { text: 'hello', systemEvent: 'needl_continued', movedToChannelId: dm, transcript: 'fake' },
  });
  eq(r.status, 400, 'transcript on text is rejected');
  const r2 = await api(asha.token, 'POST', `/api/channels/${dm}/messages`, {
    type: 'text', content: { text: 'hello', systemEvent: 'needl_continued', movedToChannelId: dm },
  });
  eq(r2.status, 201);
  eq(r2.data.message.content.systemEvent ?? null, null);
  eq(r2.data.message.content.movedToChannelId ?? null, null);
});

await check('13.8 voice typing signal: "is recording" reaches the peer with kind=voice', async () => {
  const got = [];
  const sb = io(BASE, { auth: { token: bala.token }, transports: ['websocket'], reconnection: false });
  const sa = io(BASE, { auth: { token: asha.token }, transports: ['websocket'], reconnection: false });
  await Promise.all([sa, sb].map((s) => new Promise((res, rej) => { s.on('authenticated', res); s.on('connect_error', rej); setTimeout(() => rej(new Error('socket')), 8000); })));
  sb.emit('join_channel', { channelId: dm });
  sb.on('user_typing', (e) => got.push(e));
  await sleep(300);
  sa.emit('typing_start', { channelId: dm, kind: 'voice' });
  sa.emit('typing_start', { channelId: dm, kind: '<script>' });
  await sleep(700);
  sa.close(); sb.close();
  ok(got.some((e) => e.kind === 'voice'), 'voice kind delivered');
  ok(!got.some((e) => e.kind && e.kind !== 'voice'), 'only the allowed kind is relayed');
});

// ── Issue 14: voice bot server half ────────────────────────────────────────
const hasKey = Boolean(process.env.ANTHROPIC_API_KEY);
await check('14.1 capabilities reflect configuration; auth required', async () => {
  eq((await api(null, 'GET', '/api/assistant/capabilities')).status, 401);
  const c = await api(asha.token, 'GET', '/api/assistant/capabilities');
  eq(c.status, 200);
  eq(c.data.llm, hasKey);
});

await check('14.2 interpret without a key: graceful (app uses its own parser)', async () => {
  if (hasKey) return;
  const r = await api(asha.token, 'POST', '/api/assistant/interpret', { text: 'tell Bala bed 7 is stable' });
  eq(r.status, 200);
  eq(r.data.llm, false);
  eq(r.data.actions, []);
});

await check('14.3 input validation', async () => {
  eq((await api(asha.token, 'POST', '/api/assistant/interpret', { text: '' })).status, 400);
  eq((await api(asha.token, 'POST', '/api/assistant/interpret', { text: 'x'.repeat(1200) })).status, 400);
});

await check('14.4 Claude proposals are limited to the caller\'s own circle (validator)', async () => {
  const { createRequire: cr } = await import('node:module');
  const req2 = cr(import.meta.url);
  const { _test } = req2('../../src/features/assistant/assistant.controller.js');
  const dir = {
    people: [{ id: 'p:1', name: 'Dr Bala Krishnan' }],
    chats: [{ id: 'c:9', name: 'Ward 5 #general', kind: 'group', spaceId: 's1' }],
  };
  const acts = _test.validateActions([
    { type: 'tool_use', name: 'send_message', input: { to: 'p:1', text: ' Bed 7 stable ' } },
    { type: 'tool_use', name: 'send_message', input: { to: 'p:666', text: 'leak' } }, // not in circle
    { type: 'tool_use', name: 'open_chat', input: { to: 'c:9' } },
    { type: 'tool_use', name: 'create_handoff', input: { to: 'c:9', shift: 'night', summary: '', patients: [] } }, // handoff to a chat → dropped
    { type: 'tool_use', name: 'set_availability', input: { status: 'in_ot' } },
    { type: 'tool_use', name: 'delete_everything', input: {} }, // unknown tool
    { type: 'text', text: 'ok' },
  ], dir);
  eq(acts.map((a) => a.type), ['send_message', 'open_chat', 'set_availability']);
  eq(acts[0].text, 'Bed 7 stable');
  eq(acts[0].to.name, 'Dr Bala Krishnan');
  for (const t of _test.TOOLS) {
    eq(t.strict, true, t.name);
    eq(t.input_schema.additionalProperties, false, t.name);
  }
});

summary('Issues 13/14 voice features (server)');
