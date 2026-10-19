'use strict';
const assert = require('node:assert/strict');
const wait = ms => new Promise(r => setTimeout(r, ms));
const QUIET = 1500;
function once(socket, event) {
  return new Promise((resolve, reject) => { const timer = setTimeout(() => { socket.off(event, listener); reject(new Error('Missing socket control: ' + event)); }, 5000); const listener = payload => { clearTimeout(timer); resolve(payload); }; socket.once(event, listener); });
}
async function connect(c, actor, extra = {}, negative = false) {
  const { io } = require('socket.io-client');
  const socket = io('http://127.0.0.1:5000', { autoConnect: false, reconnection: false, forceNew: true, transports: ['websocket'], auth: { token: c.tokens[actor], ...extra } });
  c.cleanup.push(() => socket.disconnect());
  const result = once(socket, negative ? 'connect_error' : 'authenticated'); socket.connect();
  const payload = await result;
  if (!negative) assert.equal(String(payload.userId), String(c.users[actor]._id));
  return socket;
}
async function join(socket, channelId, allowed = true) {
  const response = once(socket, allowed ? 'join_channel' : 'error'); socket.emit('join_channel', { channelId });
  const value = await response; if (allowed) assert.ok(value.success && value.channelId === channelId);
}
function collect(socket, event, predicate) { const packets = []; socket.on(event, p => { if (predicate(p)) packets.push(p); }); return packets; }
async function controlEdit(c, socket, channelId, messageId) {
  const received = once(socket, 'message_updated');
  const r = await c.http(channelId === c.ids.otherChannel ? 'C' : 'A', 'PUT', `/api/channels/${channelId}/messages/${messageId}`, { content: { text: 'Realtime control canary' } });
  assert.equal(r.status, 200); const p = await received; assert.equal(String(p.messageId), messageId);
}
module.exports = ({ add, ids }) => {
  const reg = (name, work, actor = 'A') => add(name, actor, 'SOCKET', '/socket.io/', [200], undefined, {
    module: 'Realtime', category: 'realtime-authorization', context: 'Actual websocket clients, real REST producers, authenticated controls; 1500 ms quiet window.', sources: ['src/socket/index.js', 'src/socket/handlers/message.handler.js', 'src/utils/channelAccess.js'],
    run: async c => { c.evidence.quietWindowMs = QUIET; c.evidence.invariantHeld = await work(c); return c.http('anonymous', 'GET', '/health').then(r => ({ status: r.status, data: { success: r.data?.status === 'ok' } })); },
    check: (_, c) => c.evidence.invariantHeld,
  });
  for (const variant of ['missing', 'malformed', 'expired', 'wrong-key', 'inactive']) reg('socket authentication ' + variant, async c => {
    const control = await connect(c, 'A'); assert.ok(control.connected);
    const jwt = require('jsonwebtoken');
    const token = variant === 'missing' ? undefined : variant === 'malformed' ? 'invalid' : jwt.sign({ userId: String(c.users[variant === 'inactive' ? 'I' : 'A']._id) }, variant === 'wrong-key' ? 'disposable-wrong-key' : process.env.JWT_SECRET, { expiresIn: variant === 'expired' ? -1 : 60 });
    const denied = await connect(c, 'A', { token }, true); c.evidence.rejected = !denied.connected; return c.evidence.rejected;
  });
  reg('socket handshake identity forgery', async c => { const s = await connect(c, 'A', { userId: String(c.users.C._id), name: 'Forged', spaceIds: [ids.otherSpace] }); return s.connected; });
  for (const [label, actor, channel, message, privateChannel] of [
    ['foreign space', 'A', ids.otherChannel, ids.otherMessage, false],
    ['foreign DM', 'C', ids.dmAB, ids.dmMessageA, false],
    ['private group', 'B', ids.channel, ids.messageA, true],
  ]) {
    const setup = async c => { if (privateChannel) await c.models.Channel.findByIdAndUpdate(channel, { isPrivate: true, members: [c.users.A._id] }); const victim = await connect(c, channel === ids.otherChannel ? 'C' : 'A'); const attacker = await connect(c, actor); await join(victim, channel); await join(attacker, channel, false); assert.equal((await c.http(actor, 'GET', `/api/channels/${channel}/messages`)).status, 403); return { victim, attacker }; };
    reg('socket denied join prevents channel edit delivery ' + label, async c => { const { victim, attacker } = await setup(c); const packets = collect(attacker, 'message_updated', p => String(p.messageId) === message); await controlEdit(c, victim, channel, message); await wait(QUIET); c.evidence.unauthorizedEvents = packets.length; c.evidence.authorizedControl = true; return packets.length === 0; }, actor);
    for (const [input, output] of [['typing_start', 'user_typing'], ['typing_stop', 'user_stopped_typing']]) reg('socket unauthorized ' + input + ' ' + label, async c => {
      const { victim, attacker } = await setup(c);
      const legitimate = await connect(c, channel === ids.otherChannel ? 'C' : 'A'); const control = once(victim, output); legitimate.emit(input, { channelId: channel }); await control;
      const packets = collect(victim, output, p => p.channelId === channel && String(p.userId) === String(c.users[actor]._id));
      attacker.emit(input, { channelId: channel, userId: String(c.users.A._id) }); await wait(QUIET);
      c.evidence.unauthorizedEvents = packets.length; c.evidence.serverAttributedAttacker = packets.length > 0; c.evidence.authorizedControl = true; return packets.length === 0;
    }, actor);
  }
  reg('private REST message personal-room audience', async c => {
    await c.models.Channel.findByIdAndUpdate(ids.channel, { isPrivate: true, members: [c.users.A._id] });
    const victim = await connect(c, 'A'); const excluded = await connect(c, 'B'); await join(victim, ids.channel);
    assert.equal((await c.http('B', 'GET', `/api/channels/${ids.channel}/messages`)).status, 403);
    const packets = collect(excluded, 'new_message', p => p.content?.text === 'Private delivery canary'); const control = once(victim, 'new_message');
    const r = await c.http('A', 'POST', `/api/channels/${ids.channel}/messages`, { content: { text: 'Private delivery canary' } }); assert.equal(r.status, 201); assert.equal((await control)._id, r.data.data.message._id); await wait(QUIET);
    c.evidence.unauthorizedEvents = packets.length; c.evidence.fullCanaryDisclosed = packets.some(p => p._id === r.data.data.message._id); c.evidence.authorizedControl = true; return packets.length === 0;
  }, 'B');
  for (const sync of [false, true]) reg('membership revocation stale channel room ' + (sync ? 'after sync' : 'before sync'), async c => {
    const owner = await connect(c, 'A'); const member = await connect(c, 'B'); await join(owner, ids.channel); await join(member, ids.channel);
    await controlEdit(c, member, ids.channel, ids.messageA);
    assert.equal((await c.http('A', 'DELETE', `/api/spaces/${ids.space}/members/${c.users.B._id}`)).status, 200);
    assert.equal((await c.http('B', 'GET', `/api/channels/${ids.channel}/messages`)).status, 403);
    if (sync) { const done = once(member, 'sync_space_rooms'); member.emit('sync_space_rooms', {}); await done; }
    const packets = collect(member, 'message_updated', p => String(p.messageId) === ids.messageA);
    await controlEdit(c, owner, ids.channel, ids.messageA); await wait(QUIET); c.evidence.unauthorizedEvents = packets.length; c.evidence.authorizedControl = true; return packets.length === 0;
  }, 'B');
  reg('explicit leave removes channel-only delivery', async c => {
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); await join(a, ids.channel); await join(b, ids.channel); await controlEdit(c, b, ids.channel, ids.messageA);
    b.emit('leave_channel', { channelId: ids.channel }); await wait(100);
    const packets = collect(b, 'message_updated', p => String(p.messageId) === ids.messageA); await controlEdit(c, a, ids.channel, ids.messageA); await wait(QUIET); c.evidence.eventsAfterLeave = packets.length; return packets.length === 0;
  });
  reg('server event injection cannot relay or persist messages', async c => {
    const a = await connect(c, 'A'); const b = await connect(c, 'B'); await join(a, ids.channel); await join(b, ids.channel);
    const before = await c.models.Message.countDocuments(); const packets = collect(b, 'new_message', p => p.content?.text === 'Forged socket canary');
    a.emit('new_message', { channelId: ids.channel, content: { text: 'Forged socket canary' } });
    a.emit('send_message', { channelId: ids.channel, content: { text: 'Forged socket canary' } });
    await controlEdit(c, b, ids.channel, ids.messageA); await wait(QUIET); c.evidence.injectedEvents = packets.length; return packets.length === 0 && await c.models.Message.countDocuments() === before;
  });
  reg('fresh reconnect rechecks revoked membership', async c => {
    const old = await connect(c, 'B'); await join(old, ids.channel); old.disconnect(); await wait(150);
    assert.equal((await c.http('A', 'DELETE', `/api/spaces/${ids.space}/members/${c.users.B._id}`)).status, 200);
    const fresh = await connect(c, 'B'); await join(fresh, ids.channel, false);
    const a = await connect(c, 'A'); await join(a, ids.channel); const packets = collect(fresh, 'message_updated', p => String(p.messageId) === ids.messageA); await controlEdit(c, a, ids.channel, ids.messageA); await wait(QUIET); c.evidence.eventsAfterReconnect = packets.length; return packets.length === 0;
  });
};
