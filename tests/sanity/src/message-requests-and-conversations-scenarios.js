import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createFixtureUsers } from './fixtures.js';
import { closeDatabase, connectDatabase, messageById, notificationFor } from './database.js';
import { expectSuccess, request } from './http.js';

const results = [];
const assert = (value, message) => { if (!value) throw new Error(message); };
const marker = (name) => `sanity-conversation-${name}`;
async function eventuallyNotification(label, userId, referenceId) {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    const notification = await notificationFor(userId, referenceId);
    if (notification) return notification;
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 100));
  }
  throw new Error(`${label} was not persisted within 5 seconds (request state was persisted).`);
}
async function scenario(id, action, prerequisite = true) {
  const startedAt = Date.now();
  if (!prerequisite) { results.push({ id, status: 'blocked', durationMs: 0, error: 'Required request, conversation, or message fixture was not created.' }); return; }
  try { await action(); results.push({ id, status: 'passed', durationMs: Date.now() - startedAt }); }
  catch (error) { results.push({ id, status: 'failed', durationMs: Date.now() - startedAt, error: error.message }); console.error(`${id}: ${error.stack || error.message}`); }
}
async function send(channelId, token, text) {
  return expectSuccess(await request(`/api/channels/${channelId}/messages`, {
    method: 'POST', token, expectedStatus: 201, body: { type: 'text', content: { text } },
  }), `send ${text}`).message;
}

