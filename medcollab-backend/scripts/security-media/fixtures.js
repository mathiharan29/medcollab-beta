'use strict';
const assert = require('node:assert/strict');
const ids = { space: '7ec000000000000000000001', otherSpace: '7ec000000000000000000002', channel: '7ec000000000000000000003', otherChannel: '7ec000000000000000000004', handoff: '7ec000000000000000000008', dmOther: '7ec00000000000000000000a' };
function load() {
  const models = Object.fromEntries(['User', 'Space', 'Channel', 'Message', 'Handoff', 'Notification'].map(n => [n, require(`../../src/features/${n === 'Handoff' ? 'handoffs' : n.toLowerCase() + 's'}/${n.toLowerCase()}.model`)]));
  models.OTP = require('../../src/features/auth/otp.model');
  return models;
}
async function reset(models) {
  // Every collection starts empty in this network-none, disposable MongoDB.
  for (const model of Object.values(models)) await model.deleteMany({});
  const users = {};
  for (const [i, key] of 'ABCDEFGHIU'.split('').entries()) {
    users[key] = await models.User.create({ _id: `7ed${String(i + 1).padStart(21, '0')}`, phone: `+15558880${String(i + 1).padStart(3, '0')}`, name: `Synthetic Media ${key}`, role: 'consultant', institution: 'Media fixture only', isVerified: true, isOnboarded: key !== 'U', isActive: key !== 'I', fcmTokens: [] });
  }
  await models.Space.create([
    { _id: ids.space, name: 'Media AB', type: 'department', inviteCode: 'MEDABA', createdBy: users.A._id, members: [{ userId: users.A._id, role: 'owner' }, { userId: users.B._id, role: 'member' }] },
    { _id: ids.otherSpace, name: 'Media C', type: 'department', inviteCode: 'MEDCCA', createdBy: users.C._id, members: [{ userId: users.C._id, role: 'owner' }] },
  ]);
  await models.Channel.create([
    { _id: ids.channel, name: 'media-ab', spaceId: ids.space, createdBy: users.A._id },
    { _id: ids.otherChannel, name: 'media-c', spaceId: ids.otherSpace, createdBy: users.C._id },
    { _id: ids.dmOther, type: 'direct', spaceId: null, name: null, members: [users.D._id, users.E._id], createdBy: users.D._id },
  ]);
  await models.Handoff.create({ _id: ids.handoff, spaceId: ids.space, channelId: ids.channel, fromUserId: users.A._id, toUserId: users.B._id, shiftDate: '2025-01-15', shiftType: 'morning', status: 'draft', patients: [{ bedNumber: 'CI', clinicalAlias: 'Synthetic' }] });
  assert.equal(await models.User.countDocuments(), 10); assert.equal(await models.Channel.countDocuments(), 3);
  return users;
}
async function snapshot(models) {
  const state = {};
  for (const [name, model] of Object.entries(models)) {
    const docs = await model.find().sort({ _id: 1 }).lean();
    state[name] = name === 'User' ? docs.map(({ lastSeenAt, updatedAt, ...rest }) => rest) : docs;
  }
  return JSON.stringify(state);
}
async function settled(models) {
  const wait = ms => new Promise(r => setTimeout(r, ms)); await wait(100);
  let previous = await snapshot(models), quiet = 0;
  for (let i = 0; i < 25; i++) { await wait(25); const next = await snapshot(models); quiet = previous === next ? quiet + 1 : 0; if (quiet >= 2) return next; previous = next; }
  throw new Error('Media fixture state did not settle');
}
module.exports = { ids, load, reset, snapshot, settled };
