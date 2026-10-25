/**
 * Helpers for space-level socket rooms (`space:<spaceId>`).
 * Presence and space broadcasts target these rooms.
 */

const Space = require('../features/spaces/space.model');
const logger = require('../utils/logger');

let io;

const initSpaceRooms = (socketServer) => {
  io = socketServer;
};

/**
 * Add all active sockets for [userId] to a space room.
 * Called after REST create/join so presence works without reconnect.
 */
const joinUserToSpaceRoom = (userId, spaceId) => {
  if (!io) return;

  const uid = userId.toString();
  const sid = spaceId.toString();
  const room = `space:${sid}`;
  let joined = 0;

  io.sockets.sockets.forEach((socket) => {
    if (socket.userId?.toString() !== uid) return;

    socket.join(room);
    if (!socket.spaceIds) socket.spaceIds = [];
    if (!socket.spaceIds.includes(sid)) {
      socket.spaceIds.push(sid);
    }
    socket.data.spaceIds = socket.spaceIds;
    joined += 1;
  });

  if (joined > 0) {
    logger.socket(`User ${uid} joined space room ${room} (${joined} socket(s))`);
  }
};

/**
 * Remove all active sockets for [userId] from a space room (leave / kick).
 * Re-syncs rooms from MongoDB membership so eviction is authoritative before
 * REST returns (FR-JRN-04 / FR-SPC-06 presence leak).
 */
const leaveUserFromSpaceRoom = async (userId, spaceId) => {
  if (!io) return;

  const uid = userId.toString();
  const sid = spaceId.toString();
  const room = `space:${sid}`;

  const sockets = [...io.sockets.sockets.values()].filter((socket) => {
    const socketUid = (socket.userId || socket.data?.userId || '').toString();
    return socketUid === uid;
  });

  await Promise.all(
    sockets.map(async (socket) => {
      await socket.leave(room);
      // Authoritative: drop any stale space rooms that no longer match DB membership.
      await syncSocketSpaceRooms(socket);
    })
  );

  if (sockets.length > 0) {
    logger.socket(`User ${uid} left space room ${room} (${sockets.length} socket(s))`);
  }
};

/**
 * Re-sync all space rooms for a connected socket from MongoDB membership.
 * Leaves rooms the user no longer belongs to (leave / removal / reconnect).
 */
const syncSocketSpaceRooms = async (socket) => {
  const spaces = await Space.find(
    { 'members.userId': socket.userId, isActive: true },
    { _id: 1 },
  ).lean();

  const spaceIds = spaces.map((s) => s._id.toString());
  const next = new Set(spaceIds);
  const previous = Array.isArray(socket.spaceIds)
    ? socket.spaceIds.map(String)
    : [];

  for (const sid of previous) {
    if (!next.has(sid)) {
      await socket.leave(`space:${sid}`);
    }
  }

  // Also drop any space:* rooms that drifted off socket.spaceIds.
  for (const room of [...socket.rooms]) {
    if (!room.startsWith('space:')) continue;
    const sid = room.slice('space:'.length);
    if (!next.has(sid)) {
      await socket.leave(room);
    }
  }

  socket.spaceIds = spaceIds;
  socket.data.spaceIds = spaceIds;

  await Promise.all(
    spaceIds.map((spaceId) => socket.join(`space:${spaceId}`))
  );

  logger.socket(
    `${socket.userName} synced ${spaceIds.length} space room(s)`,
  );

  return spaceIds.length;
};

module.exports = {
  initSpaceRooms,
  joinUserToSpaceRoom,
  leaveUserFromSpaceRoom,
  syncSocketSpaceRooms,
};
