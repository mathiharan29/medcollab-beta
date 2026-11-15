// Issues 10 + 11 (beta 11-14): "Delete for me" and "Clear chat" must hold in
// every view that copies messages — group list, chat list, space page,
// channel info (pinned), thread (root + reply count). Colleagues unaffected.
import { api, doctor, ward, send, dmBetween, check, eq, ok, summary } from './lib.mjs';

const meera = await doctor('Meera Iyer');
const arjun = await doctor('Arjun Rao');
const { spaceId, general } = await ward(arjun, [meera]);

const groupPreview = async (who) => {
  const r = await api(who.token, 'GET', '/api/spaces');
  const sp = r.data.spaces.find((s) => s._id === spaceId);
  return sp.channels.find((c) => c._id === general)?.lastMessage?.text ?? null;
};
const spacePagePreview = async (who) => {
  const r = await api(who.token, 'GET', `/api/spaces/${spaceId}`);
  return r.data.space.channels.find((c) => c._id === general)?.lastMessage?.text ?? null;
};
const channelListPreview = async (who) => {
  const r = await api(who.token, 'GET', `/api/spaces/${spaceId}/channels`);
  return r.data.channels.find((c) => c._id === general)?.lastMessage?.text ?? null;
};
const channelInfo = async (who) =>
  (await api(who.token, 'GET', `/api/channels/${general}`)).data.channel;
const timeline = async (who) =>
  (await api(who.token, 'GET', `/api/channels/${general}/messages`)).data.messages;

// ── Issue 10 — Delete for me ────────────────────────────────────────────────
const handover0 = await send(arjun, general, 'Bed 12 for review');
const handover = await send(arjun, general, 'Evening handover moved to 7 pm');

await check('10.0 both see the latest message as the preview', async () => {
  eq(await groupPreview(meera), 'Evening handover moved to 7 pm', 'meera');
  eq(await groupPreview(arjun), 'Evening handover moved to 7 pm', 'arjun');
});

await check('10.1 delete for me hides it from Meera\'s timeline', async () => {
  const d = await api(meera.token, 'DELETE', `/api/channels/${general}/messages/${handover._id}?scope=me`);
  eq(d.status, 200);
  ok(!(await timeline(meera)).some((m) => m._id === handover._id), 'still in timeline');
});

