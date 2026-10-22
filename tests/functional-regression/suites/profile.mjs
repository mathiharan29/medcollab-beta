import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { capturedOtp, users } from '../src/fixtures.mjs';

await runModule('profile', [{
  id: 'FR-PRO-01', module: 'PRO',
  run: async ({ request, inbox, db }) => {
    const phone = users.C.phone;
    await request('/api/auth/request-otp', { method: 'POST', body: { phone } });
    const first = await request('/api/auth/verify-otp', { method: 'POST', body: { phone, otp: await capturedOtp(inbox, phone) } });
    assert.equal(first.data.isNewUser, true);
    const token = first.data.accessToken;
    const before = await request('/api/users/me', { token });
    assert.equal(before.data.user.isOnboarded, false);
    await request('/api/spaces', { token, expectedStatus: 403 });
    const changed = await request('/api/users/me', { method: 'PUT', token, body: { name: 'Dr Synthetic New', role: 'intern', institution: 'Synthetic Institute' } });
    assert.equal(changed.data.user.isOnboarded, true);
    const me = await request('/api/users/me', { token });
    assert.equal(me.data.user.name, 'Dr Synthetic New');
    assert.equal(me.data.user.isOnboarded, true);
    const spaces = await request('/api/spaces', { token });
    assert.deepEqual(spaces.data.spaces, []);
    await request('/api/auth/request-otp', { method: 'POST', body: { phone } });
    const returning = await request('/api/auth/verify-otp', { method: 'POST', body: { phone, otp: await capturedOtp(inbox, phone) } });
    assert.equal(returning.data.isNewUser, false);
    assert.equal(returning.data.user._id, first.data.user._id);
    await db(async (connection) => {
      const stored = await connection.collection('users').findOne({ phone });
      assert.equal(stored.name, 'Dr Synthetic New');
      assert.equal(stored.isOnboarded, true);
    });
  },
}, {
  id: 'FR-PRO-02', module: 'PRO',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const valid = [
      ['name', 'N'.repeat(2)], ['name', 'N'.repeat(100)],
      ['bio', 'B'.repeat(300)], ['institution', 'I'.repeat(200)],
      ['pgYear', 1], ['pgYear', 6],
    ];
    for (const [field, value] of valid) {
      const changed = await request('/api/users/me', { method: 'PUT', token: a.token, body: { [field]: value } });
      assert.equal(changed.data.user[field], value);
      const read = await request('/api/users/me', { token: a.token });
      assert.equal(read.data.user[field], value);
    }
    const invalid = [
      ['name', 'N'.repeat(101)], ['bio', 'B'.repeat(301)], ['institution', 'I'.repeat(201)],
      ['pgYear', 0], ['pgYear', 7], ['role', 'fictional-role'],
    ];
    for (const [field, value] of invalid) {
      const before = (await request('/api/users/me', { token: a.token })).data.user[field];
      const rejected = await request('/api/users/me', { method: 'PUT', token: a.token, body: { [field]: value }, expectedStatus: 400 });
      assert.equal(rejected.payload.success, false);
      const after = (await request('/api/users/me', { token: a.token })).data.user[field];
      assert.equal(after, before, `Rejected ${field} update changed persisted profile`);
    }
    await db(async (connection) => {
      const stored = await connection.collection('users').findOne({ phone: a.phone });
      assert.equal(stored.name, 'N'.repeat(100));
      assert.equal(stored.bio, 'B'.repeat(300));
      assert.equal(stored.institution, 'I'.repeat(200));
      assert.equal(stored.pgYear, 6);
    });
  },
}, {
  id: 'FR-PRO-04', module: 'PRO',
  prerequisiteSeed: 'Existing A/B direct channel inserted directly to exercise profile projections; live direct-DM creation returns 500 on pinned upstream and is not credited here',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Profile Projection', type: 'department' }, expectedStatus: 201 })).data.space;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: space.inviteCode } });
    const dmId = await db(async (connection) => {
      const inserted = await connection.collection('channels').insertOne({
        spaceId: null, type: 'direct', members: [new connection.base.Types.ObjectId(a.userId), new connection.base.Types.ObjectId(b.userId)],
        createdBy: new connection.base.Types.ObjectId(a.userId), isArchived: false, createdAt: new Date(), updatedAt: new Date(),
      });
      return String(inserted.insertedId);
    });
    const changed = { displayTitle: 'Synthetic Consultant', speciality: 'Synthetic Cardiology', avatarUrl: 'https://example.invalid/synthetic-avatar.png', bio: 'Synthetic profile detail for regression' };
    const updated = await request('/api/users/me', { method: 'PUT', token: b.token, body: changed });
    for (const [field, value] of Object.entries(changed)) assert.equal(updated.data.user[field], value);
    const publicProfile = await request(`/api/users/${b.userId}`, { token: a.token });
    for (const [field, value] of Object.entries(changed)) assert.equal(publicProfile.data.user[field], value);
    const dmDetail = await request(`/api/channels/${dmId}`, { token: a.token });
    const dmPeer = dmDetail.data.channel.members.find((member) => member._id === b.userId);
    assert.ok(dmPeer, 'Updated peer must remain in the DM');
    for (const field of ['displayTitle', 'speciality', 'avatarUrl']) assert.equal(dmPeer[field], changed[field]);
    const dmMembers = await request(`/api/channels/${dmId}/members`, { token: a.token });
    const member = dmMembers.data.members.find((item) => item._id === b.userId);
    assert.ok(member);
    for (const field of ['displayTitle', 'speciality', 'avatarUrl']) assert.equal(member[field], changed[field]);
    const spaces = await request(`/api/spaces/${space._id}/members`, { token: a.token });
    const spaceMember = spaces.data.members.find((item) => item._id === b.userId);
    assert.ok(spaceMember);
    for (const field of ['displayTitle', 'speciality', 'avatarUrl']) assert.equal(spaceMember[field], changed[field]);
    await db(async (connection) => {
      const stored = await connection.collection('users').findOne({ phone: b.phone });
      for (const [field, value] of Object.entries(changed)) assert.equal(stored[field], value);
      const channel = await connection.collection('channels').findOne({ _id: new connection.base.Types.ObjectId(dmId) });
      assert.deepEqual(new Set(channel.members.map(String)), new Set([a.userId, b.userId]));
    });
  },
}, {
  id: 'FR-PRO-03', module: 'PRO',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const first = await request('/api/users/me', { method: 'PUT', token: a.token, body: { notifications: { mentions: false } } });
    assert.equal(first.data.user.notifications.mentions, false);
    const second = await request('/api/users/me', { method: 'PUT', token: a.token, body: { notifications: { handoffs: false } } });
    assert.equal(second.data.user.notifications.mentions, false);
    assert.equal(second.data.user.notifications.handoffs, false);
    const reread = await request('/api/users/me', { token: a.token });
    assert.equal(reread.data.user.notifications.mentions, false);
    assert.equal(reread.data.user.notifications.handoffs, false);
    const refreshed = await request('/api/auth/refresh', { method: 'POST', body: { refreshToken: a.refreshToken } });
    const relogin = await request('/api/users/me', { token: refreshed.data.accessToken });
    assert.equal(relogin.data.user.notifications.mentions, false);
    assert.equal(relogin.data.user.notifications.handoffs, false);
    await db(async (connection) => {
      const stored = await connection.collection('users').findOne({ phone: a.phone });
      assert.equal(stored.notifications.mentions, false);
      assert.equal(stored.notifications.handoffs, false);
    });
  },
}]);
