import { createRequire } from 'node:module';
import { join } from 'node:path';
import { backendRoot as configuredBackendRoot, repoRoot } from './config.mjs';
import { backendRequire } from './db.mjs';

const sanityRequire = createRequire(join(repoRoot, 'tests/sanity/package.json'));

export async function connectSocket(backendRoot, origin, token, timeoutMs = 10000) {
  // Prefer the disposable backend install (device lane) so a Docker Linux
  // npm ci into tests/sanity cannot break Windows host socket.io-client.
  // Suites often pass null; fall back to the configured target backendRoot.
  const roots = [backendRoot, configuredBackendRoot].filter(Boolean);
  let io;
  for (const root of roots) {
    try {
      ({ io } = backendRequire(root)('socket.io-client'));
      if (io) break;
    } catch {
      /* try next */
    }
  }
  if (!io) ({ io } = sanityRequire('socket.io-client'));
  const socket = io(origin, { auth: { token }, transports: ['websocket'], timeout: timeoutMs, autoConnect: false });
  const authenticated = waitFor(socket, 'authenticated', () => true, timeoutMs);
  socket.connect();
  try { await authenticated; return socket; } catch (error) { socket.disconnect(); throw error; }
}

export function waitFor(socket, event, predicate = () => true, timeoutMs = 10000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { socket.off(event, listener); reject(new Error(`Socket event ${event} timed out`)); }, timeoutMs);
    const listener = (payload) => { if (!predicate(payload)) return; clearTimeout(timer); socket.off(event, listener); resolve(payload); };
    socket.on(event, listener);
  });
}
