// Issue 8 (beta 11-14): adding a person to a Needl must reach everyone who
// has the old conversation open — live, with a way into the new Needl.
import { createRequire } from 'node:module';
import { api, doctor, dmBetween, send, check, eq, ok, sleep, summary, BASE } from './lib.mjs';

const require = createRequire(import.meta.url);
const { io } = require('socket.io-client');

const asha = await doctor('Asha Rao');
const bala = await doctor('Bala Krish');
const chitra = await doctor('Chitra Nair');
const dev = await doctor('Dev Menon');
const ab = await dmBetween(asha, bala);
await dmBetween(asha, chitra);
await dmBetween(asha, dev);

await send(asha, ab, 'Bed 7 needs a review');

// Needl Asha + Bala + Chitra
const n1r = await api(asha.token, 'POST', `/api/channels/${ab}/expand`, { userIds: [chitra.id], history: 'all' });
const n1 = n1r.data?.channel?._id;

// Bala keeps a live connection (as the app does) while Asha adds Dev.
const received = [];
const sock = io(BASE, { auth: { token: bala.token }, transports: ['websocket'], reconnection: false });
await new Promise((resolve, reject) => {
  sock.on('authenticated', resolve);
  sock.on('connect_error', reject);
  setTimeout(() => reject(new Error('socket timeout')), 8000);
});
sock.emit('join_channel', { channelId: n1 });
sock.on('new_message', (m) => received.push(m));
await sleep(300);

const n2r = await api(asha.token, 'POST', `/api/channels/${n1}/expand`, { userIds: [dev.id], history: 'all' });
const n2 = n2r.data?.channel?._id;
await sleep(800);

await check('8.1 expand creates the 4-person Needl and reports it as new', async () => {
  eq(n1r.status, 200, 'first expand');
  eq(n2r.status, 200, 'second expand');
  ok(n2 && n2 !== n1, 'new channel id');
  eq(n2r.data.createdNew, true);
  eq(n2r.data.channel.members.length, 4);
});

await check('8.2 Bala (in the old Needl) gets the "continued" line live, with the new id', async () => {
  const line = received.find((m) => m.channelId === n1 && m.type === 'system'
    && m.content?.systemEvent === 'needl_continued');
  ok(line, `no live line; got ${JSON.stringify(received.map((m) => m.content?.systemEvent))}`);
  eq(String(line.content.movedToChannelId), String(n2));
  ok(/added Dev Menon/.test(line.content.text), line.content.text);
});

await check('8.3 the line is stored in the old Needl (reopen shows it) and is its preview', async () => {
  const tl = (await api(bala.token, 'GET', `/api/channels/${n1}/messages`)).data.messages;
  const last = tl[tl.length - 1];
  eq(last.content.systemEvent, 'needl_continued');
  eq(String(last.content.movedToChannelId), String(n2));
  const list = (await api(bala.token, 'GET', '/api/channels/dm')).data.channels;
  ok(/continues in the new Needl/.test(list.find((c) => c._id === n1).lastMessage.text), 'preview');
});

await check('8.4 everyone can open the new Needl with the shared history; Dev is in it', async () => {
  for (const who of [asha, bala, chitra, dev]) {
    const r = await api(who.token, 'GET', `/api/channels/${n2}/messages`);
    eq(r.status, 200, who.name);
    ok(r.data.messages.some((m) => m.content?.text === 'Bed 7 needs a review'), `${who.name} history`);
  }
  const members = (await api(bala.token, 'GET', `/api/channels/${n2}/members`)).data.members;
  ok(members.some((m) => m._id === dev.id), 'dev listed');
});

await check('8.5 Dev cannot read the old 3-person Needl', async () => {
  const r = await api(dev.token, 'GET', `/api/channels/${n1}/messages`);
  ok(r.status === 403 || r.status === 404, `got ${r.status}`);
});

await check('8.6 adding nobody new is refused (no empty "continued" line)', async () => {
  const r = await api(asha.token, 'POST', `/api/channels/${n2}/expand`, { userIds: [bala.id] });
  eq(r.status, 400);
});

sock.close();
summary('Issue 8 Needl add reaches open chats');
