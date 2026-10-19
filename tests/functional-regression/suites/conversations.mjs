import assert from 'node:assert/strict';
import { runModule } from '../src/module-runner.mjs';
import { DecisionPending } from '../src/runner.mjs';

const cases = [{
  id: 'FR-DM-01', module: 'DM',
  prerequisiteSeed: 'Accepted A/B request inserted directly for pair-delegation branch; no accept endpoint behavior credited',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Group Alias', type: 'department' }, expectedStatus: 201 })).data.space;
    for (const person of [b, c]) await request('/api/spaces/join', { method: 'POST', token: person.token, body: { inviteCode: space.inviteCode } });
    const first = await request('/api/channels/dm/group', { method: 'POST', token: a.token, body: { userIds: [c.userId, b.userId, c.userId, a.userId] } });
    const groupId = first.data.channel._id;
    const reopened = await request('/api/channels/group-dm', { method: 'POST', token: a.token, body: { userIds: [b.userId, c.userId] } });
    assert.equal(reopened.data.channel._id, groupId);
    assert.deepEqual(new Set(reopened.data.channel.members.map((member) => member._id || member)), new Set([a.userId, b.userId, c.userId]));
    const selfOnly = await request('/api/channels/dm/group', { method: 'POST', token: a.token, body: { userIds: [a.userId] }, expectedStatus: 400 });
    assert.equal(selfOnly.payload.success, false);
    await db(async (connection) => {
      const collection = connection.collection('messagerequests');
      await collection.insertOne({ fromUserId: new connection.base.Types.ObjectId(a.userId), toUserId: new connection.base.Types.ObjectId(b.userId), status: 'accepted', createdAt: new Date(), updatedAt: new Date() });
    });
    const pair = await request('/api/channels/dm/group', { method: 'POST', token: a.token, body: { userIds: [b.userId] } });
    const direct = await request('/api/channels/dm', { method: 'POST', token: a.token, body: { userId: b.userId } });
    assert.equal(pair.data.channel._id, direct.data.channel._id);
    await db(async (connection) => {
      const groups = await connection.collection('channels').find({ spaceId: null, members: new connection.base.Types.ObjectId(a.userId) }).toArray();
      assert.equal(groups.filter((item) => item.members.length === 3).length, 1);
      assert.equal(groups.filter((item) => item.members.length === 2).length, 1);
    });
  },
}, {
  id: 'FR-DM-03', module: 'DM',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Rename Needl', type: 'department' }, expectedStatus: 201 })).data.space;
    for (const person of [b, c]) await request('/api/spaces/join', { method: 'POST', token: person.token, body: { inviteCode: space.inviteCode } });
    const created = await request('/api/channels/dm/group', { method: 'POST', token: a.token, body: { userIds: [b.userId, c.userId] } });
    const id = created.data.channel._id;
    const membership = new Set([a.userId, b.userId, c.userId]);
    const blank = await request(`/api/channels/${id}`, { method: 'PUT', token: a.token, body: { name: '  ' } });
    assert.equal(blank.data.channel.isNeedl, true);
    assert.match(blank.data.channel.name, /Synthetic B/);
    assert.match(blank.data.channel.name, /Synthetic C/);
    await db(async (connection) => {
      const saved = await connection.collection('channels').findOne({ _id: new connection.base.Types.ObjectId(id) });
      assert.equal(saved.name, null);
    });
    const eighty = 'N'.repeat(80);
    const exact = await request(`/api/channels/${id}`, { method: 'PUT', token: b.token, body: { name: `  ${eighty}  ` } });
    assert.equal(exact.data.channel.name, eighty);
    const overlong = await request(`/api/channels/${id}`, { method: 'PUT', token: c.token, body: { name: 'Q'.repeat(81) } });
    assert.equal(overlong.data.channel.name, 'Q'.repeat(80));
    for (const viewer of [a, b, c]) {
      const detail = await request(`/api/channels/${id}`, { token: viewer.token });
      assert.equal(detail.data.channel.name, 'Q'.repeat(80));
      assert.deepEqual(new Set(detail.data.channel.members.map((member) => member._id || member)), membership);
    }
    await db(async (connection) => {
      const saved = await connection.collection('channels').findOne({ _id: new connection.base.Types.ObjectId(id) });
      assert.equal(saved.name, 'Q'.repeat(80));
      assert.deepEqual(new Set(saved.members.map(String)), membership);
      assert.equal(await connection.collection('channels').countDocuments({ type: 'direct', members: { $all: [...membership].map((member) => new connection.base.Types.ObjectId(member)) }, isArchived: false }), 1);
    });
  },
}, {
  id: 'FR-DM-04', module: 'DM',
  prerequisiteSeed: 'Two direct channels inserted as existing conversation fixtures because live pair creation returns 500 on pinned upstream; list ordering and peer projection are tested independently',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    const [abId, acId] = await db(async (connection) => {
      const make = (peer) => ({
        spaceId: null, type: 'direct', members: [new connection.base.Types.ObjectId(a.userId), new connection.base.Types.ObjectId(peer.userId)],
        createdBy: new connection.base.Types.ObjectId(a.userId), isArchived: false, createdAt: new Date(), updatedAt: new Date(),
      });
      const inserted = await connection.collection('channels').insertMany([make(b), make(c)]);
      return Object.values(inserted.insertedIds).map(String);
    });
    const notes = await request('/api/channels/dm', { method: 'POST', token: a.token, body: { userId: a.userId } });
    assert.equal(notes.data.channel.isSelfNotes, true);
    const group = await request('/api/channels/dm/group', { method: 'POST', token: a.token, body: { userIds: [b.userId, c.userId] } });
    assert.equal(group.data.channel.isNeedl, true);
    const first = await request(`/api/channels/${abId}/messages`, { method: 'POST', token: a.token, body: { content: { text: 'synthetic first DM 6101' } }, expectedStatus: 201 });
    const second = await request(`/api/channels/${acId}/messages`, { method: 'POST', token: a.token, body: { content: { text: 'synthetic second DM 6102' } }, expectedStatus: 201 });
    const listA = (await request('/api/channels/dm', { token: a.token })).data.channels;
    const byId = new Map(listA.map((channel) => [channel._id, channel]));
    for (const id of [abId, acId, notes.data.channel._id, group.data.channel._id]) assert.ok(byId.has(id));
    assert.ok(listA.findIndex((channel) => channel._id === acId) < listA.findIndex((channel) => channel._id === abId));
    assert.equal(byId.get(abId).peer._id, b.userId);
    assert.equal(byId.get(acId).peer._id, c.userId);
    assert.equal(byId.get(notes.data.channel._id).isSelfNotes, true);
    assert.equal(byId.get(group.data.channel._id).isNeedl, true);
    const listB = (await request('/api/channels/dm', { token: b.token })).data.channels;
    const listC = (await request('/api/channels/dm', { token: c.token })).data.channels;
    assert.equal(listB.find((channel) => channel._id === abId).peer._id, a.userId);
    assert.equal(listC.find((channel) => channel._id === acId).peer._id, a.userId);
    assert.ok(!listB.some((channel) => channel._id === acId));
    assert.ok(!listC.some((channel) => channel._id === abId));
    await db(async (connection) => {
      const channels = await connection.collection('channels').find({ _id: { $in: [abId, acId].map((id) => new connection.base.Types.ObjectId(id)) } }).toArray();
      const ab = channels.find((channel) => String(channel._id) === abId);
      const ac = channels.find((channel) => String(channel._id) === acId);
      assert.equal(String(ab.lastMessage.messageId), first.data.message._id);
      assert.equal(String(ac.lastMessage.messageId), second.data.message._id);
      assert.ok(ac.lastMessage.sentAt > ab.lastMessage.sentAt, 'Fixture messages must have distinct ordered send times');
      assert.equal(await connection.collection('messages').countDocuments({ channelId: { $in: channels.map((channel) => channel._id) } }), 2);
    });
  },
}, {
  id: 'FR-DM-05', module: 'DM',
  prerequisiteSeed: 'Existing A/B direct channel and three timestamped synthetic roots inserted directly; live pair creation is a separate failing contract',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Today Expansion', type: 'department' }, expectedStatus: 201 })).data.space;
    await request('/api/spaces/join', { method: 'POST', token: c.token, body: { inviteCode: space.inviteCode } });
    const now = new Date();
    const midnight = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
    const samples = [
      ['before', new Date(midnight - 1)], ['at', new Date(midnight)], ['after', new Date(midnight + 1)],
    ];
    const sourceId = await db(async (connection) => {
      const channel = await connection.collection('channels').insertOne({
        spaceId: null, type: 'direct', members: [new connection.base.Types.ObjectId(a.userId), new connection.base.Types.ObjectId(b.userId)],
        createdBy: new connection.base.Types.ObjectId(a.userId), isArchived: false, createdAt: new Date(), updatedAt: new Date(),
      });
      const id = channel.insertedId;
      const roots = samples.map(([label, createdAt]) => ({
        channelId: id, spaceId: null, senderId: new connection.base.Types.ObjectId(a.userId), type: 'text',
        content: { text: `synthetic today ${label}` }, priority: 'normal', isDeleted: false, deletedAt: null,
        createdAt, updatedAt: createdAt,
      }));
      await connection.collection('messages').insertMany(roots);
      return String(id);
    });
    const expanded = await request(`/api/channels/${sourceId}/expand`, { method: 'POST', token: a.token, body: { userIds: [c.userId], history: 'today' } });
    const destinationId = expanded.data.channel._id;
    assert.notEqual(destinationId, sourceId);
    assert.deepEqual(new Set(expanded.data.channel.members.map((member) => member._id || member)), new Set([a.userId, b.userId, c.userId]));
    await db(async (connection) => {
      const source = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(sourceId) }).sort({ createdAt: 1 }).toArray();
      const copies = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(destinationId) }).sort({ createdAt: 1 }).toArray();
      assert.deepEqual(source.map((item) => item.content.text), samples.map(([label]) => `synthetic today ${label}`));
      assert.deepEqual(copies.map((item) => item.content.text), ['synthetic today at', 'synthetic today after']);
      assert.deepEqual(copies.map((item) => item.createdAt.getTime()), [midnight, midnight + 1]);
      assert.ok(copies.every((item) => !source.some((original) => original._id.equals(item._id))));
    });
    throw new DecisionPending('Q2: intended client timezone for today expansion needs product decision', [
      'server UTC midnight excluded prior-day root', 'at/after-midnight roots copied with new IDs', 'source records unchanged',
    ]);
  },
}, {
  id: 'FR-DM-06', module: 'DM', timeoutMs: 60000,
  prerequisiteSeed: 'Existing A/B direct channel and 502 synthetic roots inserted directly to isolate all-history copy behavior',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Copy Cap', type: 'department' }, expectedStatus: 201 })).data.space;
    await request('/api/spaces/join', { method: 'POST', token: c.token, body: { inviteCode: space.inviteCode } });
    const fixture = await db(async (connection) => {
      const source = await connection.collection('channels').insertOne({
        spaceId: null, type: 'direct', members: [new connection.base.Types.ObjectId(a.userId), new connection.base.Types.ObjectId(b.userId)],
        createdBy: new connection.base.Types.ObjectId(a.userId), isArchived: false, createdAt: new Date(), updatedAt: new Date(),
      });
      const start = Date.UTC(2026, 0, 1);
      const roots = Array.from({ length: 502 }, (_, index) => ({
        channelId: source.insertedId, spaceId: null, senderId: new connection.base.Types.ObjectId(a.userId), type: 'text',
        content: { text: `synthetic cap ${String(index).padStart(3, '0')}` }, priority: 'normal',
        isDeleted: index === 501, deletedAt: index === 501 ? new Date(start + 501000) : null,
        createdAt: new Date(start + index * 1000), updatedAt: new Date(start + index * 1000),
      }));
      const inserted = await connection.collection('messages').insertMany(roots);
      return { sourceId: String(source.insertedId), selectedPreviewSourceId: String(inserted.insertedIds[499]) };
    });
    const expanded = await request(`/api/channels/${fixture.sourceId}/expand`, { method: 'POST', token: a.token, body: { userIds: [c.userId], history: 'all' } });
    const destinationId = expanded.data.channel._id;
    assert.notEqual(destinationId, fixture.sourceId);
    await db(async (connection) => {
      const source = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(fixture.sourceId) }).sort({ createdAt: 1 }).toArray();
      const copies = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(destinationId) }).sort({ createdAt: 1 }).toArray();
      assert.equal(source.length, 502);
      assert.equal(source.filter((item) => item.isDeleted).length, 1);
      assert.equal(copies.length, 500);
      assert.equal(copies[0].content.text, 'synthetic cap 000');
      assert.equal(copies.at(-1).content.text, 'synthetic cap 499');
      assert.ok(!copies.some((item) => ['synthetic cap 500', 'synthetic cap 501'].includes(item.content.text)));
      assert.ok(copies.every((copy) => !source.some((original) => original._id.equals(copy._id))));
      const destination = await connection.collection('channels').findOne({ _id: new connection.base.Types.ObjectId(destinationId) });
      assert.equal(String(destination.lastMessage.messageId), fixture.selectedPreviewSourceId);
      assert.ok(!copies.some((copy) => String(copy._id) === String(destination.lastMessage.messageId)));
      assert.deepEqual(new Set(destination.members.map(String)), new Set([a.userId, b.userId, c.userId]));
    });
    throw new DecisionPending('Q2: 500-item oldest-first cap and source-ID destination preview require product decision', [
      '501 active source roots and one deleted root retained', 'oldest 500 active roots copied with new IDs', 'deleted and newest active roots excluded', 'destination preview points to source ID',
    ]);
  },
}, {
  id: 'FR-DM-07', module: 'DM',
  prerequisiteSeed: 'Existing A/B direct channel inserted directly; root, thread reply and quote then created through live message APIs',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Copy Graph', type: 'department' }, expectedStatus: 201 })).data.space;
    await request('/api/spaces/join', { method: 'POST', token: c.token, body: { inviteCode: space.inviteCode } });
    const sourceId = await db(async (connection) => String((await connection.collection('channels').insertOne({
      spaceId: null, type: 'direct', members: [new connection.base.Types.ObjectId(a.userId), new connection.base.Types.ObjectId(b.userId)],
      createdBy: new connection.base.Types.ObjectId(a.userId), isArchived: false, createdAt: new Date(), updatedAt: new Date(),
    })).insertedId));
    const root = (await request(`/api/channels/${sourceId}/messages`, { method: 'POST', token: a.token, body: { content: { text: 'synthetic graph root' } }, expectedStatus: 201 })).data.message;
    const reply = (await request(`/api/channels/${sourceId}/messages/${root._id}/reply`, { method: 'POST', token: b.token, body: { content: { text: 'synthetic graph thread reply' } }, expectedStatus: 201 })).data.message;
    const quote = (await request(`/api/channels/${sourceId}/messages`, { method: 'POST', token: b.token, body: { content: { text: 'synthetic graph quote' }, replyToId: root._id }, expectedStatus: 201 })).data.message;
    const sourceThread = await request(`/api/channels/${sourceId}/messages/${root._id}/thread`, { token: a.token });
    assert.deepEqual(sourceThread.data.replies.map((item) => item._id), [reply._id]);
    const expanded = await request(`/api/channels/${sourceId}/expand`, { method: 'POST', token: a.token, body: { userIds: [c.userId], history: 'all' } });
    const destinationId = expanded.data.channel._id;
    const graph = await db(async (connection) => {
      const source = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(sourceId) }).toArray();
      const copies = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(destinationId) }).toArray();
      assert.equal(source.length, 3);
      assert.equal(copies.length, 3);
      const byText = (list, text) => list.find((item) => item.content.text === text);
      assert.equal(String(byText(source, 'synthetic graph thread reply').threadId), root._id);
      assert.equal(String(byText(source, 'synthetic graph quote').replyTo.messageId), root._id);
      assert.equal(byText(source, 'synthetic graph root').replyCount, 1);
      const copiedRoot = byText(copies, 'synthetic graph root');
      const copiedReply = byText(copies, 'synthetic graph thread reply');
      const copiedQuote = byText(copies, 'synthetic graph quote');
      assert.ok(copiedRoot && copiedReply && copiedQuote);
      assert.ok(copies.every((item) => !source.some((original) => original._id.equals(item._id))));
      assert.equal(copiedReply.threadId ?? null, null);
      assert.equal(String(copiedQuote.replyTo.messageId), root._id);
      return { copiedRootId: String(copiedRoot._id), copiedQuoteId: String(copiedQuote._id) };
    });
    const copiedThread = await request(`/api/channels/${destinationId}/messages/${graph.copiedRootId}/thread`, { token: c.token });
    assert.deepEqual(copiedThread.data.replies, []);
    const copiedTimeline = await request(`/api/channels/${destinationId}/messages`, { token: c.token });
    const copiedQuote = copiedTimeline.data.messages.find((item) => item._id === graph.copiedQuoteId);
    assert.equal(copiedQuote.replyTo.messageId, root._id);
    const sourceTargetInDestination = await request(`/api/channels/${destinationId}/messages/${root._id}/thread`, { token: c.token, expectedStatus: 403 });
    assert.equal(sourceTargetInDestination.payload.success, false);
    throw new DecisionPending('Q2: copied thread and quote graph remapping requires product decision', [
      'source thread and quote references unchanged', 'three copies have new IDs', 'copied thread reply has no threadId', 'copied quote targets source root', 'destination thread and source-ID navigation cannot open the copied graph',
    ]);
  },
}, {
  id: 'FR-DM-08', module: 'DM',
  prerequisiteSeed: 'Existing A/B direct channel inserted directly; history messages sent through live API before and after first expansion',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Reuse Expansion', type: 'department' }, expectedStatus: 201 })).data.space;
    await request('/api/spaces/join', { method: 'POST', token: c.token, body: { inviteCode: space.inviteCode } });
    const sourceId = await db(async (connection) => String((await connection.collection('channels').insertOne({
      spaceId: null, type: 'direct', members: [new connection.base.Types.ObjectId(a.userId), new connection.base.Types.ObjectId(b.userId)],
      createdBy: new connection.base.Types.ObjectId(a.userId), isArchived: false, createdAt: new Date(), updatedAt: new Date(),
    })).insertedId));
    const firstSource = (await request(`/api/channels/${sourceId}/messages`, { method: 'POST', token: a.token, body: { content: { text: 'synthetic source before expansion' } }, expectedStatus: 201 })).data.message;
    const expand = () => request(`/api/channels/${sourceId}/expand`, { method: 'POST', token: a.token, body: { userIds: [c.userId], history: 'all' } });
    const first = await expand();
    const destinationId = first.data.channel._id;
    assert.equal(first.data.createdNew, true);
    const secondSource = (await request(`/api/channels/${sourceId}/messages`, { method: 'POST', token: b.token, body: { content: { text: 'synthetic source after expansion' } }, expectedStatus: 201 })).data.message;
    const reopened = await expand();
    assert.equal(reopened.data.channel._id, destinationId);
    assert.deepEqual(new Set(reopened.data.channel.members.map((member) => member._id || member)), new Set([a.userId, b.userId, c.userId]));
    const destination = await request(`/api/channels/${destinationId}/messages`, { token: c.token });
    assert.deepEqual(destination.data.messages.map((message) => message.content.text), ['synthetic source before expansion']);
    await db(async (connection) => {
      const source = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(sourceId) }).toArray();
      const copies = await connection.collection('messages').find({ channelId: new connection.base.Types.ObjectId(destinationId) }).toArray();
      assert.deepEqual(new Set(source.map((message) => String(message._id))), new Set([firstSource._id, secondSource._id]));
      assert.equal(copies.length, 1);
      assert.notEqual(String(copies[0]._id), firstSource._id);
      assert.equal(copies[0].content.text, 'synthetic source before expansion');
      const groups = await connection.collection('channels').find({ type: 'direct', members: { $all: [a, b, c].map((person) => new connection.base.Types.ObjectId(person.userId)) }, isArchived: false }).toArray();
      assert.equal(groups.length, 1);
      assert.equal(String(groups[0]._id), destinationId);
    });
  },
}, {
  id: 'FR-DM-09', module: 'DM',
  prerequisiteSeed: 'Accepted A/B request inserted directly before concurrent pair intents because live acceptance is a separate failing contract',
  run: async ({ identity, request, db }) => {
    const a = await identity('A'), b = await identity('B'), c = await identity('C');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Concurrent Conversation', type: 'department' }, expectedStatus: 201 })).data.space;
    for (const person of [b, c]) await request('/api/spaces/join', { method: 'POST', token: person.token, body: { inviteCode: space.inviteCode } });
    await db(async (connection) => connection.collection('messagerequests').insertOne({
      fromUserId: new connection.base.Types.ObjectId(a.userId), toUserId: new connection.base.Types.ObjectId(b.userId),
      status: 'accepted', createdAt: new Date(), updatedAt: new Date(),
    }));
    const groupAttempts = await Promise.allSettled([
      request('/api/channels/dm/group', { method: 'POST', token: a.token, body: { userIds: [b.userId, c.userId] } }),
      request('/api/channels/dm/group', { method: 'POST', token: b.token, body: { userIds: [c.userId, a.userId] } }),
      request('/api/channels/group-dm', { method: 'POST', token: c.token, body: { userIds: [a.userId, b.userId] } }),
    ]);
    const groupErrors = groupAttempts.filter((item) => item.status === 'rejected');
    const groupIds = groupAttempts.filter((item) => item.status === 'fulfilled').map((item) => item.value.data.channel._id);
    const groupRecords = await db(async (connection) => connection.collection('channels').find({
      type: 'direct', members: { $all: [a, b, c].map((person) => new connection.base.Types.ObjectId(person.userId)), $size: 3 },
    }).toArray());
    if (groupErrors.length) throw groupErrors[0].reason;
    assert.equal(groupIds.length, 3);
    assert.ok(groupRecords.length >= 1);
    for (const id of groupIds) assert.ok(groupRecords.some((record) => String(record._id) === id));
    const pairAttempts = await Promise.allSettled([
      request('/api/channels/dm', { method: 'POST', token: a.token, body: { userId: b.userId } }),
      request('/api/channels/dm', { method: 'POST', token: b.token, body: { userId: a.userId } }),
    ]);
    const pairErrors = pairAttempts.filter((item) => item.status === 'rejected');
    const pairIds = pairAttempts.filter((item) => item.status === 'fulfilled').map((item) => item.value.data.channel._id);
    const pairRecords = await db(async (connection) => connection.collection('channels').find({
      type: 'direct', members: { $all: [a, b].map((person) => new connection.base.Types.ObjectId(person.userId)), $size: 2 },
    }).toArray());
    if (pairErrors.length) {
      assert.equal(pairRecords.length, 0, 'Failed pair intents must not create hidden partial DMs');
      pairErrors[0].reason.message += `; concurrent group records observed: ${groupRecords.length}`;
      throw pairErrors[0].reason;
    }
    assert.equal(pairRecords.length, 1, 'Concurrent pair intent must create exactly one conversation');
    assert.deepEqual(new Set(pairIds), new Set([String(pairRecords[0]._id)]));
    throw new DecisionPending(`Q7: concurrent group exact-membership guarantee unresolved; observed ${groupRecords.length} matching group record(s)`, [
      `three group calls completed with ${groupRecords.length} persisted exact-membership record(s)`, 'two pair calls returned one pair ID',
    ]);
  },
}, {
  id: 'FR-DM-02', module: 'DM', timeoutMs: 60000,
  run: async ({ identity, request, db }) => {
    const a = await identity('A');
    const space = (await request('/api/spaces', { method: 'POST', token: a.token, body: { name: 'Synthetic Needl Boundary', type: 'department' }, expectedStatus: 201 })).data.space;
    const others = [];
    for (const label of ['B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J']) {
      const person = await identity(label);
      await request('/api/spaces/join', { method: 'POST', token: person.token, body: { inviteCode: space.inviteCode } });
      others.push(person);
    }
    const accepted = await request('/api/channels/dm/group', { method: 'POST', token: a.token, body: { userIds: others.slice(0, 8).map((person) => person.userId) } });
    const groupId = accepted.data.channel._id;
    assert.ok(groupId);
    const reread = await request(`/api/channels/${groupId}`, { token: a.token });
    assert.deepEqual(new Set(reread.data.channel.members.map((member) => member._id || member)), new Set([a.userId, ...others.slice(0, 8).map((person) => person.userId)]));
    const rejected = await request('/api/channels/dm/group', { method: 'POST', token: a.token, body: { userIds: others.map((person) => person.userId) }, expectedStatus: 400 });
    assert.equal(rejected.payload.success, false);
    await db(async (connection) => {
      const groups = await connection.collection('channels').find({ spaceId: null, members: new connection.base.Types.ObjectId(a.userId) }).toArray();
      assert.equal(groups.filter((item) => item.members.length === 9).length, 1);
      assert.equal(groups.filter((item) => item.members.length === 10).length, 0, 'Rejected 10-person group must not create a partial conversation');
      assert.equal(String(groups.find((item) => item.members.length === 9)._id), groupId);
    });
  },
}];

// Conversation membership and history mutations are isolated per case.
for (const item of cases) await runModule(`conversations-${item.id.slice(-2).toLowerCase()}`, [item]);
