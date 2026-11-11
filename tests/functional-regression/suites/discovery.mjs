import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';

await runModule('discovery', [{
  id: 'FR-DISC-01', module: 'DISC',
  prerequisiteSeed: 'Accepted A/C request inserted directly to represent an existing peer relationship',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C'), d = await identity('D'), e = await identity('E');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Discovery', type: 'department' }, expectedStatus: 201 })).data.space;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: space.inviteCode } });
    await request('/api/users/me', { method: 'PUT', token: d.token, body: { notifications: { allowMessageRequestsFromAnyone: true } } });
    await db(async (connection) => connection.collection('messagerequests').insertOne({ fromUserId: new connection.base.Types.ObjectId(a.userId), toUserId: new connection.base.Types.ObjectId(c.userId), status: 'accepted', createdAt: new Date(), updatedAt: new Date() }));
    const lookup = async (person) => {
      const byPhone = (await request(`/api/users/lookup?phone=${encodeURIComponent(person.phone)}`, { token: a.token })).data;
      const byId = (await request(`/api/users/${person.userId}/relationship`, { token: a.token })).data;
      const { user: phoneProfile, ...phoneRelationship } = byPhone;
      const { user: idProfile, ...idRelationship } = byId;
      assert.deepEqual(idRelationship, phoneRelationship);
      assert.equal(phoneProfile._id, person.userId);
      assert.equal(idProfile._id, person.userId);
      return byId;
    };
    const self = await lookup(a);
    assert.equal(self.isSelf, true);
    assert.equal(self.canMessage, true);
    assert.equal(self.canRequest, false);
    const shared = await lookup(b);
    assert.equal(shared.relationship, 'group_member');
    assert.equal(shared.sharesGroup, true);
    assert.equal(shared.canMessage, false);
    assert.equal(shared.canRequest, true);
    const accepted = await lookup(c);
    assert.equal(accepted.relationship, 'known');
    assert.equal(accepted.canMessage, true);
    assert.equal(accepted.canRequest, false);
    const optedIn = await lookup(d), optedOut = await lookup(e);
    assert.equal(optedIn.relationship, 'stranger');
    assert.equal(optedIn.canRequest, true);
    assert.equal(optedOut.relationship, 'stranger');
    assert.equal(optedOut.canRequest, true);
    assert.equal(optedOut.canMessage, false, 'Open requests do not open a DM');
    assert.equal(optedOut.pendingRequest, null);
    await request('/api/channels/dm', { method: 'POST', token: a.token, body: { userId: e.userId }, expectedStatus: 403 });
    await db(async (connection) => {
      const saved = await connection.collection('spaces').findOne({ _id: new connection.base.Types.ObjectId(space._id) });
      assert.deepEqual(new Set(saved.members.map((item) => String(item.userId))), new Set([a.userId, b.userId]));
    });
  },
}, {
  id: 'FR-DISC-03', module: 'DISC',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C'), d = await identity('D'), e = await identity('E');
    const s1 = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Search One', type: 'department' }, expectedStatus: 201 })).data.space;
    const s2 = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Search Two', type: 'department' }, expectedStatus: 201 })).data.space;
    await request('/api/spaces/join', { method: 'POST', token: b.token, body: { inviteCode: s1.inviteCode } });
    for (const person of [c, d]) await request('/api/spaces/join', { method: 'POST', token: person.token, body: { inviteCode: s2.inviteCode } });
    for (const [person, body] of [
      [b, { name: 'Dr C++ One' }], [c, { vocleUsername: 'synthetic_profx' }],
      [d, { speciality: 'Heart (Echo)' }], [e, { name: 'Dr C++ Outside', institution: 'Outside (Research)' }],
    ]) await request('/api/users/me', { method: 'PUT', token: person.token, body });
    const search = async (q, spaceId, expectedStatus = 200) => request(`/api/users/search?q=${encodeURIComponent(q)}${spaceId ? `&spaceId=${spaceId}` : ''}`, { token: a.token, expectedStatus });
    const short = await search('c', null, 400);
    assert.equal(short.payload.success, false);
    assert.match(short.payload.message, /at least 2/i);
    const two = await search('Dr');
    assert.ok(two.data.users.some((user) => user._id === b.userId));
    const punctuation = await search('  c++  ');
    assert.deepEqual(punctuation.data.users.map((user) => [user._id, user.isKnown]), [[b.userId, true], [e.userId, false]]);
    const handle = await search('  @SyNtHeTiC_PrOfX  ');
    assert.deepEqual(handle.data.users.map((user) => user._id), [c.userId]);
    assert.deepEqual((await search('outside (research)')).data.users.map((user) => user._id), [e.userId]);
    const speciality = await search('HEART (echo)');
    assert.deepEqual(speciality.data.users.map((user) => user._id), [d.userId]);
    const inS2 = await search('@synthetic_profx', s2._id);
    assert.deepEqual(inS2.data.users.map((user) => user._id), [c.userId]);
    const excluded = await search('C++', s2._id);
    assert.deepEqual(excluded.data.users, []);
    const fullPhone = await search(e.phone);
    assert.deepEqual(fullPhone.data.users.map((user) => user._id), [e.userId]);
    assert.ok(!Object.hasOwn(fullPhone.data.users[0], 'phone'));
    const partialPhone = await search(e.phone.slice(-4));
    assert.ok(!partialPhone.data.users.some((user) => user._id === e.userId));
    const knownPhone = await search(b.phone.slice(-4));
    assert.ok(knownPhone.data.users.some((user) => user._id === b.userId && !Object.hasOwn(user, 'phone')));
    await db(async (connection) => {
      const saved = await connection.collection('users').find({ _id: { $in: [b, c, d, e].map((user) => new connection.base.Types.ObjectId(user.userId)) } }).toArray();
      assert.equal(saved.length, 4);
      assert.equal(saved.find((user) => String(user._id) === c.userId).vocleUsername, 'synthetic_profx');
      const filtered = await connection.collection('spaces').findOne({ _id: new connection.base.Types.ObjectId(s2._id) });
      assert.deepEqual(new Set(filtered.members.map((member) => String(member.userId))), new Set([a.userId, c.userId, d.userId]));
    });
  },
}, {
  id: 'FR-DISC-04', module: 'DISC',
  prerequisiteSeed: 'Twenty-six eligible and two ineligible synthetic users inserted directly as search fixtures, then added to a test space',
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Search Limit', type: 'department' }, expectedStatus: 201 })).data.space;
    const eligibleIds = await db(async (connection) => {
      const makeUser = (index, overrides = {}) => ({
        phone: `+120255503${String(index).padStart(2, '0')}`,
        name: `Synthetic Limit ${String(index).padStart(2, '0')}`,
        role: 'intern', institution: 'Vocle Synthetic Institute',
        isVerified: true, isOnboarded: true, isActive: true,
        createdAt: new Date(), updatedAt: new Date(), ...overrides,
      });
      const users = Array.from({ length: 26 }, (_, index) => makeUser(index + 1));
      users.push(makeUser(27, { name: 'Synthetic Limit 00 Inactive', isActive: false }), makeUser(28, { name: 'Synthetic Limit 00 Incomplete', isOnboarded: false }));
      const inserted = await connection.collection('users').insertMany(users);
      const ids = Object.values(inserted.insertedIds);
      assert.equal(ids.length, 28);
      const joinedAt = new Date();
      const changed = await connection.collection('spaces').updateOne(
        { _id: new connection.base.Types.ObjectId(space._id) },
        { $push: { members: { $each: ids.map((userId) => ({ userId, role: 'member', joinedAt, isMuted: false })) } } },
      );
      assert.equal(changed.modifiedCount, 1);
      return ids.slice(0, 26).map(String);
    });
    const result = await request(`/api/users/search?q=${encodeURIComponent('Synthetic Limit')}`, { token: a.token });
    const found = result.data.users.map((user) => user._id);
    assert.equal(found.length, 25, 'Search must enforce the 25-result cap');
    assert.equal(new Set(found).size, 25, 'Search must not duplicate users');
    for (const id of found) assert.ok(eligibleIds.includes(id), `Ineligible or unknown user leaked into search: ${id}`);
    await db(async (connection) => {
      const stored = await connection.collection('users').find({ name: /^Synthetic Limit/ }).toArray();
      assert.equal(stored.length, 28);
      assert.equal(stored.filter((user) => user.isActive && user.isOnboarded).length, 26);
      const savedSpace = await connection.collection('spaces').findOne({ _id: new connection.base.Types.ObjectId(space._id) });
      assert.equal(savedSpace.members.length, 29);
    });
  },
}, {
  id: 'FR-DISC-02', module: 'DISC',
  prerequisiteSeed: 'Synthetic Indian-format contact is seeded to test the address-book matching contract independently of OTP',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B');
    for (const variant of ['+12025550102', '+1 (202) 555-0102', '12025550102']) {
      const result = await request(`/api/users/lookup?phone=${encodeURIComponent(variant)}`, { token: a.token });
      assert.equal(result.data.user._id, b.userId);
    }
    for (const malformed of ['abc', '123']) {
      const result = await request(`/api/users/lookup?phone=${encodeURIComponent(malformed)}`, { token: a.token, expectedStatus: 400 });
      assert.equal(result.payload.success, false);
    }
    const absent = await request(`/api/users/lookup?phone=${encodeURIComponent('+12025550999')}`, { token: a.token, expectedStatus: 404 });
    assert.equal(absent.payload.success, false);
    await db(async (connection) => {
      const users = await connection.collection('users').find({ phone: b.phone }).toArray();
      assert.equal(users.length, 1);
      assert.equal(String(users[0]._id), b.userId);
    });
    const fixture = await db(async (connection) => {
      const users = connection.collection('users');
      const contact = { name: 'Dr Synthetic Contact', phone: '+912025550177', role: 'intern', isOnboarded: true, isActive: true };
      const created = await users.insertOne({ ...contact });
      const inactive = await users.insertOne({ ...contact, name: 'Dr Synthetic Inactive', phone: '+912025550178', isActive: false });
      return { activeId: created.insertedId, inactiveId: inactive.insertedId };
    });
    const contactPhone = '(202) 555-0177';
    const contactPath = '/api/users/contacts/match';
    const contactNumbers = [contactPhone, '+912025550177', '+912025550178', '2025550199', 'invalid', null];
    const matched = await request(contactPath, { method: 'POST', token: a.token, body: { phones: contactNumbers } });
    assert.deepEqual(matched.data.matches.map((item) => item.user._id), [String(fixture.activeId)]);
    const [match] = matched.data.matches;
    assert.equal(match.contactPhone, contactPhone);
    assert.equal(match.canMessage, false);
    assert.equal(match.pendingRequest, null);
    assert.ok(!Object.hasOwn(match.user, 'phone'));
    const atLimit = await request(contactPath, { method: 'POST', token: a.token, body: { phones: Array(3000).fill(contactPhone) } });
    assert.deepEqual(atLimit.data.matches.map((item) => item.user._id), [String(fixture.activeId)]);
    await request(contactPath, { method: 'POST', token: a.token, body: { phones: Array(3001).fill(contactPhone) }, expectedStatus: 400 });
    const empty = await request(contactPath, { method: 'POST', token: a.token, body: { phones: [] } });
    assert.deepEqual(empty.data.matches, []);
    await db(async (connection) => {
      const users = connection.collection('users');
      assert.equal(await users.countDocuments({ _id: { $in: [fixture.activeId, fixture.inactiveId] } }), 2);
      assert.equal(await users.countDocuments({ phone: { $in: ['2025550199', '+912025550199'] } }), 0);
      const caller = await users.findOne({ _id: new connection.base.Types.ObjectId(a.userId) });
      assert.ok(!JSON.stringify(caller).includes('2025550199'));
    });
  },
}]);
