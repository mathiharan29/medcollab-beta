import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { DecisionPending } from '../src/runner.mjs';

const cases = [{
  id: 'FR-REQ-01', module: 'REQ',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), d = await identity('D');
    await request('/api/users/me', { method: 'PUT', token: d.token, body: { notifications: { allowMessageRequestsFromAnyone: true } } });
    await request('/api/users/me', { method: 'PUT', token: a.token, body: { notifications: { allowMessageRequestsFromAnyone: true } } });
    const first = await request('/api/message-requests', { method: 'POST', token: a.token, body: { toUserId: d.userId, introMessage: 'synthetic reverse collision' }, expectedStatus: 201 });
    const id = first.data.request.id;
    const reverse = await request('/api/message-requests', { method: 'POST', token: d.token, body: { toUserId: a.userId } });
    assert.equal(reverse.data.request.id, id);
    assert.equal(reverse.data.action, 'accept_incoming');
    const sent = await request('/api/message-requests?direction=sent', { token: a.token });
    const received = await request('/api/message-requests?direction=received', { token: d.token });
    assert.equal(sent.data.requests.filter((item) => item.id === id).length, 1);
    assert.equal(received.data.requests.filter((item) => item.id === id).length, 1);
    assert.equal(received.data.requests.find((item) => item.id === id).direction, 'received');
    const count = await request('/api/message-requests/pending-count', { token: d.token });
    assert.equal(count.data.count, 1);
    await db(async (connection) => {
      const records = await connection.collection('messagerequests').find({ $or: [{ fromUserId: new connection.base.Types.ObjectId(a.userId), toUserId: new connection.base.Types.ObjectId(d.userId) }, { fromUserId: new connection.base.Types.ObjectId(d.userId), toUserId: new connection.base.Types.ObjectId(a.userId) }] }).toArray();
      assert.equal(records.length, 1);
      assert.equal(String(records[0]._id), id);
      assert.equal(records[0].status, 'pending');
    });
  },
}, {
  id: 'FR-REQ-03', module: 'REQ',
  prerequisiteSeed: 'Accepted and declined statuses set directly after real request creation to isolate list/filter serialization; transition behavior is exercised separately',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), d = await identity('D'), e = await identity('E'), f = await identity('F');
    for (const person of [d, e, f]) await request('/api/users/me', { method: 'PUT', token: person.token, body: { notifications: { allowMessageRequestsFromAnyone: true } } });
    const requests = [];
    for (const [person, introMessage] of [[d, ''], [e, 'X'.repeat(280)], [f, 'Synthetic declined intro']]) {
      const created = await request('/api/message-requests', { method: 'POST', token: a.token, body: { toUserId: person.userId, introMessage }, expectedStatus: 201 });
      assert.equal(created.data.request.introMessage, introMessage);
      requests.push({ person, introMessage, id: created.data.request.id });
    }
    const rejected = await request('/api/message-requests', { method: 'POST', token: a.token, body: { toUserId: f.userId, introMessage: 'Y'.repeat(281) }, expectedStatus: 400 });
    assert.equal(rejected.payload.success, false);
    await db(async (connection) => {
      const ids = requests.map((item) => new connection.base.Types.ObjectId(item.id));
      assert.equal(await connection.collection('messagerequests').countDocuments({ _id: { $in: ids } }), 3);
      assert.equal((await connection.collection('messagerequests').updateOne({ _id: ids[1] }, { $set: { status: 'accepted' } })).modifiedCount, 1);
      assert.equal((await connection.collection('messagerequests').updateOne({ _id: ids[2] }, { $set: { status: 'declined' } })).modifiedCount, 1);
    });
    const list = async (person, direction, status) => (await request(`/api/message-requests?direction=${direction}&status=${status}`, { token: person.token })).data.requests;
    for (const [index, status] of ['pending', 'accepted', 'declined'].entries()) {
      const expected = requests[index];
      const sent = await list(a, 'sent', status);
      const all = await list(a, 'all', status);
      const received = await list(expected.person, 'received', status);
      for (const items of [sent, all, received]) {
        assert.deepEqual(items.map((item) => item.id), [expected.id]);
        assert.equal(items[0].introMessage, expected.introMessage);
      }
      assert.equal(sent[0].direction, 'sent');
      assert.equal(received[0].direction, 'received');
      assert.equal(sent[0].peer.id || sent[0].peer._id, expected.person.userId);
      assert.equal(received[0].peer.id || received[0].peer._id, a.userId);
    }
    assert.deepEqual(await list(a, 'received', 'pending'), []);
    const counts = await Promise.all([a, d, e, f].map((person) => request('/api/message-requests/pending-count', { token: person.token })));
    assert.deepEqual(counts.map((item) => item.data.count), [0, 1, 0, 0]);
    await db(async (connection) => {
      const persisted = await connection.collection('messagerequests').find({ fromUserId: new connection.base.Types.ObjectId(a.userId) }).toArray();
      assert.deepEqual(new Set(persisted.map((item) => item.status)), new Set(['pending', 'accepted', 'declined']));
      assert.equal(persisted.length, 3, 'Overlength intro must not create another record');
    });
  },
}, {
  id: 'FR-REQ-04', module: 'REQ',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    for (const person of [b, c]) await request('/api/users/me', { method: 'PUT', token: person.token, body: { notifications: { allowMessageRequestsFromAnyone: true } } });
    const sendTo = async (person) => (await request('/api/message-requests', { method: 'POST', token: a.token, body: { toUserId: person.userId, introMessage: `Synthetic transition ${person.label}` }, expectedStatus: 201 })).data.request.id;
    const declineId = await sendTo(c);
    const declined = await request(`/api/message-requests/${declineId}/decline`, { method: 'POST', token: c.token });
    assert.equal(declined.data.request.status, 'declined');
    for (const action of ['decline', 'accept']) {
      const rejected = await request(`/api/message-requests/${declineId}/${action}`, { method: 'POST', token: c.token, expectedStatus: 400 });
      assert.equal(rejected.payload.success, false);
    }
    const cCount = await request('/api/message-requests/pending-count', { token: c.token });
    assert.equal(cCount.data.count, 0);
    await db(async (connection) => {
      const stored = await connection.collection('messagerequests').findOne({ _id: new connection.base.Types.ObjectId(declineId) });
      assert.equal(stored.status, 'declined');
      assert.equal(await connection.collection('channels').countDocuments({ type: 'direct', members: new connection.base.Types.ObjectId(c.userId) }), 0);
    });
    const acceptId = await sendTo(b);
    let acceptanceError;
    try {
      const accepted = await request(`/api/message-requests/${acceptId}/accept`, { method: 'POST', token: b.token });
      assert.equal(accepted.data.request.status, 'accepted');
      assert.ok(accepted.data.channel._id);
    } catch (error) { acceptanceError = error; }
    const bCount = await request('/api/message-requests/pending-count', { token: b.token });
    assert.equal(bCount.data.count, 0);
    for (const action of ['accept', 'decline']) {
      const rejected = await request(`/api/message-requests/${acceptId}/${action}`, { method: 'POST', token: b.token, expectedStatus: 400 });
      assert.equal(rejected.payload.success, false);
    }
    await db(async (connection) => {
      const stored = await connection.collection('messagerequests').findOne({ _id: new connection.base.Types.ObjectId(acceptId) });
      assert.equal(stored.status, 'accepted');
      const channels = await connection.collection('channels').find({ type: 'direct', members: { $all: [new connection.base.Types.ObjectId(a.userId), new connection.base.Types.ObjectId(b.userId)] } }).toArray();
      if (!acceptanceError) assert.equal(channels.length, 1, 'Successful accept must open exactly one DM');
      else assert.equal(channels.length, 0, 'Failed accept left accepted state without a DM');
    });
    if (acceptanceError) throw acceptanceError;
  },
}, {
  id: 'FR-REQ-05', module: 'REQ', mongoFailpoint: true,
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B');
    await request('/api/users/me', { method: 'PUT', token: b.token, body: { notifications: { allowMessageRequestsFromAnyone: true } } });
    const created = await request('/api/message-requests', { method: 'POST', token: a.token, body: { toUserId: b.userId, introMessage: 'Synthetic interrupted acceptance' }, expectedStatus: 201 });
    const id = created.data.request.id;
    await db(async (connection) => {
      const result = await connection.db.admin().command({
        configureFailPoint: 'failCommand', mode: { times: 1 },
        // Authentication and request middleware can issue findAndModify too.
        // Restrict the disposable fault to the DM upsert's collection so the
        // failure occurs after request.save(), at the intended lifecycle edge.
        data: {
          failCommands: ['findAndModify'],
          namespace: `${connection.db.databaseName}.channels`,
          errorCode: 42,
        },
      });
      assert.equal(result.ok, 1, 'Disposable MongoDB did not arm the findAndModify fault');
    });
    const interrupted = await request(`/api/message-requests/${id}/accept`, { method: 'POST', token: b.token, expectedStatus: 500 });
    assert.equal(interrupted.payload.success, false);
    await db(async (connection) => {
      const record = await connection.collection('messagerequests').findOne({ _id: new connection.base.Types.ObjectId(id) });
      assert.equal(record.status, 'accepted', 'The injected fault must occur after the request state write');
      const dmCount = await connection.collection('channels').countDocuments({ type: 'direct', members: { $all: [new connection.base.Types.ObjectId(a.userId), new connection.base.Types.ObjectId(b.userId)] } });
      assert.equal(dmCount, 0);
    });
    const acceptedList = await request('/api/message-requests?direction=received&status=accepted', { token: b.token });
    assert.deepEqual(acceptedList.data.requests.map((item) => item.id), [id]);
    const dms = await request('/api/channels/dm', { token: b.token });
    assert.ok(!dms.data.channels.some((channel) => channel.members?.some((member) => member._id === a.userId)));
    const retry = await request(`/api/message-requests/${id}/accept`, { method: 'POST', token: b.token, expectedStatus: 400 });
    assert.equal(retry.payload.success, false);
    await db(async (connection) => {
      const record = await connection.collection('messagerequests').findOne({ _id: new connection.base.Types.ObjectId(id) });
      assert.equal(record.status, 'accepted');
      assert.equal(await connection.collection('channels').countDocuments({ type: 'direct', members: { $all: [new connection.base.Types.ObjectId(a.userId), new connection.base.Types.ObjectId(b.userId)] } }), 0);
    });
    throw new DecisionPending('Q7: recovery or atomic rollback contract for accepted-without-DM state requires product decision', [
      'controlled database fault returned 500', 'request persisted as accepted without DM', 'reload exposes accepted request but no DM', 'accept retry rejected and did not recover',
    ]);
  },
}, {
  id: 'FR-REQ-02', module: 'REQ',
  prerequisiteSeed: 'Accepted request inserted as component prerequisite; no accept endpoint behavior credited',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), e = await identity('E');
    const initialRecords = await db(async (connection) => connection.collection('messagerequests').countDocuments({}));
    let seededId;
    await db(async (connection) => {
      const fromUserId = new connection.base.Types.ObjectId(a.userId);
      const toUserId = new connection.base.Types.ObjectId(b.userId);
      const seeded = await connection.collection('messagerequests').insertOne({ fromUserId, toUserId, status: 'accepted', introMessage: 'synthetic prerequisite', createdAt: new Date(), updatedAt: new Date() });
      seededId = String(seeded.insertedId);
    });
    const pendingBefore = await Promise.all([a, b, e].map((person) => request('/api/message-requests/pending-count', { token: person.token })));
    const notificationCountBefore = await db(async (connection) => connection.collection('notifications').countDocuments({ userId: { $in: [a, b, e].map((person) => new connection.base.Types.ObjectId(person.userId)) } }));
    const boundaries = [
      [{ toUserId: a.userId }, 400],
      [{ toUserId: '000000000000000000000001' }, 404],
      [{ toUserId: b.userId }, 400],
      [{ toUserId: e.userId }, 403],
    ];
    for (const [body, status] of boundaries) {
      const denied = await request('/api/message-requests', { method: 'POST', token: a.token, body, expectedStatus: status });
      assert.equal(denied.payload.success, false);
    }
    const pendingAfter = await Promise.all([a, b, e].map((person) => request('/api/message-requests/pending-count', { token: person.token })));
    assert.deepEqual(pendingAfter.map((item) => item.data.count), pendingBefore.map((item) => item.data.count));
    await db(async (connection) => {
      const records = await connection.collection('messagerequests').find({}).toArray();
      assert.equal(records.length, initialRecords + 1);
      assert.equal(records.filter((item) => String(item._id) === seededId && item.status === 'accepted').length, 1);
      const notifications = await connection.collection('notifications').countDocuments({ userId: { $in: [a, b, e].map((person) => new connection.base.Types.ObjectId(person.userId)) } });
      assert.equal(notifications, notificationCountBefore);
    });
  },
}];

// Request statuses and opt-in preferences change shared relationship state.
// A fresh backend and database per case keeps each transition independent.
for (const item of cases) await runModule(`requests-${item.id.slice(-2).toLowerCase()}`, [item]);
