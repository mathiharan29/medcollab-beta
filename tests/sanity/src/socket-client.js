import { io } from 'socket.io-client';

const origin = 'http://127.0.0.1:5000';

function timeout(label, milliseconds = 10_000) {
  return new Promise((_, reject) => setTimeout(() => reject(new Error(`Timed out waiting for ${label}.`)), milliseconds));
}

export async function connectRealtime(token) {
  if ((process.env.SANITY_ORIGIN || origin) !== origin) throw new Error('Rejected non-local socket origin.');
  const socket = io(origin, { auth: { token }, transports: ['websocket'], timeout: 10_000 });
  const authenticated = await Promise.race([
    new Promise((resolve, reject) => {
      socket.once('authenticated', resolve);
      socket.once('connect_error', reject);
    }),
    timeout('socket authentication'),
  ]);
  return { socket, authenticated, waitFor: (event, predicate = () => true) => waitFor(socket, event, predicate) };
}

export function waitFor(socket, event, predicate = () => true, milliseconds = 10_000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off(event, listener);
      reject(new Error(`Timed out waiting for socket event ${event}.`));
    }, milliseconds);
    const listener = (payload) => {
      if (!predicate(payload)) return;
      clearTimeout(timer);
      socket.off(event, listener);
      resolve(payload);
    };
    socket.on(event, listener);
  });
}

export async function joinChannel(client, channelId) {
  const joined = client.waitFor('join_channel', (payload) => payload?.success === true && payload.channelId === channelId);
  client.socket.emit('join_channel', { channelId });
  await joined;
}

export function closeRealtime(client) {
  client?.socket?.disconnect();
}
