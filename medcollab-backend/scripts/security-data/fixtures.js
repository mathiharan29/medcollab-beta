'use strict';
const assert = require('node:assert/strict');
const { load, settled } = require('../security-media/fixtures');
function models() {
  const m = load();
  m.MessageRequest = require('../../src/features/message-requests/messageRequest.model');
  m.SupportTicket = require('../../src/features/support/support.controller').SupportTicket;
  return m;
}
async function context(m, api) {
  const ids = Object.fromEntries(Object.keys(m).map(n => [n, new Set()]));
  let sequence = 0;
  const c = { models: m, api, id: () => new (require('mongoose').Types.ObjectId)(`7ef${String(++sequence).padStart(21, '0')}`),
    track(name, id) { ids[name].add(String(id)); },
    async make(name, data) { const id = c.id(); c.track(name, id); return m[name].create({ ...data, _id: id }); },
    async snapshot() { return settled(m); },
    handoff() { return { spaceId: c.s._id, channelId: c.ch._id, fromUserId: c.A._id, toUserId: c.B._id, shiftDate: '2025-01-15', shiftType: 'morning', patients: [{ bedNumber: 'CI', clinicalAlias: 'Synthetic' }] }; },
    async cleanup() {
      // Exact identities only. Generated OTP/inbox side effects are scoped to
      // these synthetic users; never delete collection-wide or by namespace.
      await settled(m);
      const userIds = [c.A, c.B, c.C].filter(Boolean).map(u => u._id);
      const phones = [c.A, c.B, c.C].filter(Boolean).map(u => u.phone);
      for (const name of Object.keys(m)) {
        const clauses = [{ _id: { $in: [...ids[name]] } }];
        if (name === 'OTP') clauses.push({ phone: { $in: phones } });
        if (name === 'Notification') clauses.push({ userId: { $in: userIds } });
        await m[name].deleteMany({ $or: clauses });
        assert.equal(await m[name].countDocuments(), 0, 'Unregistered database residue');
      }
      return { exactSyntheticCleanup: true, residualDocuments: 0 };
    }
  };
  // Register cleanup before creating any fixture so partial fixture failures
  // also have an exact-resource journal.
  c.seed = async () => {
    for (const [i, actor] of ['A', 'B', 'C'].entries()) c[actor] = await c.make('User', { phone: `+15558880${String(i + 1).padStart(3, '0')}`, name: `Synthetic Data ${actor}`, role: 'consultant', isVerified: true, isOnboarded: true });
    c.s = await c.make('Space', { name: 'Synthetic Data AB', type: 'department', inviteCode: 'DATABA', createdBy: c.A._id, members: [{ userId: c.A._id, role: 'owner' }, { userId: c.B._id, role: 'member' }] });
    c.ch = await c.make('Channel', { name: 'synthetic-data', spaceId: c.s._id, createdBy: c.A._id });
    c.message = await c.make('Message', { channelId: c.ch._id, senderId: c.A._id, content: { text: 'synthetic base' } });
    await c.make('Handoff', c.handoff());
    await c.make('MessageRequest', { fromUserId: c.C._id, toUserId: c.B._id });
    await c.make('SupportTicket', { type: 'bug', title: 'Synthetic', description: 'Synthetic', userId: c.A._id });
    for (const actor of ['A', 'B']) c[`note${actor}`] = await c.make('Notification', { userId: c[actor]._id, type: 'mention', body: 'synthetic notification', referenceType: 'Message', referenceId: c.message._id });
    await c.make('OTP', { phone: c.A.phone, otpHash: await require('bcryptjs').hash('123456', 10), expiresAt: new Date(Date.now() + 300000) });
  };
  return c;
}
module.exports = { models, context };