await check('10.2 Meera\'s group-list preview falls back to the previous message', async () => {
  eq(await groupPreview(meera), 'Bed 12 for review');
});
await check('10.3 same fallback on group page and channel list and channel info', async () => {
  eq(await spacePagePreview(meera), 'Bed 12 for review', 'space page');
  eq(await channelListPreview(meera), 'Bed 12 for review', 'channel list');
  eq((await channelInfo(meera)).lastMessage?.text, 'Bed 12 for review', 'channel info');
});
await check('10.4 colleagues still see the original everywhere', async () => {
  eq(await groupPreview(arjun), 'Evening handover moved to 7 pm', 'group list');
  eq(await spacePagePreview(arjun), 'Evening handover moved to 7 pm', 'space page');
  ok((await timeline(arjun)).some((m) => m._id === handover._id), 'timeline');
});
await check('10.5 a new message replaces the fallback for both', async () => {
  await send(arjun, general, 'ICU bed free');
  eq(await groupPreview(meera), 'ICU bed free', 'meera');
  eq(await groupPreview(arjun), 'ICU bed free', 'arjun');
});
await check('10.6 delete-for-me of every visible message → empty preview, list order kept', async () => {
  const all = await timeline(meera);
  for (const m of all.filter((x) => x.type !== 'system')) {
    await api(meera.token, 'DELETE', `/api/channels/${general}/messages/${m._id}?scope=me`);
  }
  const r = await api(meera.token, 'GET', '/api/spaces');
  const ch = r.data.spaces.find((s) => s._id === spaceId).channels.find((c) => c._id === general);
  // Remaining visible root (if any) is a system activity line; otherwise empty.
  ok(ch.lastMessage.text === null || /joined|created|added/i.test(ch.lastMessage.text),
    `unexpected preview ${ch.lastMessage.text}`);
  ok(ch.lastMessage.sentAt, 'sentAt kept for ordering');
  eq(await groupPreview(arjun), 'ICU bed free', 'arjun unaffected');
});
await check('10.7 hiding a thread reply that is the latest activity falls back to a root', async () => {
  const root = await send(arjun, general, 'Ward round notes');
  const reply = (await api(arjun.token, 'POST', `/api/channels/${general}/messages/${root._id}/reply`, {
    type: 'text', content: { text: 'Patient in bed 3 stable' },
  })).data.message;
  eq(await groupPreview(meera), 'Patient in bed 3 stable', 'reply is shared latest');
  await api(meera.token, 'DELETE', `/api/channels/${general}/messages/${reply._id}?scope=me`);
  eq(await groupPreview(meera), 'Ward round notes', 'meera falls back');
  eq(await groupPreview(arjun), 'Patient in bed 3 stable', 'arjun unaffected');
});
await check('10.8 reply count under the root excludes Meera\'s hidden reply (only for her)', async () => {
  const mine = (await timeline(meera)).find((m) => m.content?.text === 'Ward round notes');
  const his = (await timeline(arjun)).find((m) => m.content?.text === 'Ward round notes');
  eq(mine.replyCount, 0, 'meera');
  eq(mine.lastReply, null, 'meera lastReply');
  eq(his.replyCount, 1, 'arjun');
  const t = await api(meera.token, 'GET', `/api/channels/${general}/messages/${mine._id}/thread`);
  eq(t.data.rootMessage.replyCount, 0, 'thread root count');
  eq(t.data.replies.length, 0, 'thread replies');
});
await check('10.9 who hid what is never exposed (pinned/channel info/timeline)', async () => {
  await api(arjun.token, 'POST', `/api/channels/${general}/pin/${handover0._id}`);
  const info = await api(arjun.token, 'GET', `/api/channels/${general}`);
  ok(!JSON.stringify(info.body).includes('hiddenFor'), 'hiddenFor leaked in channel info');
  const tl = await api(arjun.token, 'GET', `/api/channels/${general}/messages`);
  ok(!JSON.stringify(tl.body).includes('hiddenFor'), 'hiddenFor leaked in timeline');
});
await check('10.10 pinned bar drops a message Meera deleted for herself (not for Arjun)', async () => {
  const pinsOf = async (w) => (await channelInfo(w)).pinnedMessages.map((p) => p.messageId?._id || p.messageId);
  ok((await pinsOf(arjun)).includes(handover0._id), 'arjun sees pin');
  ok(!(await pinsOf(meera)).includes(handover0._id), 'meera still sees hidden pin');
});
await check('10.11 delete for me is idempotent; outsider cannot touch it', async () => {
  const again = await api(meera.token, 'DELETE', `/api/channels/${general}/messages/${handover._id}?scope=me`);
  eq(again.status, 200);
  const stranger = await doctor('Out Sider');
  const x = await api(stranger.token, 'DELETE', `/api/channels/${general}/messages/${handover._id}?scope=me`);
  ok(x.status === 403 || x.status === 404, `outsider got ${x.status}`);
});

// ── Issue 11 — Clear chat ───────────────────────────────────────────────────
const preRoot = await send(arjun, general, 'Old plan: discharge bed 9');
await api(arjun.token, 'POST', `/api/channels/${general}/messages/${preRoot._id}/reply`, {
  type: 'text', content: { text: 'Old reply: pending labs' },
});
await api(arjun.token, 'POST', `/api/channels/${general}/pin/${preRoot._id}`);
await send(arjun, general, 'Pre-clear latest');