async function run() {
  await connectDatabase();
  const people = await createFixtureUsers();
  let acceptedRequest; let dm; let dmMessage;
  try {
    const groupFixture = expectSuccess(await request('/api/spaces', {
      method: 'POST', token: people.A.token, expectedStatus: 201,
      body: { name: 'Sanity Conversation Group', type: 'department', description: 'Group DM eligibility fixture' },
    }), 'create conversation group fixture').space;
    await request('/api/spaces/join', { method: 'POST', token: people.B.token, body: { inviteCode: groupFixture.inviteCode } });
    await request('/api/spaces/join', { method: 'POST', token: people.C.token, body: { inviteCode: groupFixture.inviteCode } });
    await request('/api/users/me', { method: 'PUT', token: people.D.token, body: { notifications: { allowMessageRequestsFromAnyone: true } } });
    await request('/api/users/me', { method: 'PUT', token: people.E.token, body: { notifications: { allowMessageRequestsFromAnyone: true } } });

    await scenario('message-requests-01', async () => {
      const lookup = expectSuccess(await request(`/api/users/lookup?phone=${encodeURIComponent(people.D.phone)}`, { token: people.A.token }), 'lookup eligible peer');
      assert(lookup.canRequest === true && lookup.canMessage === false, 'Lookup did not identify a request-eligible peer.');
      const created = expectSuccess(await request('/api/message-requests', {
        method: 'POST', token: people.A.token, expectedStatus: 201, body: { toUserId: people.D.userId, introMessage: marker('intro') },
      }), 'create message request');
      acceptedRequest = created.request;
      const duplicate = expectSuccess(await request('/api/message-requests', {
        method: 'POST', token: people.A.token, body: { toUserId: people.D.userId, introMessage: marker('intro') },
      }), 'repeat message request');
      const [sent, received, pending] = await Promise.all([
        request('/api/message-requests?direction=sent', { token: people.A.token }),
        request('/api/message-requests?direction=received', { token: people.D.token }),
        request('/api/message-requests/pending-count', { token: people.D.token }),
      ]);
      const notification = await eventuallyNotification('Recipient message-request notification', people.D.userId, acceptedRequest.id);
      assert(duplicate.request.id === acceptedRequest.id, 'Duplicate request was not stable.');
      assert(expectSuccess(sent, 'sent requests').requests.some((item) => item.id === acceptedRequest.id), 'Sent request was missing.');
      assert(expectSuccess(received, 'received requests').requests.some((item) => item.id === acceptedRequest.id), 'Received request was missing.');
      assert(expectSuccess(pending, 'pending count').count === 1, 'Pending request count was incorrect.');
      assert(notification?.type === 'message_request' && notification.referenceType === 'MessageRequest', 'Recipient notification was not persisted.');
    });

    await scenario('message-requests-02', async () => {
      const accepted = expectSuccess(await request(`/api/message-requests/${acceptedRequest.id}/accept`, { method: 'POST', token: people.D.token }), 'accept request');
      dm = accepted.channel;
      const [fromList, toList] = await Promise.all([
        request('/api/channels/dm', { token: people.A.token }), request('/api/channels/dm', { token: people.D.token }),
      ]);
      const notification = await eventuallyNotification('Sender request-acceptance notification', people.A.userId, acceptedRequest.id);
      assert(accepted.request.status === 'accepted' && dm?.peer?._id === people.A.userId, 'Accepted request did not create the expected DM.');
      assert(expectSuccess(fromList, 'sender DM list').channels.some((channel) => channel._id === dm._id), 'Accepted DM missing for sender.');
      assert(expectSuccess(toList, 'recipient DM list').channels.some((channel) => channel._id === dm._id), 'Accepted DM missing for recipient.');
      assert(notification?.metadata?.channelId?.toString() === dm._id, 'Acceptance notification was not persisted for sender.');
    }, Boolean(acceptedRequest));

    await scenario('message-requests-03', async () => {
      const declined = expectSuccess(await request('/api/message-requests', {
        method: 'POST', token: people.A.token, expectedStatus: 201, body: { toUserId: people.E.userId, introMessage: marker('decline') },
      }), 'create disposable request').request;
      const declinedResult = expectSuccess(await request(`/api/message-requests/${declined.id}/decline`, { method: 'POST', token: people.E.token }), 'decline request');
      await request(`/api/message-requests/${declined.id}/decline`, { method: 'POST', token: people.E.token, expectedStatus: 400 });
      const count = expectSuccess(await request('/api/message-requests/pending-count', { token: people.E.token }), 'pending count after decline');
      assert(declinedResult.request.status === 'declined' && count.count === 0, 'Declining a request did not finish its lifecycle.');
    });

    await scenario('direct-and-group-conversations-01', async () => {
      const [fromA, fromD] = await Promise.all([
        request('/api/channels/dm', { method: 'POST', token: people.A.token, body: { userId: people.D.userId } }),
        request('/api/channels/dm', { method: 'POST', token: people.D.token, body: { userId: people.A.userId } }),
      ]);
      assert(expectSuccess(fromA, 'reopen sender DM').channel._id === dm._id && expectSuccess(fromD, 'reopen recipient DM').channel._id === dm._id, 'Accepted DM did not reopen to one stable ID.');
    }, Boolean(dm));

    await scenario('direct-and-group-conversations-02', async () => {
      dmMessage = await send(dm._id, people.A.token, marker('dm-message'));
      const [detail, messages, sidebar] = await Promise.all([
        request(`/api/channels/${dm._id}`, { token: people.D.token }), request(`/api/channels/${dm._id}/messages`, { token: people.D.token }), request('/api/channels/dm', { token: people.D.token }),
      ]);
      assert(expectSuccess(detail, 'DM detail').channel.peer?._id === people.A.userId, 'DM peer details were incorrect.');
      assert(expectSuccess(messages, 'DM messages').messages.some((message) => message._id === dmMessage._id), 'DM message was not readable.');
      assert(expectSuccess(sidebar, 'DM sidebar').channels.find((channel) => channel._id === dm._id)?.lastMessage?.text === marker('dm-message'), 'DM last-message preview was incorrect.');
    }, Boolean(dm));

    await scenario('direct-and-group-conversations-03', async () => {
      await request(`/api/channels/${dm._id}/messages/read`, { method: 'POST', token: people.D.token, body: { messageIds: [dmMessage._id] } });
      await request(`/api/channels/${dm._id}/messages/read`, { method: 'POST', token: people.D.token, body: { messageIds: [dmMessage._id] } });
      const read = await messageById(dmMessage._id);
      await request('/api/users/me', { method: 'PUT', token: people.D.token, body: { notifications: { readReceiptsEnabled: false } } });
      const privateMessage = await send(dm._id, people.A.token, marker('private-read'));
      await request(`/api/channels/${dm._id}/messages/read`, { method: 'POST', token: people.D.token, body: { messageIds: [privateMessage._id] } });
      const privateRead = await messageById(privateMessage._id);
      assert((read.readBy || []).filter((entry) => entry.userId.toString() === people.D.userId).length === 1, 'DM read receipt was not deduplicated.');
      assert(!(privateRead.readBy || []).some((entry) => entry.userId.toString() === people.D.userId), 'Read receipt was added despite disabled preference.');
    }, Boolean(dm && dmMessage));

    await scenario('direct-and-group-conversations-04', async () => {
      const notes = expectSuccess(await request('/api/channels/dm', { method: 'POST', token: people.A.token, body: { userId: people.A.userId } }), 'open self notes').channel;
      await send(notes._id, people.A.token, marker('note'));
      const group = expectSuccess(await request('/api/channels/dm/group', { method: 'POST', token: people.A.token, body: { userIds: [people.B.userId, people.C.userId] } }), 'create group DM').channel;
      const reopened = expectSuccess(await request('/api/channels/dm/group', { method: 'POST', token: people.A.token, body: { userIds: [people.C.userId, people.B.userId] } }), 'reopen group DM').channel;
      const renamed = expectSuccess(await request(`/api/channels/${group._id}`, { method: 'PUT', token: people.B.token, body: { name: 'Sanity group renamed' } }), 'rename group DM').channel;
      const storedNotes = expectSuccess(await request(`/api/channels/${notes._id}/messages`, { token: people.A.token }), 'read self note');
      assert(notes.isSelfNotes === true && storedNotes.messages.some((message) => message.content.text === marker('note')), 'Notes to self were not persistent.');
      assert(reopened._id === group._id && renamed.name === 'Sanity group renamed' && renamed.members.length === 3, 'Group DM did not preserve membership or rename.');
    });

    await scenario('direct-and-group-conversations-05', async () => {
      const sourceMessage = await send(dm._id, people.A.token, marker('expansion-source'));
      const none = expectSuccess(await request(`/api/channels/${dm._id}/expand`, { method: 'POST', token: people.A.token, body: { userIds: [people.B.userId], history: 'none' } }), 'expand without history').channel;
      const all = expectSuccess(await request(`/api/channels/${dm._id}/expand`, { method: 'POST', token: people.A.token, body: { userIds: [people.C.userId], history: 'all' } }), 'expand with history').channel;
      const [noneMessages, allMessages, sourceMessages] = await Promise.all([
        request(`/api/channels/${none._id}/messages`, { token: people.A.token }), request(`/api/channels/${all._id}/messages`, { token: people.A.token }), request(`/api/channels/${dm._id}/messages`, { token: people.A.token }),
      ]);
      assert(none.members.length === 3 && expectSuccess(noneMessages, 'no-history results').messages.length === 0, 'No-history expansion copied messages.');
      assert(all.members.length === 3 && expectSuccess(allMessages, 'all-history results').messages.some((message) => message.content.text === marker('expansion-source')), 'All-history expansion did not copy source content.');
      assert(expectSuccess(sourceMessages, 'source history').messages.some((message) => message._id === sourceMessage._id), 'Expansion changed source conversation history.');
    }, Boolean(dm));
  } finally {
    await closeDatabase();
    const output = resolve(process.env.SANITY_OUTPUT_DIR || 'output');
    await mkdir(output, { recursive: true });
    await writeFile(resolve(output, 'message-requests-and-conversations-results.json'), `${JSON.stringify({ expected: 8, results }, null, 2)}\n`);
  }
  const passed = results.filter((result) => result.status === 'passed').length;
  console.log(`Message-request and conversation scenarios passed: ${passed}/8.`);
  if (passed !== 8) process.exitCode = 1;
}

run().catch(async (error) => { console.error(error.stack || error.message); await closeDatabase(); process.exitCode = 1; });
