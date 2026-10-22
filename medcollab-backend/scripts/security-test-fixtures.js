#!/usr/bin/env node

/**
 * Deterministic fixtures for the disposable CI security-test database only.
 * This script deliberately refuses any environment other than NODE_ENV=test
 * and the local vocle_ci MongoDB instance used by the GitHub Actions workflow.
 */

require('dotenv').config();

const mongoose = require('mongoose');
const User = require('../src/features/users/user.model');
const Space = require('../src/features/spaces/space.model');
const Channel = require('../src/features/channels/channel.model');
const Message = require('../src/features/messages/message.model');
const Handoff = require('../src/features/handoffs/handoff.model');
const {
  USER_ROLES,
  SPACE_TYPES,
  SPACE_ROLES,
  CHANNEL_TYPES,
  MESSAGE_TYPES,
  MESSAGE_PRIORITY,
  HANDOFF_STATUS,
  SHIFT_TYPES,
  PATIENT_STATUS,
} = require('../src/constants');

const TEST_DATABASE_URI = 'mongodb://127.0.0.1:27017/vocle_ci';
const FIXTURE = {
  users: [
    {
      key: 'userA',
      phone: '+15550000001',
      name: 'Vocle Security User A',
      role: USER_ROLES.CONSULTANT,
    },
    {
      key: 'userB',
      phone: '+15550000002',
      name: 'Vocle Security User B',
      role: USER_ROLES.PG_RESIDENT,
    },
    {
      key: 'userC',
      phone: '+15550000003',
      name: 'Vocle Security User C',
      role: USER_ROLES.INTERN,
    },
    // D shares the institution but no space with A/B/C. E–H deliberately do
    // not share an institution or space with one another; they exercise the
    // stranger message-request boundary rather than a superficial outsider.
    { key: 'userD', phone: '+15550000004', name: 'Vocle Security User D', role: USER_ROLES.CONSULTANT },
    { key: 'userE', phone: '+15550000005', name: 'Vocle Security User E', role: USER_ROLES.PG_RESIDENT, institution: 'Vocle External Alpha' },
    { key: 'userF', phone: '+15550000006', name: 'Vocle Security User F', role: USER_ROLES.NURSE, institution: 'Vocle External Beta' },
    { key: 'userG', phone: '+15550000007', name: 'Vocle Security User G', role: USER_ROLES.INTERN, institution: 'Vocle External Gamma' },
    // H is unrelated to F but explicitly opts in, so request lifecycle cases
    // exercise the intended stranger-request path without weakening production rules.
    { key: 'userH', phone: '+15550000008', name: 'Vocle Security User H', role: USER_ROLES.JUNIOR_CONSULTANT, institution: 'Vocle External Delta', allowMessageRequestsFromAnyone: true },
    // This identity is intentionally inactive and is never authenticated.
    { key: 'userI', phone: '+15550000009', name: 'Vocle Security User I', role: USER_ROLES.CONSULTANT, institution: 'Vocle CI Fixture', isActive: false },
  ],
  inviteCode: 'VCLTST',
  spaceName: 'Vocle Security Test Space',
  channelName: 'security-test',
  messages: {
    userA: 'Security fixture message from userA.',
    userB: 'Security fixture message from userB.',
  },
  shiftDate: new Date('2025-01-15T00:00:00.000Z'),
};

function assertSafeEnvironment() {
  if (process.env.NODE_ENV !== 'test') {
    throw new Error('Security fixtures may run only with NODE_ENV=test');
  }
  if (process.env.MONGODB_URI !== TEST_DATABASE_URI) {
    throw new Error('Security fixtures may run only against the local vocle_ci database');
  }
}

async function connect() {
  assertSafeEnvironment();
  await mongoose.connect(TEST_DATABASE_URI, { serverSelectionTimeoutMS: 10000 });
}

