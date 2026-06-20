/**
 * Space room management over socket.
 * Clients call sync_space_rooms after create/join or on reconnect.
 */

const { SOCKET_EVENTS } = require('../../constants');
const { syncSocketSpaceRooms } = require('../spaceRooms');
const {
  broadcastPresenceUpdate,
  emitPresenceSnapshotForSocket,
} = require('./presence.handler');
const logger = require('../../utils/logger');

const registerSpaceHandlers = (io, socket) => {
  socket.on(SOCKET_EVENTS.SYNC_SPACE_ROOMS, async () => {
    try {
      const spaceCount = await syncSocketSpaceRooms(socket);
      await emitPresenceSnapshotForSocket(socket);
      broadcastPresenceUpdate(io, socket, { isOnline: true });
      socket.emit(SOCKET_EVENTS.SYNC_SPACE_ROOMS, {
        success: true,
        spaceCount,
      });
    } catch (err) {
      logger.error(`sync_space_rooms failed: ${err.message}`);
      socket.emit(SOCKET_EVENTS.ERROR, {
        message: 'Could not sync space rooms',
      });
    }
  });
};

module.exports = { registerSpaceHandlers };