await check('11.1 clear chat empties Meera\'s timeline and previews (group list, page, info)', async () => {
  const c = await api(meera.token, 'POST', `/api/channels/${general}/messages/clear`);
  eq(c.status, 200);
  eq((await timeline(meera)).length, 0, 'timeline');
  eq(await groupPreview(meera), null, 'group list');
  eq(await spacePagePreview(meera), null, 'space page');
  eq(await channelListPreview(meera), null, 'channel list');
  eq((await channelInfo(meera)).lastMessage?.text ?? null, null, 'channel info');
});
await check('11.2 reopening an older thread directly does not return its root', async () => {
  const t = await api(meera.token, 'GET', `/api/channels/${general}/messages/${preRoot._id}/thread`);
  eq(t.status, 404);
  ok(!JSON.stringify(t.body).includes('discharge bed 9'), 'root text leaked');
});
await check('11.3 Arjun still opens the same thread with its replies', async () => {
  const t = await api(arjun.token, 'GET', `/api/channels/${general}/messages/${preRoot._id}/thread`);
  eq(t.status, 200);
  eq(t.data.rootMessage.content.text, 'Old plan: discharge bed 9');
  eq(t.data.replies.length, 1);
  eq(await groupPreview(arjun), 'Pre-clear latest', 'arjun preview');
});
await check('11.4 a new reply in a cleared thread does not resurface it in Meera\'s preview', async () => {
  await api(arjun.token, 'POST', `/api/channels/${general}/messages/${preRoot._id}/reply`, {
    type: 'text', content: { text: 'New reply on old thread' },
  });
  eq(await groupPreview(arjun), 'New reply on old thread', 'arjun sees it');
  eq(await groupPreview(meera), null, 'meera must not see the cleared thread');
});
await check('11.5 pinned pre-clear message is hidden for Meera only', async () => {
  const pins = async (w) => (await channelInfo(w)).pinnedMessages.map((p) => p.messageId?._id || p.messageId);
  ok(!(await pins(meera)).includes(preRoot._id), 'meera');
  ok((await pins(arjun)).includes(preRoot._id), 'arjun');
});
await check('11.6 new messages after clear show for Meera; history stays hidden on reload', async () => {
  await send(arjun, general, 'After clear: rounds at 8');
  eq(await groupPreview(meera), 'After clear: rounds at 8');
  const tl = await timeline(meera);
  eq(tl.map((m) => m.content?.text), ['After clear: rounds at 8']);
});
await check('11.7 search respects clear (pre-clear text not found for Meera)', async () => {
  const s = await api(meera.token, 'GET', '/api/search?q=discharge');
  ok(!JSON.stringify(s.body).includes('discharge bed 9'), 'search leaked');
});
await check('11.8 clearing twice moves the cutoff forward', async () => {
  await api(meera.token, 'POST', `/api/channels/${general}/messages/clear`);
  eq((await timeline(meera)).length, 0);
  eq(await groupPreview(meera), null);
});
await check('11.9 a thread started after the clear is reachable for Meera', async () => {
  const fresh = await send(arjun, general, 'Fresh thread');
  const t = await api(meera.token, 'GET', `/api/channels/${general}/messages/${fresh._id}/thread`);
  eq(t.status, 200);
});

// ── DM (Direct / Needl list) uses the same rules ────────────────────────────
await check('10/11 DM list: delete-for-me fallback and clear', async () => {
  const dm = await dmBetween(arjun, meera);
  await send(arjun, dm, 'DM one');
  const two = await send(arjun, dm, 'DM two');
  await api(meera.token, 'DELETE', `/api/channels/${dm}/messages/${two._id}?scope=me`);
  const list = async (w) => (await api(w.token, 'GET', '/api/channels/dm')).data.channels
    .find((c) => c._id === dm).lastMessage?.text ?? null;
  eq(await list(meera), 'DM one', 'meera fallback');
  eq(await list(arjun), 'DM two', 'arjun original');
  await api(meera.token, 'POST', `/api/channels/${dm}/messages/clear`);
  eq(await list(meera), null, 'meera after clear');
  eq(await list(arjun), 'DM two', 'arjun after meera cleared');
});

summary('Issues 10/11 privacy views');
