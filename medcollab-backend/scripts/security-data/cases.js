'use strict';
const assert = require('node:assert/strict');
const bcrypt = require('bcryptjs');
const cases = [];
function add(name, expected, scope, sources, run) {
  cases.push({ caseId: `VOCLE-${786 + cases.length}`, name, expected, scope, sources, run });
}
const user = 'src/features/users/user.model.js', otp = 'src/features/auth/otp.model.js';
const msg = 'src/features/messages/message.model.js', channel = 'src/features/channels/channel.model.js';
const space = 'src/features/spaces/space.model.js', handoff = 'src/features/handoffs/handoff.model.js';
const notification = 'src/features/notifications/notification.model.js';
const out = (secure, evidence) => ({ secure: !!secure, evidence });
add('Strict schemas discard unknown top-level and nested fields', 'Unknown fields cannot persist through normal model writes', 'model', [user, otp, msg, channel, space, handoff, notification, 'src/features/support/support.controller.js'], async c => {
  const checks = [];
  for (const [name, model] of Object.entries(c.models)) {
    const doc = await model.findOne();
    if (!doc) continue;
    await model.updateOne({ _id: doc._id }, { $set: { dataSecurityCanary: 'unknown' } });
    checks.push(!(await model.collection.findOne({ _id: doc._id })).dataSecurityCanary);
  }
  await c.models.User.updateOne({ _id: c.A._id }, { $set: { 'notifications.unknown': true, 'availability.unknown': true } });
  const m = await c.make('Message', { channelId: c.ch._id, senderId: c.A._id, content: { text: 'synthetic', unexpected: 'unknown' } });
  const h = await c.make('Handoff', { ...c.handoff(), patients: [{ bedNumber: 'CI', clinicalAlias: 'Synthetic', patientName: 'unknown', attachments: [{ url: 'https://example.invalid/synthetic', unknown: true }] }] });
  const u = await c.models.User.collection.findOne({ _id: c.A._id });
  const rawM = await c.models.Message.collection.findOne({ _id: m._id });
  const rawH = await c.models.Handoff.collection.findOne({ _id: h._id });
  const nestedUnknownPersisted = !!(u.notifications.unknown || u.availability.unknown || rawM.content.unexpected || rawH.patients[0].patientName || rawH.patients[0].attachments[0].unknown);
  return out(checks.every(Boolean) && !nestedUnknownPersisted, { modelsChecked: checks.length, topLevelUnknownPersisted: !checks.every(Boolean), nestedUnknownPersisted });
});
add('Profile allowlist preserves identity and security flags', 'Profile update cannot change phone, active/verified flags, device tokens or operator updates', 'HTTP', ['src/features/users/user.controller.js'], async c => {
  const r = await c.api('A', 'PUT', '/api/users/me', { bio: 'allowed canary', phone: c.B.phone, isActive: false, isVerified: false, fcmTokens: ['injected'], $set: { isActive: false }, unknown: true });
  assert.equal(r.status, 200);
  const u = await c.models.User.findById(c.A._id).lean();
  return out(u.phone === c.A.phone && u.isActive && u.isVerified && u.fcmTokens.length === 0 && u.bio === 'allowed canary' && !u.unknown, { status: r.status, identityPreserved: u.phone === c.A.phone, flagsPreserved: u.isActive && u.isVerified, injectedTokens: u.fcmTokens.length });
});
add('Nested preference updates merge siblings and strip unknown keys', 'Allowed toggle persists without unexpected keys or erasing sibling preferences', 'HTTP', [user, 'src/features/users/user.controller.js'], async c => {
  const r = await c.api('A', 'PUT', '/api/users/me', { notifications: { mentions: false, unknown: true, $where: 'synthetic' } });
  assert.equal(r.status, 200);
  const u = await c.models.User.findById(c.A._id).lean();
  return out(u.notifications.mentions === false && u.notifications.handoffs === true && !u.notifications.unknown && !u.notifications.$where, { status: r.status, siblingPreserved: u.notifications.handoffs === true, unknownPersisted: !!u.notifications.unknown });
});
add('Public profile and populated sender exclude phone/device credentials', 'Public responses omit phone and fcmTokens while retaining authorized profile data', 'HTTP', [user, 'src/features/messages/message.controller.js'], async c => {
  await c.models.User.updateOne({ _id: c.B._id }, { fcmTokens: ['synthetic-device-canary'] });
  const m = await c.make('Message', { channelId: c.ch._id, senderId: c.B._id, content: { text: 'synthetic' } });
  const p = await c.api('A', 'GET', `/api/users/${c.B._id}`);
  const r = await c.api('A', 'GET', `/api/channels/${c.ch._id}/messages`);
  assert.equal(p.status, 200); assert.equal(r.status, 200);
  const sender = r.data.data.messages.find(x => x._id === String(m._id)).senderId;
  return out(!('phone' in p.data.data.user) && !('fcmTokens' in p.data.data.user) && !('phone' in sender) && !('fcmTokens' in sender), { profileStatus: p.status, messagesStatus: r.status, senderProjected: !!sender.name });
});
add('Default model reads/serialization hide sensitive fields', 'Defense in depth: default model read and JSON omit device tokens and OTP hashes', 'model-hardening', [user, otp], async c => {
  await c.models.User.updateOne({ _id: c.A._id }, { fcmTokens: ['synthetic-device'] });
  const u = await c.models.User.findById(c.A._id);
  const o = await c.models.OTP.findOne({ phone: c.A.phone });
  const flags = { userJSONTokensVisible: 'fcmTokens' in u.toJSON(), userLeanTokensVisible: 'fcmTokens' in await c.models.User.findById(c.A._id).lean(), otpJSONHashVisible: 'otpHash' in o.toJSON() };
  return out(!Object.values(flags).some(Boolean), flags);
});
add('Operator-shaped body target cannot create a DM', 'Object-shaped identity input rejected without new channel or request', 'HTTP', ['src/features/channels/channel.routes.js', 'src/middleware/validate.js'], async c => {
  const before = await c.models.Channel.countDocuments();
  const r = await c.api('A', 'POST', '/api/channels/dm', { userId: { $ne: null } });
  return out(r.status === 400 && await c.models.Channel.countDocuments() === before, { status: r.status, channelCountUnchanged: await c.models.Channel.countDocuments() === before });
});
add('Bracket query input cannot broaden notification ownership', 'Real Express query parsing preserves fixed owner filter and does not execute bracket operators', 'HTTP', ['src/app.js', 'src/features/notifications/notification.controller.js'], async c => {
  const own = await c.api('A', 'GET', '/api/notifications?type=mention');
  const r = await c.api('A', 'GET', '/api/notifications?type[$ne]=synthetic&userId[$ne]=synthetic');
  assert.equal(own.status, 200); assert.equal(own.data.data.notifications.length, 1);
  assert.equal(r.status, 200);
  return out(r.data.data.notifications.length === 1 && r.data.data.notifications.every(n => n.userId === String(c.A._id)), { status: r.status, count: r.data.data.notifications.length, foreignRecords: r.data.data.notifications.filter(n => n.userId !== String(c.A._id)).length });
});
add('Malformed ObjectId and cursor reject without writes', 'Invalid route ID/cursor returns controlled denial and leaves domain data unchanged', 'HTTP', ['src/middleware/validate.js', 'src/middleware/errorHandler.js'], async c => {
  const before = await c.snapshot();
  const r = await c.api('A', 'GET', '/api/users/not-an-id');
  const q = await c.api('A', 'GET', '/api/notifications?before=not-an-id');
  return out(r.status === 400 && q.status === 400 && before === await c.snapshot(), { idStatus: r.status, cursorStatus: q.status, stateUnchanged: before === await c.snapshot() });
});
add('Concurrent phone insertion is constrained by actual unique index', 'Exactly one insert succeeds and duplicate receives MongoDB 11000', 'database-index', [user], async c => {
  const results = await Promise.allSettled([c.make('User', { phone: '+15558880999' }), c.make('User', { phone: '+15558880999' })]);
  const successes = results.filter(x => x.status === 'fulfilled').length;
  const duplicates = results.filter(x => x.status === 'rejected' && x.reason.code === 11000).length;
  return out(successes === 1 && duplicates === 1, { successes, duplicates });
});
add('Concurrent invite insertion is constrained by actual unique index', 'Exactly one space can hold the same inviteCode', 'database-index', [space], async c => {
  const data = { name: 'Synthetic duplicate', type: 'department', inviteCode: 'DUPLAA', createdBy: c.A._id };
  const r = await Promise.allSettled([c.make('Space', data), c.make('Space', data)]);
  return out(r.filter(x => x.status === 'fulfilled').length === 1 && r.some(x => x.status === 'rejected' && x.reason.code === 11000), { successes: r.filter(x => x.status === 'fulfilled').length, duplicateKeyErrors: r.filter(x => x.status === 'rejected' && x.reason.code === 11000).length });
});
add('Canonical DM key serializes concurrent atomic upserts', 'Canonical pair order and partial unique index produce one pair channel', 'database-index', [channel, 'src/features/channels/channel.controller.js'], async c => {
  const { Channel } = c.models; const key = Channel.directMemberKey(c.A._id, c.B._id);
  const create = () => Channel.findOneAndUpdate({ type: 'direct', directKey: key }, { $setOnInsert: { type: 'direct', directKey: key, members: [c.A._id, c.B._id], createdBy: c.A._id } }, { upsert: true, new: true });
  const r = await Promise.allSettled([create(), create()]);
  const docs = await Channel.find({ directKey: key }); docs.forEach(d => c.track('Channel', d._id));
  const index = (await Channel.collection.indexes()).find(x => x.key.directKey === 1);
  return out(r.every(x => x.status === 'fulfilled') && docs.length === 1 && key === Channel.directMemberKey(c.B._id, c.A._id) && index.unique === true && !!index.partialFilterExpression, { successes: r.filter(x => x.status === 'fulfilled').length, pairChannels: docs.length, uniquePartialIndex: !!index.unique && !!index.partialFilterExpression });
});
add('Pending request pair duplicates are constrained at data layer', 'Defense in depth: duplicate active request pair cannot persist', 'model-hardening', ['src/features/message-requests/messageRequest.model.js', 'src/features/message-requests/messageRequest.controller.js'], async c => {
  const d = { fromUserId: c.A._id, toUserId: c.B._id };
  const r = await Promise.allSettled([c.make('MessageRequest', d), c.make('MessageRequest', d)]);
  const count = await c.models.MessageRequest.countDocuments({ ...d, status: 'pending' });
  return out(count === 1, { successfulInserts: r.filter(x => x.status === 'fulfilled').length, pendingPairs: count, scope: 'direct model concurrency; HTTP race not claimed' });
});
add('OTP creator persists bcrypt only and removes raw input', 'Persisted hash matches synthetic code and raw OTP field is absent', 'model', [otp], async c => {
  const o = await c.models.OTP.createOtp(c.A.phone, '234567'); c.track('OTP', o._id);
  const raw = await c.models.OTP.collection.findOne({ _id: o._id });
  const match = await bcrypt.compare('234567', raw.otpHash);
  return out(match && raw.otpHash !== '234567' && !('otp' in raw) && /^\$2[ab]\$10\$/.test(raw.otpHash), { bcryptMatches: match, rawCodeStored: raw.otpHash === '234567' || 'otp' in raw, cost10: /^\$2[ab]\$10\$/.test(raw.otpHash) });
});
add('Expired OTP denied before physical TTL deletion', 'Verifier excludes an expired record still present in MongoDB', 'model', [otp], async c => {
  const o = await c.models.OTP.findOne({ phone: c.A.phone });
  await c.models.OTP.updateOne({ _id: o._id }, { expiresAt: new Date(Date.now() - 1000) });
  assert.ok(await c.models.OTP.exists({ _id: o._id }));
  const r = await c.models.OTP.verifyOtp(c.A.phone, '123456');
  return out(!r.valid, { denied: !r.valid, recordPresentBeforeVerification: true });
});
add('OTP attempt cap and sequential consumption preserve single use', 'Third wrong attempt exhausts code; valid code deletes record and cannot replay', 'model', [otp], async c => {
  for (let i = 0; i < 3; i++) assert.equal((await c.models.OTP.verifyOtp(c.A.phone, '999999')).valid, false);
  const exhausted = await c.models.OTP.verifyOtp(c.A.phone, '123456');
  const o = await c.models.OTP.createOtp(c.A.phone, '234567'); c.track('OTP', o._id);
  const good = await c.models.OTP.verifyOtp(c.A.phone, '234567');
  const replay = await c.models.OTP.verifyOtp(c.A.phone, '234567');
  return out(!exhausted.valid && good.valid && !replay.valid && !await c.models.OTP.exists({ _id: o._id }), { attemptCapDenial: !exhausted.valid, firstAccepted: good.valid, replayAccepted: replay.valid, consumedDeleted: !await c.models.OTP.exists({ _id: o._id }), concurrencyCoveredBy: 'VOCLE-687 (historical)' });
});
add('OTP replacement invalidates previous unconsumed record', 'New OTP marks old record used and only newest code verifies', 'model', [otp], async c => {
  const old = await c.models.OTP.findOne({ phone: c.A.phone });
  const o = await c.models.OTP.createOtp(c.A.phone, '234567'); c.track('OTP', o._id);
  const used = (await c.models.OTP.findById(old._id)).isUsed;
  const rejected = !(await c.models.OTP.verifyOtp(c.A.phone, '123456')).valid;
  const accepted = (await c.models.OTP.verifyOtp(c.A.phone, '234567')).valid;
  return out(used && rejected && accepted, { previousMarkedUsed: used, oldDenied: rejected, newestAccepted: accepted });
});
add('Actual OTP and notification TTL indexes match expiry field', 'Both collections have expiresAt ascending TTL with expireAfterSeconds zero', 'database-index', [otp, notification], async c => {
  const indexes = [];
  for (const name of ['OTP', 'Notification']) {
    const index = (await c.models[name].collection.indexes()).find(x => x.key.expiresAt === 1);
    indexes.push({ model: name, exists: !!index, expireAfterSeconds: index?.expireAfterSeconds });
  }
  return out(indexes.every(x => x.exists && x.expireAfterSeconds === 0), { indexes, timingClaim: 'TTL timing is not an authorization oracle' });
});
add('Expired notification excluded before asynchronous TTL cleanup', 'Policy candidate: expired inbox item is not served or counted while awaiting TTL deletion', 'HTTP-policy', [notification, 'src/features/notifications/notification.controller.js'], async c => {
  await c.models.Notification.updateOne({ _id: c.noteA._id }, { expiresAt: new Date(Date.now() - 1000) });
  assert.ok(await c.models.Notification.exists({ _id: c.noteA._id }));
  const r = await c.api('A', 'GET', '/api/notifications'); assert.equal(r.status, 200);
  const present = r.data.data.notifications.some(n => n._id === String(c.noteA._id));
  return out(!present && r.data.data.unreadCount === 0, { expiredVisible: present, unreadCount: r.data.data.unreadCount, status: r.status, defaultRetentionDays: Math.round((c.noteB.expiresAt - c.noteB.createdAt) / 86400000) });
});
add('Soft deletion blanks content and reactions on persisted message', 'Save deletion hook blanks text/media and records deletion timestamp', 'model', [msg], async c => {
  const m = await c.make('Message', { channelId: c.ch._id, senderId: c.A._id, content: { text: 'synthetic sensitive canary', mediaUrl: 'https://example.invalid/synthetic' }, reactions: [{ emoji: 'X', userIds: [c.B._id] }] });
  m.isDeleted = true; await m.save();
  const raw = await c.models.Message.findById(m._id).lean();
  return out(raw.isDeleted && !!raw.deletedAt && raw.content.text === 'This message was deleted' && raw.content.mediaUrl === null && raw.reactions.length === 0, { deletionFlag: raw.isDeleted, deletedAtSet: !!raw.deletedAt, mediaBlanked: raw.content.mediaUrl === null, reactions: raw.reactions.length });
});
add('Editing a deleted message cannot restore stored text', 'Deleted message update is denied and placeholder content remains unchanged', 'HTTP', [msg, 'src/features/messages/message.controller.js'], async c => {
  const live = await c.make('Message', { channelId: c.ch._id, senderId: c.A._id, content: { text: 'live control' } });
  assert.equal((await c.api('A', 'PUT', `/api/channels/${c.ch._id}/messages/${live._id}`, { content: { text: 'valid edit control' } })).status, 200);
  const m = await c.make('Message', { channelId: c.ch._id, senderId: c.A._id, content: { text: 'delete canary' } });
  assert.equal((await c.api('A', 'DELETE', `/api/channels/${c.ch._id}/messages/${m._id}`)).status, 200);
  assert.equal((await c.models.Message.findById(m._id)).content.text, 'This message was deleted');
  const r = await c.api('A', 'PUT', `/api/channels/${c.ch._id}/messages/${m._id}`, { content: { text: 'restored synthetic canary' } });
  const raw = await c.models.Message.findById(m._id).lean();
  return out([400, 403, 404, 409].includes(r.status) && raw.content.text === 'This message was deleted', { liveEditStatus: 200, deletionStatus: 200, deletedEditStatus: r.status, isDeleted: raw.isDeleted, deletedAtSet: !!raw.deletedAt, deletedTextRestored: raw.content.text === 'restored synthetic canary' });
});
add('Deletion removes denormalized quote and channel text copies', 'Policy candidate: delete scrubs copied previews as well as original content', 'model-policy', [msg, channel, 'src/features/messages/message.controller.js'], async c => {
  const m = await c.make('Message', { channelId: c.ch._id, senderId: c.A._id, content: { text: 'snapshot canary' } });
  const quoted = await c.make('Message', { channelId: c.ch._id, senderId: c.B._id, content: { text: 'quote synthetic' }, replyTo: { messageId: m._id, text: 'snapshot canary' } });
  await c.models.Channel.updateOne({ _id: c.ch._id }, { lastMessage: { messageId: m._id, text: 'snapshot canary' } });
  assert.equal((await c.api('A', 'DELETE', `/api/channels/${c.ch._id}/messages/${m._id}`)).status, 200);
  const quoteRetained = (await c.models.Message.findById(quoted._id)).replyTo.text === 'snapshot canary';
  const channelRetained = (await c.models.Channel.findById(c.ch._id)).lastMessage.text === 'snapshot canary';
  return out(!quoteRetained && !channelRetained, { quoteRetained, channelRetained, sourceIntent: 'quote snapshot preservation is explicit; retention policy unresolved' });
});
add('Stale private-channel membership cannot bypass removed space membership', 'After owner removes member, REST message read denies despite stale channel array', 'HTTP', ['src/features/spaces/space.controller.js', 'src/utils/channelAccess.js'], async c => {
  const privateCh = await c.make('Channel', { spaceId: c.s._id, createdBy: c.A._id, name: 'synthetic-private', isPrivate: true, members: [c.A._id, c.B._id] });
  assert.equal((await c.api('B', 'GET', `/api/channels/${privateCh._id}/messages`)).status, 200);
  assert.equal((await c.api('A', 'DELETE', `/api/spaces/${c.s._id}/members/${c.B._id}`)).status, 200);
  const retained = (await c.models.Channel.findById(privateCh._id)).members.some(x => String(x) === String(c.B._id));
  const r = await c.api('B', 'GET', `/api/channels/${privateCh._id}/messages`);
  return out(r.status === 403 && r.data.data == null, { previouslyAuthorized: true, staleChannelMember: retained, readStatus: r.status, payloadAbsent: r.data.data == null });
});
add('Inactive space blocks protected channel read', 'Policy candidate: inactive space membership cannot authorize channel data', 'HTTP-policy', ['src/utils/channelAccess.js', space], async c => {
  await c.make('Message', { channelId: c.ch._id, senderId: c.A._id, content: { text: 'inactive-space synthetic' } });
  assert.equal((await c.api('B', 'GET', `/api/channels/${c.ch._id}/messages`)).status, 200);
  await c.models.Space.updateOne({ _id: c.s._id }, { isActive: false });
  const r = await c.api('B', 'GET', `/api/channels/${c.ch._id}/messages`);
  return out([403, 404].includes(r.status), { status: r.status, returnedMessages: r.data.data?.messages?.length || 0, deactivationOrigin: 'model-seeded; no space deactivation endpoint exists' });
});
add('Missing resource references are rejected at model boundary', 'Defense in depth: required ObjectId refs must point to existing related resources', 'model-hardening', [msg, handoff, notification], async c => {
  const absent = c.id();
  assert.equal(await c.models.Channel.exists({ _id: absent }), null);
  const probes = await Promise.allSettled([
    c.make('Message', { channelId: absent, senderId: c.A._id, content: { text: 'synthetic orphan' } }),
    c.make('Handoff', { ...c.handoff(), channelId: absent }),
  ]);
  for (const p of probes) if (p.status === 'rejected') assert.ok(['ValidationError', 'MongoServerError'].includes(p.reason.name), 'Unexpected reference probe failure');
  const persisted = [];
  for (const [i, p] of probes.entries()) persisted.push(p.status === 'fulfilled' && !!await c.models[i ? 'Handoff' : 'Message'].exists({ _id: p.value._id }));
  return out(!persisted.some(Boolean), { orphanMessagePersisted: persisted[0], orphanHandoffPersisted: persisted[1], scope: 'model writes only; refs are not foreign keys' });
});
add('Routed acknowledgement rejects oversized note and preserves state', 'Route-level validation compensates for update validators omitted in controller', 'HTTP', ['src/features/handoffs/handoff.routes.js', 'src/features/handoffs/handoff.controller.js'], async c => {
  const h = await c.make('Handoff', { ...c.handoff(), status: 'submitted' });
  const r = await c.api('B', 'POST', `/api/handoffs/${h._id}/acknowledge`, { note: 'x'.repeat(501) });
  const raw = await c.models.Handoff.findById(h._id);
  return out(r.status === 400 && raw.status === 'submitted' && raw.acknowledgementNote === '', { status: r.status, statePreserved: raw.status === 'submitted' && raw.acknowledgementNote === '' });
});
add('Deactivated and deleted user records invalidate fresh HTTP credentials', 'HTTP authentication consults live user state rather than trusting JWT alone', 'HTTP', ['src/middleware/auth.js'], async c => {
  assert.equal((await c.api('B', 'GET', '/api/users/me')).status, 200);
  await c.models.User.updateOne({ _id: c.B._id }, { isActive: false });
  const inactive = await c.api('B', 'GET', '/api/users/me');
  await c.models.User.deleteOne({ _id: c.B._id });
  const deleted = await c.api('B', 'GET', '/api/users/me');
  return out(inactive.status === 401 && deleted.status === 401, { inactiveStatus: inactive.status, deletedStatus: deleted.status, existingSocketEvidence: 'VOCLE-654/655 (historical)' });
});
add('Notification writes bind ID and owner and preserve foreign record', 'Foreign notification read/delete denied; own update succeeds', 'HTTP', ['src/features/notifications/notification.controller.js'], async c => {
  const before = JSON.stringify(await c.models.Notification.findById(c.noteB._id).lean());
  const read = await c.api('A', 'PUT', `/api/notifications/${c.noteB._id}/read`);
  const del = await c.api('A', 'DELETE', `/api/notifications/${c.noteB._id}`);
  const own = await c.api('A', 'PUT', `/api/notifications/${c.noteA._id}/read`);
  return out(read.status === 404 && del.status === 404 && own.status === 200 && before === JSON.stringify(await c.models.Notification.findById(c.noteB._id).lean()), { foreignReadStatus: read.status, foreignDeleteStatus: del.status, ownReadStatus: own.status, foreignStatePreserved: before === JSON.stringify(await c.models.Notification.findById(c.noteB._id).lean()) });
});
add('Support write derives identity and status from authenticated user', 'Caller cannot mass assign support owner, phone or triage state', 'HTTP', ['src/features/support/support.controller.js'], async c => {
  const r = await c.api('A', 'POST', '/api/support/bug', { title: 'Synthetic support', description: 'Synthetic only', userId: String(c.B._id), userPhone: c.B.phone, status: 'closed' });
  assert.equal(r.status, 201); c.track('SupportTicket', r.data.data.ticketId);
  const t = await c.models.SupportTicket.findById(r.data.data.ticketId);
  return out(String(t.userId) === String(c.A._id) && t.userPhone === c.A.phone && t.status === 'open', { status: r.status, ownerBound: String(t.userId) === String(c.A._id), phoneDerived: t.userPhone === c.A.phone, state: t.status });
});
add('FCM instance method deduplicates and caps device tokens', 'Seven sequential registrations persist latest five distinct tokens', 'model', [user], async c => {
  for (let i = 0; i < 7; i++) await (await c.models.User.findById(c.A._id)).addFcmToken(`synthetic-${i}`);
  await (await c.models.User.findById(c.A._id)).addFcmToken('synthetic-6');
  const u = await c.models.User.findById(c.A._id);
  return out(u.fcmTokens.length === 5 && new Set(u.fcmTokens).size === 5 && u.fcmTokens[0] === 'synthetic-6' && !u.fcmTokens.includes('synthetic-0'), { tokens: u.fcmTokens.length, distinct: new Set(u.fcmTokens).size, newestFirst: u.fcmTokens[0] === 'synthetic-6' });
});
add('Device token cannot remain bound to two accounts', 'Policy candidate: device token registration has a defined account-transfer boundary', 'model-policy', [user, 'src/features/users/user.controller.js'], async c => {
  await c.A.addFcmToken('synthetic-shared-device'); await c.B.addFcmToken('synthetic-shared-device');
  const count = await c.models.User.countDocuments({ fcmTokens: 'synthetic-shared-device' });
  return out(count === 1, { accountsWithSameSyntheticToken: count, scope: 'model sequential registration; provider delivery not executed' });
});
add('Socket availability write enforces schema note limit', 'Socket update rejects oversized note without persisting invalid availability', 'handler', ['src/socket/handlers/presence.handler.js', user], async c => {
  const { registerPresenceHandlers } = require('../../src/socket/handlers/presence.handler');
  const events = new Map(), errors = [];
  const socket = { userId: c.A._id, userName: 'Synthetic', id: 'data-probe', rooms: new Set(), join() {}, emit(event) { errors.push(event); }, on(event, callback) { events.set(event, callback); } };
  const io = { to() { return { emit() {} }; } };
  registerPresenceHandlers(io, socket);
  // Await initial presence read before exercising/cleaning the handler.
  await new Promise(resolve => setTimeout(resolve, 50));
  try {
    await events.get('update_availability')({ status: 'on_call', note: 'x'.repeat(101) });
    const u = await c.models.User.findById(c.A._id);
    return out(u.availability.note.length <= 100, { persistedNoteLength: u.availability.note.length, emittedErrors: errors.length, transport: 'direct real handler with synthetic socket; MongoDB is real' });
  } finally { events.get('disconnect')('test cleanup'); }
});
const manifest = { schemaVersion: 1, count: cases.length, baselineCount: 785, combinedCatalogCount: 785 + cases.length, cases: cases.map(({ run, ...entry }) => entry) };
module.exports = { cases, manifest };
