// Beta round 11-26: real forwards, reactions (several per person, concurrent
// taps), handoff voice replies.
import { api, doctor, ward, dmBetween, send, check, eq, ok, summary, BASE } from './lib.mjs';

const meera = await doctor('Meera Iyer');
const arjun = await doctor('Arjun Rao');
const bala = await doctor('Bala Krishnan');
const out = await doctor('Out Sider');
const { spaceId, general } = await ward(meera, [arjun, bala], 'Ward 11');
const dmArjun = await dmBetween(meera, arjun);
const dmBala = await dmBetween(meera, bala);

async function upload(who, name, type, context = 'message') {
  const fd = new FormData();
  fd.append('context', context);
  fd.append('file', new Blob([new Uint8Array(2048).fill(3)], { type }), name);
  const r = await fetch(`${BASE}/api/media/upload`, { method: 'POST', headers: { authorization: `Bearer ${who.token}` }, body: fd });
  const j = await r.json();
  return j.data.url;
}
const msgs = async (who, ch) => (await api(who.token, 'GET', `/api/channels/${ch}/messages`)).data.messages;

// ── Issue 2: forward ─────────────────────────────────────────────────────
const original = await send(arjun, dmArjun, 'Bed 7 K+ 6.1, repeat at 2 am');
let forwardId;
await check('26.1 forward copies the original text, tagged — no link, no storage URL', async () => {
  const r = await api(meera.token, 'POST', `/api/channels/${dmBala}/messages`, {
    type: 'text', content: { text: 'client text is ignored' },
    forwardOf: { channelId: dmArjun, messageId: original._id }, clientMessageId: 'fw-test-000001',
  });
  eq(r.status, 201, JSON.stringify(r.body));
  forwardId = r.data.message._id;
  eq(r.data.message.content.text, 'Bed 7 K+ 6.1, repeat at 2 am');
  ok(r.data.message.forwarded.fromName.includes('Arjun Rao'), r.data.message.forwarded.fromName);
  eq(String(r.data.message.forwarded.sourceMessageId), original._id);
  ok(!JSON.stringify(r.data.message.content).includes('vocle://'), 'no link in content');
  const seen = (await msgs(bala, dmBala)).find((m) => m._id === forwardId);
  eq(seen.forwarded.fromName, r.data.message.forwarded.fromName, 'the recipient sees who wrote it');
});

await check('26.2 a retried forward (same key) is stored once', async () => {
  const r = await api(meera.token, 'POST', `/api/channels/${dmBala}/messages`, {
    type: 'text', content: { text: 'x' }, forwardOf: { channelId: dmArjun, messageId: original._id }, clientMessageId: 'fw-test-000001',
  });
  eq(r.data.message._id, forwardId);
  eq((await msgs(bala, dmBala)).filter((m) => m.forwarded?.sourceMessageId === original._id).length, 1);
});

await check('26.3 photos forward as photos (same stored image)', async () => {
  const url = await upload(arjun, 'scan.jpg', 'image/jpeg');
  const photo = (await api(arjun.token, 'POST', `/api/channels/${dmArjun}/messages`, {
    type: 'image', content: { mediaUrl: url, mimeType: 'image/jpeg', fileName: 'scan.jpg' },
  })).data.message;
  const r = await api(meera.token, 'POST', `/api/channels/${general}/messages`, {
    type: 'image', content: { mediaUrl: url }, forwardOf: { channelId: dmArjun, messageId: photo._id },
  });
  eq(r.status, 201, JSON.stringify(r.body));
  eq(r.data.message.type, 'image');
  eq(r.data.message.content.mediaUrl, url);
  eq(r.data.message.content.text ?? null, null, 'no URL pasted as text');
});

await check('26.4 forwarding a forward keeps the original author', async () => {
  const r = await api(bala.token, 'POST', `/api/channels/${general}/messages`, {
    type: 'text', content: { text: 'x' }, forwardOf: { channelId: dmBala, messageId: forwardId },
  });
  eq(r.status, 201, JSON.stringify(r.body));
  ok(r.data.message.forwarded.fromName.includes('Arjun Rao'), 'original author kept');
  eq(String(r.data.message.forwarded.sourceMessageId), original._id);
});

await check('26.5 cannot forward from a chat you are not in, or a deleted message', async () => {
  const outDm = await dmBetween(out, arjun);
  const r = await api(out.token, 'POST', `/api/channels/${outDm}/messages`, {
    type: 'text', content: { text: 'x' }, forwardOf: { channelId: dmArjun, messageId: original._id },
  });
  eq(r.status, 403);
  const gone = await send(arjun, dmArjun, 'to be deleted');
  await api(arjun.token, 'DELETE', `/api/channels/${dmArjun}/messages/${gone._id}?scope=everyone`);
  const r2 = await api(meera.token, 'POST', `/api/channels/${dmBala}/messages`, {
    type: 'text', content: { text: 'x' }, forwardOf: { channelId: dmArjun, messageId: gone._id },
  });
  eq(r2.status, 404);
  const r3 = await api(meera.token, 'POST', `/api/channels/${dmBala}/messages`, {
    type: 'text', content: { text: 'x' }, forwardOf: { channelId: 'not-an-id', messageId: original._id },
  });
  eq(r3.status, 400);
});

