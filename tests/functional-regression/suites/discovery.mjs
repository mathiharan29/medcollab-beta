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
    const lookup = async (person) => (await request(`/api/users/lookup?phone=${encodeURIComponent(person.phone)}`, { token: a.token })).data;
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
    assert.equal(optedOut.canRequest, false);
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
      [b, { name: 'Dr C++ One' }], [c, { displayTitle: 'Prof. X' }],
      [d, { speciality: 'Heart (Echo)' }], [e, { name: 'Dr C++ Outside' }],
    ]) await request('/api/users/me', { method: 'PUT', token: person.token, body });
    const search = async (q, spaceId, expectedStatus = 200) => request(`/api/users/search?q=${encodeURIComponent(q)}${spaceId ? `&spaceId=${spaceId}` : ''}`, { token: a.token, expectedStatus });
    const short = await search('c', null, 400);
    assert.equal(short.payload.success, false);
    assert.match(short.payload.message, /at least 2/i);
    const two = await search('Dr');
    assert.ok(two.data.users.some((user) => user._id === b.userId));
    const punctuation = await search('  c++  ');
    assert.deepEqual(new Set(punctuation.data.users.map((user) => user._id)), new Set([b.userId, e.userId]));
    const title = await search('  pRoF. x  ');
    assert.deepEqual(title.data.users.map((user) => user._id), [c.userId]);
    const speciality = await search('HEART (echo)');
    assert.deepEqual(speciality.data.users.map((user) => user._id), [d.userId]);
    const inS2 = await search('Prof. X', s2._id);
    assert.deepEqual(inS2.data.users.map((user) => user._id), [c.userId]);
    const excluded = await search('C++', s2._id);
    assert.deepEqual(excluded.data.users, []);
    await db(async (connection) => {
      const saved = await connection.collection('users').find({ _id: { $in: [b, c, d, e].map((user) => new connection.base.Types.ObjectId(user.userId)) } }).toArray();
      assert.equal(saved.length, 4);
      assert.equal(saved.find((user) => String(user._id) === c.userId).displayTitle, 'Prof. X');
      const filtered = await connection.collection('spaces').findOne({ _id: new connection.base.Types.ObjectId(s2._id) });
      assert.deepEqual(new Set(filtered.members.map((member) => String(member.userId))), new Set([a.userId, c.userId, d.userId]));
    });
  },
}, {
  id: 'FR-DISC-04', module: 'DISC',
  prerequisiteSeed: 'Twenty-one eligible and two ineligible synthetic users inserted directly as search fixtures, then added to a test space',
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
      const users = Array.from({ length: 21 }, (_, index) => makeUser(index + 1));
      users.push(makeUser(22, { isActive: false }), makeUser(23, { isOnboarded: false }));
      const inserted = await connection.collection('users').insertMany(users);
      const ids = Object.values(inserted.insertedIds);
      assert.equal(ids.length, 23);
      const joinedAt = new Date();
      const changed = await connection.collection('spaces').updateOne(
        { _id: new connection.base.Types.ObjectId(space._id) },
        { $push: { members: { $each: ids.map((userId) => ({ userId, role: 'member', joinedAt, isMuted: false })) } } },
      );
      assert.equal(changed.modifiedCount, 1);
      return ids.slice(0, 21).map(String);
    });
    const result = await request(`/api/users/search?q=${encodeURIComponent('Synthetic Limit')}`, { token: a.token });
    const found = result.data.users.map((user) => user._id);
    assert.equal(found.length, 20, 'Search must enforce the documented 20-result cap');
    assert.equal(new Set(found).size, 20, 'Search must not duplicate users');
    for (const id of found) assert.ok(eligibleIds.includes(id), `Ineligible or unknown user leaked into search: ${id}`);
    await db(async (connection) => {
      const stored = await connection.collection('users').find({ name: /^Synthetic Limit/ }).toArray();
      assert.equal(stored.length, 23);
      assert.equal(stored.filter((user) => user.isActive && user.isOnboarded).length, 21);
      const savedSpace = await connection.collection('spaces').findOne({ _id: new connection.base.Types.ObjectId(space._id) });
      assert.equal(savedSpace.members.length, 24);
    });
  },
}, {
  id: 'FR-DISC-02', module: 'DISC',
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
  },
}]);
