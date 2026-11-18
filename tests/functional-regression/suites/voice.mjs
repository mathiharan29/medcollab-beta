import assert from 'node:assert/strict';
import { syntheticWav, uploadVoice } from '../src/audio-fixture.mjs';
import { backendRoot } from '../src/config.mjs';
import { backendRequire } from '../src/db.mjs';
import { runModule } from '../src/module-runner.mjs';
import { connectSocket, waitFor } from '../src/socket.mjs';

async function conversations({ identity, request }, labels) {
  const [a, b, c, outsider] = await Promise.all(labels.map(identity));
  const { data } = await request('/api/spaces', {
    method: 'POST', token: a.token, body: { name: 'Synthetic Voice Ward', type: 'department' }, expectedStatus: 201,
  });
  for (const person of [b, c]) await request('/api/spaces/join', {
    method: 'POST', token: person.token, body: { inviteCode: data.space.inviteCode },
  });
  const consent = await request('/api/message-requests', {
    method: 'POST', token: a.token, body: { toUserId: b.userId }, expectedStatus: 201,
  });
  await request(`/api/message-requests/${consent.data.request.id}/accept`, { method: 'POST', token: b.token });
  const dm = (await request('/api/channels/dm', {
    method: 'POST', token: a.token, body: { userId: b.userId },
  })).data.channel._id;
  const needl = (await request('/api/channels/dm/group', {
    method: 'POST', token: a.token, body: { userIds: [b.userId, c.userId] },
  })).data.channel._id;
  return { a, b, c, outsider, dm, needl };
}

const history = (channelId) => `/api/channels/${channelId}/messages`;
// Needl Voice is a separate space (beta feedback 2026-11-18): clips are read
// from the voice history; the text chat history never contains them.
const voiceHistory = (channelId) => `/api/channels/${channelId}/messages?mode=voice`;
const transcriptPath = (channelId, messageId) => `${history(channelId)}/${messageId}/transcript`;

async function sendVoice(request, token, channelId, media) {
  const content = { mediaUrl: media.url, mimeType: media.mimeType, durationMs: 1000,
    waveform: [10, 60, 30], transcriptStatus: 'pending', voiceMode: true };
  const { data } = await request(history(channelId), {
    method: 'POST', token, body: { type: 'audio', content }, expectedStatus: 201,
  });
  for (const [key, value] of Object.entries(content)) assert.deepEqual(data.message.content[key], value);
  return data.message;
}

async function join(socket, channelId) {
  const joined = waitFor(socket, 'join_channel', event => event.channelId === channelId && event.success);
  socket.emit('join_channel', { channelId });
  await joined;
}

const edit = (request, token, channelId, id, body, expectedStatus = 200) =>
  request(transcriptPath(channelId, id), { method: 'PATCH', token, body, expectedStatus });

