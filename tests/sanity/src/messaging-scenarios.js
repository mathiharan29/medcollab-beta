import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createFixtureUsers } from './fixtures.js';
import { closeDatabase, connectDatabase, messageById } from './database.js';
import { expectSuccess, request } from './http.js';
import { closeRealtime, connectRealtime, joinChannel } from './socket-client.js';

const results = [];
const assert = (value, message) => { if (!value) throw new Error(message); };
const marker = (name) => `sanity-message-${name}`;
async function scenario(id, action) {
  const startedAt = Date.now();
  try { await action(); results.push({ id, status: 'passed', durationMs: Date.now() - startedAt }); }
  catch (error) { results.push({ id, status: 'failed', durationMs: Date.now() - startedAt, error: error.message }); throw error; }
}
async function send(channelId, token, text, extra = {}) {
  return expectSuccess(await request(`/api/channels/${channelId}/messages`, {
    method: 'POST', token, expectedStatus: 201, body: { type: 'text', content: { text }, ...extra },
  }), `send ${text}`).message;
}

async function run() {
  await connectDatabase();
  const people = await createFixtureUsers();
  let space; let general; let emergency; let root; let clientA; let clientB;
  try {
    const created = expectSuccess(await request('/api/spaces', {
      method: 'POST', token: people.A.token, expectedStatus: 201,
      body: { name: 'Sanity Messaging Space', type: 'department', description: 'Messaging fixture' },
    }), 'create messaging space');
    space = created.space;
    general = created.channels.find((channel) => channel.name === 'general');
    emergency = created.channels.find((channel) => channel.name === 'emergency');
    await request('/api/spaces/join', { method: 'POST', token: people.B.token, body: { inviteCode: space.inviteCode } });
    clientA = await connectRealtime(people.A.token);
    clientB = await connectRealtime(people.B.token);
    await Promise.all([joinChannel(clientA, general._id), joinChannel(clientB, general._id)]);

    await scenario('messaging-and-needl-01', async () => {
      const event = clientB.waitFor('new_message', (payload) => payload?.content?.text === marker('text'));
      const message = await send(general._id, people.A.token, marker('text'));
      root = message;
      const delivered = await event;
      const listing = expectSuccess(await request(`/api/channels/${general._id}/messages`, { token: people.B.token }), 'read text message');
      const sidebar = expectSuccess(await request('/api/spaces', { token: people.A.token }), 'read sidebar');
      const listedChannel = sidebar.spaces.flatMap((item) => item.channels || []).find((channel) => channel._id === general._id);
      assert(message.senderId._id === people.A.userId && delivered._id === message._id, 'Text message sender or socket payload was incorrect.');
      assert(listing.messages.some((item) => item._id === message._id), 'Sent text was not readable.');
      assert(listedChannel?.lastMessage?.text === marker('text'), 'Sidebar preview did not persist.');
    });

    await scenario('messaging-and-needl-02', async () => {
      await send(general._id, people.A.token, marker('page-one'));
      await send(general._id, people.A.token, marker('page-two'));
      await send(general._id, people.A.token, marker('page-three'));
      const newest = expectSuccess(await request(`/api/channels/${general._id}/messages?limit=2`, { token: people.A.token }), 'first pagination page');
      const older = expectSuccess(await request(`/api/channels/${general._id}/messages?limit=2&before=${newest.messages[0]._id}`, { token: people.A.token }), 'older pagination page');
      const combined = [...older.messages, ...newest.messages];
      assert(newest.messages.length === 2 && older.messages.length > 0, 'Pagination did not produce two pages.');
      assert(new Set(combined.map((item) => item._id)).size === combined.length, 'Pagination pages overlapped.');
      assert(combined.every((item, index) => index === 0 || item._id > combined[index - 1]._id), 'Paginated roots were not ascending.');
    });

    await scenario('messaging-and-needl-03', async () => {
      const quoted = await send(general._id, people.B.token, marker('quote'), { replyToId: root._id });
      assert(quoted.replyTo?.messageId === root._id && quoted.replyTo?.text === marker('text'), 'Quote metadata was not retained.');
    });

    await scenario('messaging-and-needl-04', async () => {
      const reply = expectSuccess(await request(`/api/channels/${general._id}/messages/${root._id}/reply`, {
        method: 'POST', token: people.B.token, expectedStatus: 201, body: { type: 'text', content: { text: marker('thread-reply') } },
      }), 'reply to thread').message;
      const thread = expectSuccess(await request(`/api/channels/${general._id}/messages/${root._id}/thread`, { token: people.A.token }), 'read thread');
      const needl = expectSuccess(await request('/api/users/me/needl', { token: people.B.token }), 'read Needl');
      const refreshed = (await request(`/api/channels/${general._id}/messages?limit=100`, { token: people.A.token }));
      const refreshedRoot = expectSuccess(refreshed, 'read refreshed roots').messages.find((item) => item._id === root._id);
      assert(reply.threadId === root._id && thread.replies.some((item) => item._id === reply._id), 'Thread reply was not returned by thread endpoint.');
      assert(refreshedRoot?.replyCount === 1 && refreshedRoot.lastReply?.text === marker('thread-reply'), 'Thread root preview did not update.');
      assert(needl.threads.some((item) => item.rootMessageId === root._id), 'Needl omitted the relevant thread root.');
    });

    await scenario('messaging-and-needl-05', async () => {
      const editable = await send(general._id, people.A.token, marker('before-edit'));
      const updatedEvent = clientB.waitFor('message_updated', (payload) => payload?.messageId === editable._id && payload?.isEdited === true);
      const edited = expectSuccess(await request(`/api/channels/${general._id}/messages/${editable._id}`, {
        method: 'PUT', token: people.A.token, body: { content: { text: marker('after-edit') } },
      }), 'edit message').message;
      await updatedEvent;
      const deletedEvent = clientB.waitFor('message_deleted', (payload) => payload?.messageId === editable._id);
      await request(`/api/channels/${general._id}/messages/${editable._id}`, { method: 'DELETE', token: people.A.token });
      await deletedEvent;
      const stored = await messageById(editable._id);
      assert(edited.isEdited === true && edited.content.text === marker('after-edit'), 'Edit was not persisted.');
      assert(stored?.isDeleted === true, 'Delete was not a persisted soft deletion.');
    });

    await scenario('messaging-and-needl-06', async () => {
      const reacted = await send(general._id, people.A.token, marker('react'));
      const first = expectSuccess(await request(`/api/channels/${general._id}/messages/${reacted._id}/react`, { method: 'POST', token: people.B.token, body: { emoji: '👍' } }), 'add reaction');
      const second = expectSuccess(await request(`/api/channels/${general._id}/messages/${reacted._id}/react`, { method: 'POST', token: people.B.token, body: { emoji: '👍' } }), 'remove reaction');
      const pinned = expectSuccess(await request(`/api/channels/${general._id}/pin/${reacted._id}`, { method: 'POST', token: people.A.token }), 'pin message');
      const unpinned = expectSuccess(await request(`/api/channels/${general._id}/pin/${reacted._id}`, { method: 'DELETE', token: people.A.token }), 'unpin message');
      assert(first.reactions.some((reaction) => reaction.emoji === '👍'), 'Reaction was not added.');
      assert(!second.reactions.some((reaction) => reaction.emoji === '👍') && pinned.pinnedMessages.length === 1 && unpinned.pinnedMessages.length === 0, 'Reaction toggle or pin lifecycle did not persist.');
    });

    await scenario('messaging-and-needl-07', async () => {
      await request(`/api/channels/${general._id}/messages`, { method: 'POST', token: people.A.token, expectedStatus: 400, body: { type: 'text', content: { text: '' } } });
      const message = await send(emergency._id, people.A.token, marker('emergency'), { priority: 'normal' });
      assert(message.priority === 'emergency', 'Emergency channel did not override message priority.');
    });
  } finally {
    closeRealtime(clientA); closeRealtime(clientB); await closeDatabase();
    const output = resolve(process.env.SANITY_OUTPUT_DIR || 'output');
    await mkdir(output, { recursive: true });
    await writeFile(resolve(output, 'messaging-results.json'), `${JSON.stringify({ expected: 7, results }, null, 2)}\n`);
  }
  console.log('Messaging scenarios passed: 7/7.');
}

run().catch(async (error) => { console.error(error.stack || error.message); await closeDatabase(); process.exitCode = 1; });