// ── Issues 3, 6, 8: reactions ───────────────────────────────────────────
const target = await send(arjun, general, 'Yeah noted');
const react = (who, emoji, active) => api(who.token, 'POST', `/api/channels/${general}/messages/${target._id}/react`, {
  emoji, ...(active === undefined ? {} : { active }),
});
const mineOf = (reactions, who) => reactions.filter((r) => r.userIds.map(String).includes(who.id)).map((r) => r.emoji);

await check('26.6 one person can add several emojis; the same one again removes only it', async () => {
  await react(meera, '👍');
  const r = await react(meera, '❤️');
  eq(new Set(mineOf(r.data.reactions, meera)), new Set(['👍', '❤️']));
  const r2 = await react(meera, '👍');
  eq(mineOf(r2.data.reactions, meera), ['❤️']);
});

await check('26.7 explicit add/remove is idempotent (a repeated tap cannot flip it back)', async () => {
  await react(meera, '🙏', true);
  const r = await react(meera, '🙏', true);
  eq(r.data.reactions.find((x) => x.emoji === '🙏').userIds.length, 1);
  const r2 = await react(meera, '🙏', false);
  const r3 = await react(meera, '🙏', false);
  eq(r2.status, 200); eq(r3.status, 200);
  ok(!r3.data.reactions.some((x) => x.emoji === '🙏'), 'empty group removed');
});

await check('26.8 20 simultaneous reaction taps from 3 people: no errors, consistent result', async () => {
  const people = [meera, arjun, bala];
  const results = await Promise.all(Array.from({ length: 20 }, (_, i) => react(people[i % 3], ['😂', '🔥', '👏'][i % 3])));
  ok(results.every((r) => r.status === 200), `statuses ${results.map((r) => r.status).join(',')}`);
  const stored = (await msgs(meera, general)).find((m) => m._id === target._id).reactions;
  for (const r of stored) eq(new Set(r.userIds.map(String)).size, r.userIds.length, `no duplicate users in ${r.emoji}`);
  ok(stored.every((r) => r.userIds.length > 0), 'no empty groups');
});

await check('26.9 a person can have at most 8 reactions on one message', async () => {
  const fresh = await send(arjun, general, 'limit target');
  const emojis = ['😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😊', '😇'];
  const res = [];
  for (const e of emojis) res.push(await api(bala.token, 'POST', `/api/channels/${general}/messages/${fresh._id}/react`, { emoji: e }));
  eq(res.slice(0, 8).every((r) => r.status === 200), true);
  eq(res[8].status, 400);
});

// ── Issue 4: handoff voice reply ────────────────────────────────────────
await check('26.10 the receiver can reply to a handoff with a voice note (text optional)', async () => {
  const h = (await api(meera.token, 'POST', '/api/handoffs', {
    spaceId, channelId: general, toUserId: arjun.id, shiftDate: new Date().toISOString(), shiftType: 'night',
    patients: [{ bedNumber: '15', clinicalAlias: 'Post-op', status: 'critical' }],
  })).data.handoff;
  await api(meera.token, 'POST', `/api/handoffs/${h._id}/submit`);
  const url = await upload(arjun, 'reply.m4a', 'audio/mp4', 'handoff');
  const r = await api(arjun.token, 'POST', `/api/handoffs/${h._id}/notes`, {
    text: '', kind: 'note', voiceNote: { url, mimeType: 'audio/mp4', durationMs: 4200, waveform: [10, 50, 20] },
  });
  eq(r.status, 200, JSON.stringify(r.body));
  const note = r.data.handoff.writeBackNotes.at(-1);
  eq(note.voiceNote.url, url);
  eq(note.text, '');
  eq(String(note.voiceNote.recordedBy), arjun.id);
  const seen = (await api(meera.token, 'GET', `/api/handoffs/${h._id}`)).data.handoff.writeBackNotes.at(-1);
  eq(seen.voiceNote.durationMs, 4200, 'the sender hears it');
  eq((await api(arjun.token, 'POST', `/api/handoffs/${h._id}/notes`, { text: '' })).status, 400, 'empty note refused');
  eq((await api(arjun.token, 'POST', `/api/handoffs/${h._id}/notes`, {
    text: '', voiceNote: { url: 'https://evil.example/a.m4a', mimeType: 'audio/mp4', durationMs: 3000 },
  })).status, 400, 'untrusted audio refused');
});

summary('Beta 11-26 (forward, reactions, handoff voice reply)');