await runModule('voice', [{
  id: 'FR-VCE-01', module: 'VCE',
  run: async (context) => {
    const { a, b, dm } = await conversations(context, ['A', 'B', 'C', 'D']);
    const { origin, request } = context;
    const bytes = syntheticWav();
    const media = await uploadVoice(request, a.token, 'direct-voice.wav', 'message', bytes);
    const receiver = await connectSocket(null, origin, b.token);
    const sender = await connectSocket(null, origin, a.token);
    try {
      await join(receiver, dm);
      const typing = waitFor(receiver, 'user_typing', event => event.channelId === dm && event.userId === a.userId);
      sender.emit('typing_start', { channelId: dm, kind: 'voice' });
      assert.equal((await typing).kind, 'voice');

      // Attach listeners before triggering each write. Await the request and its
      // matching socket event together so failures remain visible.
      const delivery = waitFor(receiver, 'new_message', event => event.channelId === dm && event.type === 'audio');
      const [live, clip] = await Promise.all([delivery, sendVoice(request, a.token, dm, media)]);
      assert.equal(live._id, clip._id);
      assert.equal(live.content.transcriptStatus, 'pending');
      assert.equal(live.content.voiceMode, true);

      const text = 'Synthetic voice transcript veridian';
      const update = waitFor(receiver, 'message_updated', event => event.messageId === clip._id);
      const [event, saved] = await Promise.all([update, edit(request, a.token, dm, clip._id, { status: 'done', transcript: text })]);
      // Transcript updates identify the clip and are scoped to the joined room.
      assert.equal(event.messageId, clip._id);
      for (const content of [event.content, saved.data.message.content]) {
        assert.equal(content.transcript, text);
        assert.equal(content.transcriptStatus, 'done');
        assert.equal(content.mediaUrl, media.url);
      }

      const chatHistory = (await request(history(dm), { token: b.token })).data.messages;
      assert.ok(chatHistory.every(message => message._id !== clip._id), 'Needl Voice clips stay out of the text chat');
      const reloaded = (await request(voiceHistory(dm), { token: b.token })).data.messages.filter(message => message._id === clip._id);
      assert.equal(reloaded.length, 1);
      assert.equal(reloaded[0].content.transcript, text);
      assert.equal(reloaded[0].content.transcriptStatus, 'done');
      assert.equal(new URL(media.url).origin, origin);
      const download = await fetch(media.url, { headers: { authorization: `Bearer ${b.token}` }, signal: AbortSignal.timeout(10000) });
      assert.equal(download.status, 200);
      assert.deepEqual(Buffer.from(await download.arrayBuffer()), bytes);
    } finally {
      receiver.disconnect();
      sender.disconnect();
    }
  },
}, {
  id: 'FR-VCE-02', module: 'VCE',
  run: async (context) => {
    const { a, b, c, outsider, dm, needl } = await conversations(context, ['E', 'F', 'G', 'H']);
    const { request } = context;
    const voice = await uploadVoice(request, a.token, 'group-voice.wav', 'message', syntheticWav());
    const clip = await sendVoice(request, a.token, needl, voice);
    const query = '/api/search?q=zephyrite';
    const matches = async (person) => (await request(query, { token: person.token })).data.messages.map(message => message._id);
    assert.deepEqual(await matches(b), []);
    await edit(request, a.token, needl, clip._id, { status: 'done', transcript: 'Synthetic zephyrite update' });
    assert.deepEqual(await matches(b), [clip._id]);
    assert.deepEqual(await matches(c), [clip._id]);
    assert.deepEqual(await matches(outsider), []);
    const dmHistory = (await request(history(dm), { token: b.token })).data.messages;
    assert.ok(dmHistory.every(message => message._id !== clip._id));
    await request(`${history(needl)}/${clip._id}?scope=me`, { method: 'DELETE', token: b.token });
    assert.deepEqual(await matches(b), []);
    assert.deepEqual(await matches(c), [clip._id], 'A personal deletion cannot hide audio for another Needl member');
    const peerHistory = (await request(voiceHistory(needl), { token: c.token })).data.messages;
    const visible = peerHistory.find(message => message._id === clip._id);
    assert.equal(visible.content.mediaUrl, voice.url);
    assert.equal(visible.content.transcript, 'Synthetic zephyrite update');
  },
}, {
  id: 'FR-VCE-03', module: 'VCE',
  run: async (context) => {
    const { a, b, outsider, dm, needl } = await conversations(context, ['I', 'J', 'K', 'J4A']);
    const { request } = context;
    const voice = await uploadVoice(request, a.token, 'recover-voice.wav', 'message', syntheticWav());
    const clip = await sendVoice(request, a.token, dm, voice);
    const valid = { status: 'done', transcript: 'Synthetic voice recovered' };
    const { refreshToken } = a;
    const jwt = backendRequire(backendRoot)('jsonwebtoken');
    const expired = jwt.sign({ userId: a.userId }, 'synthetic-access-secret-00000000000000000000000000000001', { expiresIn: -1 });
    await edit(request, expired, dm, clip._id, valid, 401);
    await edit(request, b.token, dm, clip._id, valid, 403);
    await edit(request, outsider.token, dm, clip._id, valid, 403);
    await edit(request, a.token, needl, clip._id, valid, 403);
    await edit(request, a.token, dm, clip._id, { status: 'done', transcript: 'x'.repeat(8001) }, 400);
    await edit(request, a.token, dm, clip._id, { status: 'unknown' }, 400);
    const text = (await request(history(dm), {
      method: 'POST', token: a.token, body: { type: 'text', content: { text: 'Synthetic text control' } }, expectedStatus: 201,
    })).data.message;
    await edit(request, a.token, dm, text._id, valid, 400);
    const read = async () => (await request(voiceHistory(dm), { token: b.token })).data.messages.find(message => message._id === clip._id).content;
    assert.equal((await read()).transcriptStatus, 'pending');
    assert.equal((await read()).transcript ?? null, null);
    const renewed = await request('/api/auth/refresh', { method: 'POST', body: { refreshToken } });
    await edit(request, renewed.data.accessToken, dm, clip._id, valid);
    assert.equal((await read()).transcript, valid.transcript);
    await edit(request, renewed.data.accessToken, dm, clip._id, { status: 'unavailable' });
    const unavailable = await read();
    assert.equal(unavailable.transcriptStatus, 'unavailable');
    assert.equal(unavailable.transcript ?? null, null);
    assert.equal(unavailable.mediaUrl, voice.url);
  },
}]);
