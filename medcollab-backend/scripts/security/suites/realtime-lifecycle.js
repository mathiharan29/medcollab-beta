'use strict';
const assert = require('node:assert/strict');
const supervise = require('../local-supervisor');
const { once, until, connect, join, collect, edit, availability, wait, QUIET } = require('../socket-controls');
const oid = x => String(x?._id || x);
const jwt = () => require('jsonwebtoken');
module.exports = ({ add, ids }) => {
  const reg = (name, requirement, work, classification) => add(name, 'A', 'SOCKET', '/socket.io/', [200], undefined, {
    module: 'Realtime Lifecycle Regression', category: 'realtime-lifecycle',
    context: 'Real Socket.IO clients and local REST producers, predicate-matched controls, bounded 5 second prerequisites and 1 second exclusion window.',
    sources: ['src/socket/index.js', 'src/socket/spaceRooms.js', 'src/socket/handlers/message.handler.js', 'src/socket/handlers/presence.handler.js', 'src/middleware/auth.js'],
    securityInvariant: requirement, failureClassification: classification || 'authorization/data-isolation regression observation',
    run: async c => { c.evidence.requirement = requirement; c.evidence.quietWindowMs = QUIET; c.evidence.invariantHeld = await work(c); const r = await c.http('anonymous', 'GET', '/health'); assert.equal(r.data?.database, 'connected'); return { status: r.status, data: { success: r.data?.status === 'ok' } }; },
    check: (_, c) => c.evidence.invariantHeld,
  });
  for (const [name, token] of [
    ['absent subject', c => jwt().sign({}, process.env.JWT_SECRET, { expiresIn: 60 })],
    ['unknown subject', c => jwt().sign({ userId: ids.absentUser }, process.env.JWT_SECRET, { expiresIn: 60 })],
    ['not-before in future', c => jwt().sign({ userId: oid(c.users.A) }, process.env.JWT_SECRET, { expiresIn: 120, notBefore: 60 })],
    ['refresh token class', c => jwt().sign({ userId: oid(c.users.A) }, process.env.JWT_REFRESH_SECRET, { expiresIn: 60 })],
  ]) reg(`socket signed token ${name}`, 'New connections must authenticate an active existing access-token subject.', async c => {
    const good = await connect(c, 'A'); await join(good, ids.channel); c.evidence.authorizedControl = true;
    const bad = await connect(c, 'A', { negative: true, auth: { token: token(c) } }); c.evidence.rejected = !bad.connected; return c.evidence.rejected;
  });
  reg('connected token expiry contrasted with fresh connection', 'Record documented handshake-only token expiry: expired tokens reject REST and fresh sockets; ongoing event writes require a session-expiry policy decision.', async c => {
    const observer = await connect(c, 'B');
    const exp = Math.floor(Date.now() / 1000) + 4;
    const token = jwt().sign({ userId: oid(c.users.A), exp }, process.env.JWT_SECRET);
    const a = await connect(c, 'A', { auth: { token } }); await availability(c, a, observer);
    await until(() => Date.now() >= exp * 1000 + 100, 'controlled token expiry', 6000);
    const denied = await c.http('anonymous', 'GET', '/api/users/me', undefined, `Bearer ${token}`); assert.equal(denied.status, 401);
    await connect(c, 'A', { negative: true, auth: { token } });
    const packets = collect(observer, 'presence_update', p => p.userId === oid(c.users.A) && p.availability?.status === 'in_ot');
    a.emit('update_availability', { status: 'in_ot' }); await wait(QUIET);
    c.evidence.expiredRestRejected = true; c.evidence.freshHandshakeRejected = true; c.evidence.eventsAfterExpiry = packets.length;
    c.evidence.writeAfterExpiry = (await c.models.User.findById(c.users.A._id)).availability.status === 'in_ot';
    return !c.evidence.writeAfterExpiry;
  }, 'session expiry policy / documented handshake-only authentication');
  for (const action of ['availability', 'join']) reg(`deactivation after connection blocks ${action}`, 'Deactivated users must lose protected socket actions even on an existing connection.', async c => {
    const b = await connect(c, 'B'); const a = await connect(c, 'A'); await availability(c, a, b);
    await c.models.User.updateOne({ _id: c.users.A._id }, { isActive: false });
    assert.equal((await c.http('A', 'GET', '/api/users/me')).status, 401);
    await connect(c, 'A', { negative: true }); c.evidence.restAndFreshHandshakeRejected = true;
    if (action === 'availability') {
      a.emit('update_availability', { status: 'in_icu' }); await wait(QUIET);
      c.evidence.inactiveWritePersisted = (await c.models.User.findById(c.users.A._id)).availability.status === 'in_icu'; return !c.evidence.inactiveWritePersisted;
    }
    const outcomes = collect(a, 'join_channel', p => p.channelId === ids.channel);
    a.emit('join_channel', { channelId: ids.channel }); await wait(QUIET);
    c.evidence.inactiveJoinAcknowledged = outcomes.some(p => p.success); return !c.evidence.inactiveJoinAcknowledged;
  });
  reg('logout device removal preserves documented stateless sessions', 'Logout removes only matching FCM device registration; current stateless access tokens/sockets keep their subject until expiry.', async c => {
    await c.models.User.updateOne({ _id: c.users.A._id }, { fcmTokens: ['ci-device-one', 'ci-device-two'] });
    const a1 = await connect(c, 'A'); const a2 = await connect(c, 'A'); const b = await connect(c, 'B');
    assert.equal((await c.http('A', 'POST', '/api/auth/logout', { fcmToken: 'ci-device-one' })).status, 200);
    await availability(c, a1, b); await availability(c, a2, b, 'in_ot'); const fresh = await connect(c, 'A');
    const user = await c.models.User.findById(c.users.A._id).lean();
    c.evidence.sessionContract = 'FCM deregistration; no access-token revocation'; c.evidence.devicesStillConnected = [a1.connected, a2.connected, fresh.connected];
    return user.fcmTokens.length === 1 && user.fcmTokens[0] === 'ci-device-two' && c.evidence.devicesStillConnected.every(Boolean);
  });
  reg('multi-device presence marks offline only at last disconnect', 'Disconnecting one device must not report an active second device offline.', async c => {
    const b = await connect(c, 'B'); const a1 = await connect(c, 'A'); const a2 = await connect(c, 'A'); await availability(c, a2, b);
    const offline = collect(b, 'presence_update', p => p.userId === oid(c.users.A) && p.isOnline === false);
    a1.disconnect(); await availability(c, a2, b, 'in_ot'); await wait(QUIET); c.evidence.offlineBeforeLastDevice = offline.length;
    const final = once(b, 'presence_update', p => p.userId === oid(c.users.A) && p.isOnline === false); a2.disconnect(); await final;
    c.evidence.finalOfflineDelivered = true; return c.evidence.offlineBeforeLastDevice === 0;
  });
  reg('presence cross-space privacy and snapshot isolation', 'Presence updates and sync snapshots must disclose only shared-space identities.', async c => {
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); const outsider = await connect(c, 'C');
    const packets = collect(outsider, 'presence_update', p => [oid(c.users.A), oid(c.users.B)].includes(p.userId));
    await availability(c, a, b);
    const synced = once(outsider, 'sync_space_rooms'); outsider.emit('sync_space_rooms'); await synced; await wait(QUIET);
    c.evidence.foreignPresenceEvents = packets.length; return packets.length === 0;
  });
  for (const sync of [false, true]) reg(`removed space member presence ${sync ? 'after sync' : 'before sync'}`, 'Removed members must not receive subsequent space presence, including after explicit room sync.', async c => {
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); await availability(c, a, b);
    assert.equal((await c.http('A', 'DELETE', `/api/spaces/${ids.space}/members/${oid(c.users.B)}`)).status, 200);
    assert.equal((await c.http('B', 'GET', `/api/spaces/${ids.space}/members`)).status, 403);
    if (sync) { const done = once(b, 'sync_space_rooms'); b.emit('sync_space_rooms'); const p = await done; assert.equal(p.spaceCount, 0); }
    const ownerDevice = await connect(c, 'A'); const packets = collect(b, 'presence_update', p => p.userId === oid(c.users.A) && p.availability?.status === 'in_ot');
    await availability(c, a, ownerDevice, 'in_ot'); await wait(QUIET);
    c.evidence.removedRecipientEvents = packets.length; return packets.length === 0;
  });
  reg('fresh socket after leave has no stale space audience', 'An explicit disconnect and new connection must drop revoked space audiences.', async c => {
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); await availability(c, a, b); b.disconnect();
    assert.equal((await c.http('B', 'POST', `/api/spaces/${ids.space}/leave`, {})).status, 200);
    const fresh = await connect(c, 'B'); const own = await connect(c, 'A'); const packets = collect(fresh, 'presence_update', p => p.userId === oid(c.users.A) && p.availability?.status === 'in_ot');
    await availability(c, a, own, 'in_ot'); await wait(QUIET); c.evidence.eventsAfterFreshConnection = packets.length; return packets.length === 0;
  });
  reg('private channel membership revocation evicts edit audience', 'A member removed from a private channel must not receive future edits through a previously joined room.', async c => {
    await c.models.Channel.updateOne({ _id: ids.channel }, { isPrivate: true, members: [c.users.A._id, c.users.B._id] });
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); await join(a, ids.channel); await join(b, ids.channel); await edit(c, b, ids.channel, ids.messageA);
    await c.models.Channel.updateOne({ _id: ids.channel }, { $pull: { members: c.users.B._id } });
    assert.equal((await c.http('B', 'GET', `/api/channels/${ids.channel}/messages`)).status, 403); await join(b, ids.channel, false);
    const packets = collect(b, 'message_updated', p => p.messageId === ids.messageA && p.content?.text === 'Private revocation canary');
    await edit(c, a, ids.channel, ids.messageA, 'A', 'Private revocation canary'); await wait(QUIET); c.evidence.eventsAfterRevocation = packets.length; return packets.length === 0;
  });
  reg('cached DM typing recipients respect participant removal', 'Typing personal-room recipient caches must not deliver to a removed DM participant after channel leave.', async c => {
    const p = await supervise(c); const opts = { base: p.base };
    const a = await connect(c, 'A', opts); const b = await connect(c, 'B', opts); const control = await connect(c, 'A', opts);
    await join(a, ids.dmAB); await join(control, ids.dmAB);
    const warm = once(b, 'user_typing', x => x.channelId === ids.dmAB); a.emit('typing_start', { channelId: ids.dmAB }); await warm;
    // B has not joined the channel yet: this control proves the personal-room
    // recipient lookup completed and warmed its cache before revocation.
    c.evidence.personalRoomCacheControl = true; await join(b, ids.dmAB);
    b.emit('leave_channel', { channelId: ids.dmAB }); const barrier = once(b, 'sync_space_rooms'); b.emit('sync_space_rooms'); await barrier;
    await c.models.Channel.updateOne({ _id: ids.dmAB }, { $pull: { members: c.users.B._id } });
    assert.equal((await p.http('B', 'GET', `/api/channels/${ids.dmAB}/messages`)).status, 403);
    const packets = collect(b, 'user_stopped_typing', x => x.channelId === ids.dmAB);
    const delivered = once(control, 'user_stopped_typing', x => x.channelId === ids.dmAB); a.emit('typing_stop', { channelId: ids.dmAB }); await delivered; await wait(QUIET);
    c.evidence.authorizedControl = true; c.evidence.removedPeerEvents = packets.length; return packets.length === 0;
  });
  for (const kind of ['space', 'DM']) reg(`full message delivery isolates ${kind} audience`, 'REST-produced message bodies must reach authorized viewers and no unrelated personal/channel/space rooms.', async c => {
    const channel = kind === 'DM' ? ids.dmAB : ids.channel;
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); const outsider = await connect(c, 'C'); await join(a, channel); await join(b, channel);
    const text = `Full ${kind} isolation canary`; const packets = collect(outsider, 'new_message', p => p.content?.text === text);
    const delivered = once(b, 'new_message', p => p.content?.text === text);
    const r = await c.http('A', 'POST', `/api/channels/${channel}/messages`, { content: { text } }); assert.equal(r.status, 201); assert.equal(oid(await delivered), oid(r.data.data.message));
    await wait(QUIET); c.evidence.authorizedControl = true; c.evidence.foreignMessageEvents = packets.length; return packets.length === 0;
  });
  reg('message request notification isolates recipient devices', 'A request notification must target only recipient personal rooms; both recipient devices receive the same controlled reference.', async c => {
    const h1 = await connect(c, 'H'); const h2 = await connect(c, 'H'); const a = await connect(c, 'A'); const sender = await connect(c, 'G');
    const packets = [...[a, sender].map(s => collect(s, 'new_notification', p => p.referenceType === 'MessageRequest'))];
    const h1p = once(h1, 'new_notification', p => p.referenceType === 'MessageRequest'); const h2p = once(h2, 'new_notification', p => p.referenceType === 'MessageRequest');
    const r = await c.http('G', 'POST', '/api/message-requests', { toUserId: oid(c.users.H), introMessage: 'Synthetic notification canary' }); assert.equal(r.status, 201);
    const controls = await Promise.all([h1p, h2p]); assert.ok(controls.every(p => oid(p.referenceId) === r.data.data.request.id)); await wait(QUIET);
    c.evidence.authorizedControl = true; c.evidence.recipientDeviceControls = controls.length; c.evidence.unrelatedEvents = packets.flat().length; return packets.flat().length === 0;
  });
  for (const event of ['typing_start', 'typing_stop']) reg(`authorized ${event} ignores forged identity fields`, 'Typing identity must come from the authenticated socket, never client resource/identity fields.', async c => {
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); await join(a, ids.channel); await join(b, ids.channel);
    const response = once(b, event === 'typing_start' ? 'user_typing' : 'user_stopped_typing', p => p.channelId === ids.channel);
    a.emit(event, { channelId: ids.channel, userId: oid(c.users.C), userName: 'Forged caller', spaceId: ids.otherSpace }); const p = await response;
    c.evidence.authorizedControl = true; c.evidence.returnedIdentityFields = Object.keys(p).sort();
    c.evidence.serverIdentityRetained = p.userId === oid(c.users.A) && (event === 'typing_start' ? p.userName === c.users.A.name : p.userName === undefined);
    return c.evidence.serverIdentityRetained;
  });
  reg('availability identity forgery cannot modify peer', 'Availability writes must bind the authenticated subject even with forged caller/space identity fields.', async c => {
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); const before = (await c.models.User.findById(c.users.B._id)).availability.status;
    const ready = once(b, 'presence_update', p => p.userId === oid(c.users.A) && p.availability?.status === 'in_ot');
    a.emit('update_availability', { status: 'in_ot', userId: oid(c.users.B), spaceIds: [ids.otherSpace] }); await ready;
    c.evidence.authorizedControl = true; return (await c.models.User.findById(c.users.A._id)).availability.status === 'in_ot' && (await c.models.User.findById(c.users.B._id)).availability.status === before;
  });
  reg('availability enum rejection preserves state', 'Unknown availability status must emit a bounded rejection and preserve stored availability.', async c => {
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); await availability(c, a, b);
    const rejected = once(a, 'error'); a.emit('update_availability', { status: 'super_admin' }); await rejected; c.evidence.rejectionReceived = true;
    return (await c.models.User.findById(c.users.A._id)).availability.status === 'on_call';
  });
  reg('repeated availability writes have no message notification effects', 'Replaying a permitted presence update must remain subject-scoped and create no messages/notifications.', async c => {
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); const before = await c.models.Message.countDocuments();
    for (let i = 0; i < 3; i++) await availability(c, a, b, i % 2 ? 'in_ot' : 'on_call');
    c.evidence.controlledReplays = 3; return await c.models.Message.countDocuments() === before && await c.models.Notification.countDocuments() === 0;
  });
  for (const event of ['join_channel', 'leave_channel', 'typing_start', 'typing_stop', 'update_availability']) reg(`malformed null ${event} cannot escape handler`, 'Malformed authenticated socket payloads must preserve process availability and be handled without uncaught exceptions/rejections.', async c => {
    const p = await supervise(c); const a = await connect(c, 'A', { base: p.base }); const b = await connect(c, 'B', { base: p.base }); await join(b, ids.channel); await availability(c, a, b);
    const before = JSON.stringify((await c.models.User.findById(c.users.A._id).lean()).availability);
    a.emit(event, null);
    await wait(QUIET);
    // A logged unhandled rejection may keep test-mode service alive; record that
    // separately from a proven uncaught-exception process exit.
    if (p.diagnostics.uncaughtExceptions) await until(() => p.child.exitCode !== null, 'process exit after uncaught exception');
    c.evidence.processExited = p.child.exitCode !== null; c.evidence.exitCode = p.child.exitCode;
    c.evidence.diagnostics = { ...p.diagnostics }; c.evidence.fixtureAvailabilityPreserved = JSON.stringify((await c.models.User.findById(c.users.A._id).lean()).availability) === before;
    if (!c.evidence.processExited) { const h = await p.http('anonymous', 'GET', '/health'); c.evidence.childHealthStatus = h.status; await edit(c, b, ids.channel, ids.messageA, 'A', 'Malformed control', p.http); }
    return !c.evidence.processExited && p.diagnostics.uncaughtExceptions === 0 && p.diagnostics.unhandledRejections === 0 && c.evidence.fixtureAvailabilityPreserved;
  }, 'malformed socket payload robustness / explicit process or rejection evidence');
  reg('malformed channel identifier rejects without process loss', 'Cast-invalid room identifiers must reject locally while valid channel controls continue to work.', async c => {
    const p = await supervise(c); const a = await connect(c, 'A', { base: p.base }); await join(a, 'not-an-object-id', false); await join(a, ids.channel); await edit(c, a, ids.channel, ids.messageA, 'A', 'Cast error control', p.http);
    c.evidence.childAlive = p.child.exitCode === null; return c.evidence.childAlive && p.diagnostics.uncaughtExceptions + p.diagnostics.unhandledRejections === 0;
  });
  for (const scenario of ['membership removal', 'user deactivation', 'expired token']) reg(`transport recovery revalidates ${scenario}`, 'Recovering a transport session must revalidate authorization before replaying protected events; fresh connection denial is an independent control.', async c => {
    const p = await supervise(c); const options = { base: p.base }; const a = await connect(c, 'A', options);
    let token = c.tokens.B, exp;
    if (scenario === 'expired token') { exp = Math.floor(Date.now() / 1000) + 4; token = jwt().sign({ userId: oid(c.users.B), exp }, process.env.JWT_SECRET); }
    const b = await connect(c, 'B', { ...options, auth: { token } }); await join(a, ids.channel); await join(b, ids.channel); await edit(c, b, ids.channel, ids.messageA, 'A', 'Recovery offset control', p.http);
    assert.ok(b._pid && b._lastOffset, 'Recovery protocol session and packet offset missing');
    const disconnected = once(b, 'disconnect'); b.io.engine.close(); await disconnected;
    if (scenario === 'membership removal') assert.equal((await p.http('A', 'DELETE', `/api/spaces/${ids.space}/members/${oid(c.users.B)}`)).status, 200);
    if (scenario === 'user deactivation') await c.models.User.updateOne({ _id: c.users.B._id }, { isActive: false });
    if (exp) await until(() => Date.now() >= exp * 1000 + 100, 'recovery token expiry', 6000);
    const rest = await p.http('B', 'GET', `/api/channels/${ids.channel}/messages`, undefined, `Bearer ${token}`); assert.equal(rest.status, scenario === 'membership removal' ? 403 : 401);
    const fresh = await connect(c, 'B', { ...options, negative: scenario !== 'membership removal', auth: { token } }); if (scenario === 'membership removal') await join(fresh, ids.channel, false);
    const text = 'Protected recovery replay canary'; const packets = collect(b, 'message_updated', x => x.messageId === ids.messageA && x.content?.text === text);
    await edit(c, a, ids.channel, ids.messageA, 'A', text, p.http);
    const outcome = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { remove(); reject(new Error('Recovery produced neither authentication nor rejection')); }, 5000);
      const remove = () => { clearTimeout(timer); b.off('authenticated', accepted); b.off('connect_error', denied); };
      const accepted = payload => { remove(); resolve({ authenticated: true, recovered: b.recovered, identityMatches: payload.userId === oid(c.users.B) }); };
      const denied = () => { remove(); resolve({ authenticated: false, recovered: false }); };
      b.on('authenticated', accepted); b.on('connect_error', denied); b.connect();
    });
    await wait(QUIET); c.evidence.recovery = outcome; c.evidence.deniedFreshControl = true; c.evidence.replayedProtectedEvents = packets.length;
    return packets.length === 0 && (!outcome.authenticated || (scenario === 'membership removal' && outcome.identityMatches));
  });
};
