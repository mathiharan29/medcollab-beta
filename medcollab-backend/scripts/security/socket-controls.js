'use strict';
const assert = require('node:assert/strict');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
const QUIET = 1000;
function once(socket, event, predicate = () => true, timeout = 5000) {
  return new Promise((resolve, reject) => {
    const listener = payload => { if (!predicate(payload)) return; clearTimeout(timer); socket.off(event, listener); resolve(payload); };
    const timer = setTimeout(() => { socket.off(event, listener); reject(new Error(`Missing socket control: ${event}`)); }, timeout);
    socket.on(event, listener);
  });
}
async function until(predicate, label, timeout = 5000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) { if (await predicate()) return; await wait(25); }
  throw new Error(`Missing bounded control: ${label}`);
}
async function connect(c, actor, options = {}) {
  const { base = 'http://127.0.0.1:5000', negative = false, auth = {} } = options;
  assert.ok(['http://127.0.0.1:5000', 'http://127.0.0.1:5102'].includes(base));
  const socket = require('socket.io-client').io(base, { autoConnect: false, reconnection: false, forceNew: true, transports: ['websocket'], auth: { token: c.tokens[actor], ...auth } });
  c.cleanup.push(() => socket.disconnect());
  const ready = once(socket, negative ? 'connect_error' : 'authenticated'); socket.connect();
  const payload = await ready;
  if (!negative) assert.equal(String(payload.userId), String(c.users[actor]._id), 'Authenticated socket identity control failed');
  else assert.ok(!socket.connected, 'Negative handshake unexpectedly connected');
  return socket;
}
async function join(socket, channelId, allowed = true) {
  const ready = once(socket, allowed ? 'join_channel' : 'error'); socket.emit('join_channel', { channelId });
  const p = await ready;
  if (allowed) assert.ok(p.success && p.channelId === channelId, 'Channel join control failed');
  else assert.ok(typeof p.message === 'string');
}
function collect(socket, event, predicate = () => true) { const packets = []; socket.on(event, p => { if (predicate(p)) packets.push(p); }); return packets; }
async function edit(c, socket, channelId, messageId, actor = 'A', text = 'Deep realtime control', http = c.http) {
  const received = once(socket, 'message_updated', p => String(p.messageId) === messageId && p.content?.text === text);
  const r = await http(actor, 'PUT', `/api/channels/${channelId}/messages/${messageId}`, { content: { text } });
  assert.equal(r.status, 200, 'REST event producer failed'); await received;
  c.evidence.authorizedControl = true;
}
async function availability(c, socket, observer, status = 'on_call', actor = 'A') {
  const received = once(observer, 'presence_update', p => String(p.userId) === String(c.users[actor]._id) && p.availability?.status === status);
  socket.emit('update_availability', { status }); await received;
  await until(async () => (await c.models.User.findById(c.users[actor]._id).lean()).availability?.status === status, 'availability persistence');
  c.evidence.authorizedControl = true;
}
module.exports = { once, until, connect, join, collect, edit, availability, wait, QUIET };
