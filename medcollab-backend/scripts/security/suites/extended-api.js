'use strict';
module.exports = ({ add, ids }) => {
  const options = { module: 'Extended API', sources: ['src/features/channels/channel.controller.js', 'src/features/notifications/notification.controller.js'], context: 'Reset synthetic owner A, member B, foreign-space C and recipient-scoped notifications.' };
  const register = (name, actor, method, endpoint, statuses, body, extra = {}) => add(name, actor, method, endpoint, statuses, body, { ...options, ...extra });
  for (const actor of ['A', 'B', 'C', 'anonymous']) {
    const status = actor === 'A' ? 200 : actor === 'anonymous' ? 401 : 403;
    register('channel update admin boundary', actor, 'PUT', `/api/channels/${ids.channel}`, [status], { description: 'Controlled update', spaceId: ids.otherSpace, createdBy: ':C' }, {
      check: status === 200 ? async (_, c) => { const d = await c.models.Channel.findById(ids.channel); return d.description === 'Controlled update' && String(d.spaceId) === ids.space && String(d.createdBy) === String(c.users.A._id); } : undefined,
    });
    register('channel archive admin boundary', actor, 'DELETE', `/api/channels/${ids.channel}`, [status], undefined, {
      check: status === 200 ? async (_, c) => (await c.models.Channel.findById(ids.channel)).isArchived && await c.models.Message.countDocuments({ channelId: ids.channel }) === 2 : undefined,
    });
    register('channel creation membership and ownership', actor, 'POST', `/api/spaces/${ids.space}/channels`, [actor === 'anonymous' ? 401 : actor === 'C' ? 403 : 201], { name: 'controlled-private', isPrivate: true, createdBy: ':C', members: [':C'], spaceId: ids.otherSpace }, {
      check: ['A', 'B'].includes(actor) ? async (b, c) => { const d = await c.models.Channel.findById(b.data?.channel?._id); return !!d && String(d.spaceId) === ids.space && String(d.createdBy) === String(c.users[actor]._id) && d.members.length === 1 && String(d.members[0]) === String(c.users[actor]._id); } : undefined,
    });
  }
  const privatePrepare = async c => c.models.Channel.findByIdAndUpdate(ids.channel, { isPrivate: true, members: [c.users.A._id] });
  for (const [label, channel, message, owner, excluded, privateGroup] of [
    ['public group', ids.channel, ids.messageA, 'A', 'C', false],
    ['private group', ids.channel, ids.messageA, 'A', 'B', true],
    ['foreign DM', ids.dmOther, ids.dmOtherMessage, 'D', 'A', false],
    ['foreign space', ids.otherChannel, ids.otherMessage, 'C', 'A', false],
  ]) for (const actor of [owner, excluded]) register('search message isolation ' + label, actor, 'GET', '/api/search?q=SearchCanary&type=messages', [200], undefined, {
    prepare: async c => { if (privateGroup) await privatePrepare(c); await c.models.Message.findByIdAndUpdate(message, { 'content.text': 'SearchCanary' }); const control = await c.http(owner, 'GET', '/api/search?q=SearchCanary&type=messages'); if (control.status !== 200 || control.data?.data?.messages?.length !== 1 || control.data.data.messages[0]._id !== message) throw Error('Search positive control failed'); },
    check: (b, c) => { const list = b.data?.messages; c.evidence.canaryDisclosed = list?.some(m => m._id === message); return Array.isArray(list) && (actor === owner ? list.length === 1 && list[0]._id === message && list[0].channelId === channel : list.length === 0); },
  });
  const draft = async c => c.models.Handoff.findByIdAndUpdate(ids.handoff, { status: 'draft', submittedAt: null, shiftSummary: 'DraftCanary' });
  for (const [actor, suffix, visible] of [['A', '?type=sent', true], ['B', '?type=received', false], ['C', '', false], ['B', '?type=received&status=draft', false]]) register('handoff draft inbox privacy ' + suffix, actor, 'GET', '/api/handoffs' + suffix, [200], undefined, {
    prepare: draft, check: (b, c) => { const list = b.data?.handoffs; c.evidence.draftDisclosed = list?.some(h => h._id === ids.handoff && h.shiftSummary === 'DraftCanary'); return Array.isArray(list) && (visible ? list.length === 1 && c.evidence.draftDisclosed : list.length === 0); },
  });
  register('handoff draft direct receiver privacy', 'B', 'GET', `/api/handoffs/${ids.handoff}`, [403, 404], undefined, {
    prepare: draft,
    check: (body, c) => {
      const handoff = body.data?.handoff;
      c.evidence.returnedHandoffId = handoff?._id || null;
      c.evidence.returnedHandoffFields = handoff ? Object.keys(handoff).sort() : [];
      return true;
    },
  });
  for (const actor of ['A', 'B', 'D']) register('search draft handoff privacy', actor, 'GET', '/api/search?q=DraftCanary&type=handoffs', [200], undefined, {
    prepare: async c => { await draft(c); await c.models.Space.findByIdAndUpdate(ids.space, { $push: { members: { userId: c.users.D._id, role: 'member' } } }); const control = await c.http('A', 'GET', '/api/search?q=DraftCanary&type=handoffs'); if (control.status !== 200 || control.data?.data?.handoffs?.length !== 1) throw Error('Draft search control failed'); },
    check: (b, c) => { const list = b.data?.handoffs; c.evidence.draftDisclosed = list?.some(h => h._id === ids.handoff && h.shiftSummary === 'DraftCanary'); return Array.isArray(list) && (actor === 'A' ? list.length === 1 && c.evidence.draftDisclosed : list.length === 0); },
  });
  for (const suffix of ['', '/members', '/messages']) register('private group excluded member read ' + suffix, 'B', 'GET', `/api/channels/${ids.channel}${suffix}`, [403], undefined, {
    prepare: privatePrepare,
    check: (body, c) => {
      if (suffix === '') {
        const channel = body.data?.channel;
        c.evidence.returnedChannelId = channel?._id || null;
        c.evidence.returnedChannelFields = channel ? Object.keys(channel).sort() : [];
      }
      if (suffix === '/members') {
        const members = body.data?.members || [];
        c.evidence.returnedMemberIds = members.map(member => String(member._id)).sort();
        c.evidence.returnedMemberFields = [...new Set(members.flatMap(member => Object.keys(member || {})))].sort();
      }
      return true;
    },
  });
  for (const threadId of [ids.otherMessage, ids.dmOtherMessage]) register('direct body foreign thread binding ' + threadId, 'A', 'POST', `/api/channels/${ids.channel}/messages`, [400, 403, 404], { content: { text: 'Cross-context canary' }, threadId }, {
    module: 'Cross-module', category: 'foreign-resource', check: async (b, c) => {
      const child = b.data?.message?._id && await c.models.Message.findById(b.data.message._id).lean();
      const parent = await c.models.Message.findById(threadId).lean();
      c.evidence.foreignBindingPersisted = !!child && String(child.channelId) === ids.channel && String(child.threadId) === threadId && String(parent.channelId) !== ids.channel;
      c.evidence.foreignParentReplyCount = parent.replyCount;
      return !c.evidence.foreignBindingPersisted && parent.replyCount === 0;
    },
  });
  for (const variant of ['expired', 'wrong-key', 'inactive', 'refresh']) register('REST authentication ' + variant, 'A', 'GET', '/api/users/me', [401], undefined, {
    category: 'authentication-negative', run: c => {
      const jwt = require('jsonwebtoken');
      const key = variant === 'wrong-key' ? 'disposable-wrong-key' : variant === 'refresh' ? process.env.JWT_REFRESH_SECRET : process.env.JWT_SECRET;
      const token = jwt.sign({ userId: String(c.users[variant === 'inactive' ? 'I' : 'A']._id) }, key, { expiresIn: variant === 'expired' ? -1 : 60 });
      return c.http('A', 'GET', '/api/users/me', undefined, 'Bearer ' + token);
    },
  });
  const prep = async c => {
    const type = c.models.Notification.schema.path('type').enumValues[0];
    const docs = await c.models.Notification.create(['A', 'B'].map(actor => ({ userId: c.users[actor]._id, actorId: c.users.C._id, type, body: 'Synthetic notification', referenceId: ids.messageA, referenceType: 'Message', metadata: { channelId: ids.channel }, read: false })));
    c.noteA = String(docs[0]._id); c.noteB = String(docs[1]._id);
  };
  for (const op of ['read', 'unread', 'delete']) for (const actor of ['A', 'B', 'anonymous']) register('notification ' + op + ' recipient boundary', actor, op === 'delete' ? 'DELETE' : 'PUT', c => `/api/notifications/${c.noteA}${op === 'delete' ? '' : '/' + op}`, [actor === 'A' ? 200 : actor === 'anonymous' ? 401 : 404], undefined, {
    prepare: async c => { await prep(c); if (op === 'unread') await c.models.Notification.findByIdAndUpdate(c.noteA, { read: true }); },
    check: actor === 'A' ? async (_, c) => { const d = await c.models.Notification.findById(c.noteA); return (op === 'delete' ? !d : d.read === (op === 'read')) && !(await c.models.Notification.findById(c.noteB)).read; } : undefined,
  });
  register('notification inbox scoped to recipient', 'A', 'GET', '/api/notifications', [200], undefined, { prepare: prep, check: (b, c) => b.data?.notifications?.length === 1 && String(b.data.notifications[0]._id) === c.noteA });
  register('notification count scoped to recipient', 'A', 'GET', '/api/notifications/unread-count', [200], undefined, { prepare: prep, check: b => b.data?.count === 1 });
  for (const endpoint of ['/api/notifications/read-all', `/api/notifications/read-by-channel/${ids.channel}`, `/api/notifications/read-by-channel/${ids.otherChannel}`]) register('notification bulk recipient binding ' + endpoint, 'A', 'PUT', endpoint, [200], undefined, {
    prepare: prep, check: async (b, c) => b.data?.modifiedCount === (endpoint.endsWith(ids.otherChannel) ? 0 : 1) && !(await c.models.Notification.findById(c.noteB)).read,
  });
};