async function seed() {
  const users = {};
  for (const fixtureUser of FIXTURE.users) {
    users[fixtureUser.key] = await User.findOneAndUpdate(
      { phone: fixtureUser.phone },
      {
        $set: {
          name: fixtureUser.name,
          role: fixtureUser.role,
          speciality: 'Security Test Only',
          institution: fixtureUser.institution || 'Vocle CI Fixture',
          isVerified: true,
          isOnboarded: true,
          isActive: fixtureUser.isActive !== false,
          fcmTokens: [],
          'notifications.allowMessageRequestsFromAnyone': fixtureUser.allowMessageRequestsFromAnyone === true,
        },
      },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    );
  }

  const space = await Space.findOneAndUpdate(
    { inviteCode: FIXTURE.inviteCode },
    {
      $set: {
        name: FIXTURE.spaceName,
        description: 'Disposable CI fixtures for authorization testing.',
        type: SPACE_TYPES.DEPARTMENT,
        createdBy: users.userA._id,
        isActive: true,
        members: [
          { userId: users.userA._id, role: SPACE_ROLES.OWNER },
          { userId: users.userB._id, role: SPACE_ROLES.MEMBER },
        ],
        pendingRequests: [],
        settings: { requireApproval: false, onlyAdminsCanAnnounce: true },
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );

  const channel = await Channel.findOneAndUpdate(
    { spaceId: space._id, name: FIXTURE.channelName },
    {
      $set: {
        description: 'Disposable CI channel for authorization fixtures.',
        type: CHANNEL_TYPES.GENERAL,
        isPrivate: false,
        members: [],
        onlyAdminsCanPost: false,
        position: 10,
        isArchived: false,
        createdBy: users.userA._id,
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );

  const messageA = await Message.findOneAndUpdate(
    { channelId: channel._id, senderId: users.userA._id, 'content.text': FIXTURE.messages.userA },
    {
      $set: {
        spaceId: space._id,
        type: MESSAGE_TYPES.TEXT,
        content: { text: FIXTURE.messages.userA },
        priority: MESSAGE_PRIORITY.NORMAL,
        threadId: null,
        isDeleted: false,
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );

  const messageB = await Message.findOneAndUpdate(
    { channelId: channel._id, senderId: users.userB._id, 'content.text': FIXTURE.messages.userB },
    {
      $set: {
        spaceId: space._id,
        type: MESSAGE_TYPES.TEXT,
        content: { text: FIXTURE.messages.userB },
        priority: MESSAGE_PRIORITY.NORMAL,
        threadId: null,
        isDeleted: false,
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );

  await Channel.findByIdAndUpdate(channel._id, {
    lastMessage: {
      messageId: messageB._id,
      text: FIXTURE.messages.userB,
      senderName: users.userB.name,
      type: MESSAGE_TYPES.TEXT,
      sentAt: messageB.createdAt,
    },
  });

  const handoff = await Handoff.findOneAndUpdate(
    {
      spaceId: space._id,
      channelId: channel._id,
      fromUserId: users.userA._id,
      toUserId: users.userB._id,
      shiftDate: FIXTURE.shiftDate,
      shiftType: SHIFT_TYPES.MORNING,
    },
    {
      $set: {
        patients: [
          {
            bedNumber: 'CI-01',
            ward: 'Simulation',
            clinicalAlias: 'Synthetic fixture only',
            diagnosis: 'Non-clinical CI fixture',
            status: PATIENT_STATUS.STABLE,
            notes: 'No real patient data.',
            pendingTasks: ['Verify authorization boundaries'],
          },
        ],
        shiftSummary: 'Disposable authorization fixture handoff.',
        status: HANDOFF_STATUS.SUBMITTED,
        submittedAt: FIXTURE.shiftDate,
        acknowledgedAt: null,
        acknowledgementNote: '',
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );

  return { users, space, channel, messageA, messageB, handoff };
}

async function verify() {
  const users = {};
  for (const fixtureUser of FIXTURE.users) {
    users[fixtureUser.key] = await User.findOne({ phone: fixtureUser.phone });
    if (!users[fixtureUser.key]) throw new Error(`Missing fixture ${fixtureUser.key}`);
  }

  const space = await Space.findOne({ inviteCode: FIXTURE.inviteCode });
  if (!space) throw new Error('Missing fixture space');
  if (space.getMemberRole(users.userA._id) !== SPACE_ROLES.OWNER) {
    throw new Error('userA is not the fixture space owner');
  }
  if (!space.isMember(users.userB._id)) throw new Error('userB is not a fixture space member');
  if (space.isMember(users.userC._id)) throw new Error('userC must not be a fixture space member');
  if (space.isMember(users.userD._id)) throw new Error('userD must not share the fixture space');
  if (users.userD.institution !== users.userA.institution) throw new Error('userD must be a same-institution peer');
  if (users.userE.institution === users.userF.institution) throw new Error('message-request fixtures must be genuinely unrelated');
  if (!users.userH.notifications?.allowMessageRequestsFromAnyone) throw new Error('userH must opt in to stranger message requests');
  if (users.userI.isActive) throw new Error('userI must remain inactive for target-eligibility checks');

  const channel = await Channel.findOne({ spaceId: space._id, name: FIXTURE.channelName, isArchived: false });
  if (!channel) throw new Error('Missing fixture channel');

  const [messageA, messageB] = await Promise.all([
    Message.exists({ channelId: channel._id, senderId: users.userA._id, 'content.text': FIXTURE.messages.userA, isDeleted: false }),
    Message.exists({ channelId: channel._id, senderId: users.userB._id, 'content.text': FIXTURE.messages.userB, isDeleted: false }),
  ]);
  if (!messageA || !messageB) throw new Error('Missing fixture messages');

  const handoff = await Handoff.findOne({
    spaceId: space._id,
    channelId: channel._id,
    fromUserId: users.userA._id,
    toUserId: users.userB._id,
    shiftDate: FIXTURE.shiftDate,
    shiftType: SHIFT_TYPES.MORNING,
    status: HANDOFF_STATUS.SUBMITTED,
  });
  if (!handoff) throw new Error('Missing submitted fixture handoff from userA to userB');

  return { users, space, channel, handoff };
}

function printSummary(result) {
  console.log(
    `Security fixtures ready: userA (${result.users.userA.role}) owns "${result.space.name}"; ` +
    `userB (${result.users.userB.role}) is a member; userC is excluded; ` +
    `#${result.channel.name} has messages from userA and userB; handoff is submitted from userA to userB.`,
  );
}

async function main() {
  await connect();
  try {
    const result = process.argv.includes('--verify') ? await verify() : await seed();
    if (!process.argv.includes('--verify')) await verify();
    printSummary(result);
  } finally {
    await mongoose.disconnect();
  }
}

main().catch((error) => {
  console.error(`Security fixture setup failed: ${error.message}`);
  process.exit(1);
});
