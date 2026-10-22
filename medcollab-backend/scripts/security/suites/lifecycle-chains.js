'use strict';
const assert = require('node:assert/strict');
const { once, connect, join, collect, edit, wait, QUIET } = require('../socket-controls');
const oid = x => String(x?._id || x);
module.exports = ({ add, ids }) => {
  const reg = (name, requirement, work) => add(name, 'A', 'SOCKET', '/socket.io/', [200], undefined, {
    module: 'Lifecycle Cross-module Regression', category: 'cross-module-lifecycle', securityInvariant: requirement,
    sources: ['src/features/spaces/space.controller.js', 'src/features/messages/message.controller.js', 'src/features/handoffs/handoff.controller.js', 'src/features/message-requests/messageRequest.controller.js', 'src/socket/index.js'],
    context: 'Bounded real REST transition followed by protected Socket.IO event, independent authorization and persistence controls.',
    run: async c => { c.evidence.requirement = requirement; c.evidence.quietWindowMs = QUIET; c.evidence.invariantHeld = await work(c); const h = await c.http('anonymous', 'GET', '/health'); return { status: h.status, data: { success: h.data?.status === 'ok' } }; }, check: (_, c) => c.evidence.invariantHeld,
  });
  reg('invite join leave must revoke existing channel delivery', 'A synthetic invite join then leave must remove future protected channel event delivery from the existing connection.', async c => {
    const owner = await connect(c, 'A'); const invited = await connect(c, 'H'); await join(owner, ids.channel);
    assert.equal((await c.http('H', 'POST', '/api/spaces/join', { inviteCode: 'DSCABA' })).status, 200); await join(invited, ids.channel); await edit(c, invited, ids.channel, ids.messageA);
    assert.equal((await c.http('H', 'POST', `/api/spaces/${ids.space}/leave`, {})).status, 200); assert.equal((await c.http('H', 'GET', `/api/channels/${ids.channel}/messages`)).status, 403);
    const packets = collect(invited, 'message_updated', p => p.messageId === ids.messageA && p.content?.text === 'Invite leave canary'); await edit(c, owner, ids.channel, ids.messageA, 'A', 'Invite leave canary'); await wait(QUIET);
    c.evidence.revokedDeliveryEvents = packets.length; return packets.length === 0;
  });
  reg('space removal preserves independent DM authorization', 'Losing a space must revoke group history while preserving a separately authorized existing DM and its isolated audience.', async c => {
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); const outsider = await connect(c, 'C'); await join(a, ids.dmAB); await join(b, ids.dmAB);
    assert.equal((await c.http('A', 'DELETE', `/api/spaces/${ids.space}/members/${oid(c.users.B)}`)).status, 200);
    assert.equal((await c.http('B', 'GET', `/api/channels/${ids.channel}/messages`)).status, 403); assert.equal((await c.http('B', 'GET', `/api/channels/${ids.dmAB}/messages`)).status, 200);
    const packets = collect(outsider, 'message_updated', p => p.messageId === ids.dmMessageA); await edit(c, b, ids.dmAB, ids.dmMessageA); await wait(QUIET);
    c.evidence.groupDeniedIndependentDmAllowed = true; c.evidence.foreignEvents = packets.length; return packets.length === 0;
  });
  reg('request acceptance DM delivery retains pair isolation', 'Only accepted request parties may join the resulting DM or receive its messages; outsiders remain denied.', async c => {
    const r = await c.http('F', 'POST', `/api/message-requests/${ids.requestPending}/accept`, {}); assert.equal(r.status, 200);
    const channel = r.data?.data?.channel?._id; assert.ok(channel, 'Accepted-request DM identifier absent');
    const e = await connect(c, 'E'); const f = await connect(c, 'F'); const g = await connect(c, 'G'); await join(e, channel); await join(f, channel); await join(g, channel, false);
    assert.equal((await c.http('G', 'GET', `/api/channels/${channel}/messages`)).status, 403);
    const packets = collect(g, 'new_message', p => p.content?.text === 'Accepted pair canary'); const ready = once(f, 'new_message', p => p.content?.text === 'Accepted pair canary');
    const sent = await c.http('E', 'POST', `/api/channels/${channel}/messages`, { content: { text: 'Accepted pair canary' } }); assert.equal(sent.status, 201); assert.equal(oid(await ready), oid(sent.data.data.message)); await wait(QUIET);
    c.evidence.authorizedControl = true; c.evidence.acceptedPair = (await c.models.MessageRequest.findById(ids.requestPending)).status === 'accepted'; c.evidence.foreignEvents = packets.length;
    return c.evidence.acceptedPair && packets.length === 0;
  });
  reg('handoff reassignment notification targets only new assignee', 'Reassignment personal notifications must target the new assignee and exclude the former assignee and unrelated callers.', async c => {
    await c.models.Space.updateOne({ _id: ids.space }, { $push: { members: { userId: c.users.D._id, role: 'member' } } });
    const d = await connect(c, 'D'); const b = await connect(c, 'B'); const outsider = await connect(c, 'C');
    const packets = [b, outsider].map(s => collect(s, 'new_notification', p => oid(p.referenceId) === ids.handoff));
    const ready = once(d, 'new_notification', p => oid(p.referenceId) === ids.handoff);
    const r = await c.http('A', 'POST', `/api/handoffs/${ids.handoff}/reassign`, { toUserId: oid(c.users.D), note: 'Synthetic reassignment' }); assert.equal(r.status, 200); await ready;
    assert.equal((await c.http('B', 'POST', `/api/handoffs/${ids.handoff}/notes`, { text: 'Former assignee attempt' })).status, 403);
    await wait(QUIET); c.evidence.authorizedControl = true; c.evidence.oldAndForeignNotificationEvents = packets.flat().length;
    return packets.flat().length === 0 && oid((await c.models.Handoff.findById(ids.handoff)).toUserId) === oid(c.users.D);
  });
  for (const target of ['C', 'B']) reg(`private message mention cannot disclose preview to ${target === 'C' ? 'outsider' : 'excluded space member'}`, 'Private message mentions must not bypass audience authorization through notification previews.', async c => {
    await c.models.Channel.updateOne({ _id: ids.channel }, { isPrivate: true, members: [c.users.A._id] });
    const a = await connect(c, 'A'); const excluded = await connect(c, target); await join(a, ids.channel); await join(excluded, ids.channel, false);
    assert.equal((await c.http(target, 'GET', `/api/channels/${ids.channel}/messages`)).status, 403);
    const text = `Private mention ${target} canary`; const packets = collect(excluded, 'new_notification', p => typeof p.body === 'string' && p.body.includes(text));
    const ready = once(a, 'new_message', p => p.content?.text === text);
    const r = await c.http('A', 'POST', `/api/channels/${ids.channel}/messages`, { content: { text }, mentions: [oid(c.users[target])] }); assert.equal(r.status, 201); assert.equal(oid(await ready), oid(r.data.data.message)); await wait(QUIET);
    c.evidence.authorizedControl = true; c.evidence.unauthorizedPreviewEvents = packets.length; c.evidence.matchingMessageReference = packets.some(p => oid(p.referenceId) === oid(r.data.data.message));
    return packets.length === 0;
  });
};
