import assert from 'node:assert/strict';
import { createServer, request as httpRequest } from 'node:http';
import { join } from 'node:path';
import { readFile, mkdir, writeFile, rm } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { deflateSync } from 'node:zlib';
import { backendRoot, outputRoot, runId } from '../src/config.mjs';
import { startMongo, databaseUri, inspectDatabase } from '../src/db.mjs';
import { startBackend, stopChild } from '../src/runner.mjs';
import { createHttp } from '../src/http.mjs';
import { capturedOtp } from '../src/fixtures.mjs';
import { connectSocket } from '../src/socket.mjs';
import { deviceCases, devicePackage, emulatorSerial, resumedActivityState as resumed, activityLifecycleStates } from './device-contracts.mjs';

const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function observe(read, accept, reason, timeout = 15000) {
  const end = Date.now() + timeout;
  do {
    const value = await read();
    if (accept(value)) return value;
    await pause(100); // Bounded read observation, never a mutation retry.
  } while (Date.now() < end);
  throw new Error(`Timed out observing ${reason}`);
}
async function listen(server) {
  await new Promise((resolve, reject) => server.once('error', reject).listen(0, '127.0.0.1', resolve));
  return server.address().port;
}
const redact = (value) => String(value).replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[redacted-jwt]');

// Complete synthetic PDF with valid byte offsets, for native reader checks.
function syntheticPdf() {
  const stream = 'BT /F1 18 Tf 30 120 Td (Synthetic Vocle document) Tj ET';
  const objects = ['<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    `<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}\nendstream`];
  let text = '%PDF-1.4\n'; const offsets = [0];
  for (const [index, object] of objects.entries()) { offsets.push(Buffer.byteLength(text)); text += `${index + 1} 0 obj\n${object}\nendobj\n`; }
  const xref = Buffer.byteLength(text);
  text += `xref\n0 6\n0000000000 65535 f \n${offsets.slice(1).map((offset) => `${String(offset).padStart(10, '0')} 00000 n \n`).join('')}trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(text);
}

function syntheticPng() {
  const chunk = (tag, bytes) => {
    const data = Buffer.concat([Buffer.from(tag), bytes]);
    let crc = 0xffffffff;
    for (const byte of data) {
      crc ^= byte;
      for (let bit = 0; bit < 8; bit++) crc = crc >>> 1 ^ (crc & 1 ? 0xedb88320 : 0);
    }
    const output = Buffer.alloc(bytes.length + 12);
    output.writeUInt32BE(bytes.length); data.copy(output, 4);
    output.writeUInt32BE((crc ^ 0xffffffff) >>> 0, bytes.length + 8);
    return output;
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(1, 0); header.writeUInt32BE(1, 4);
  header[8] = 8; header[9] = 6; // One RGBA pixel, no interlace.
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', header), chunk('IDAT', deflateSync(Buffer.from([0, 0, 112, 255, 255]))), chunk('IEND', Buffer.alloc(0))]);
}

export async function startDeviceServer({ adb, serial, caseId }) {
  emulatorSerial(serial);
  const runtime = join(outputRoot, 'runtime', `device-${caseId.toLowerCase()}-${runId}`);
  const inbox = join(runtime, 'inbox');
  await mkdir(inbox, { recursive: true });
  const controlRecords = [], checkpoints = [], results = [], requests = [];
  let mongo, backend, gateway, controlServer, senderSocket;
  let outage = false, logoutFailure = false, logoutFaults = 0;
  let ackListening = false; const ackEvents = [];
  const sockets = new Set();
  const native = async (...args) => {
    const result = await promisify(execFile)(adb, ['-s', serial, ...args],
      { cwd: runtime, encoding: 'utf8', timeout: 15000, maxBuffer: 4 * 1024 * 1024, windowsHide: true });
    return result.stdout.trim();
  };
  const foreground = () => native('shell', 'dumpsys', 'activity', 'activities');
  const activity = `${devicePackage}/com.example.medcollab_app.MainActivity`;
  let uri, fixture;
  let cleaned = false;
  const db = (action) => inspectDatabase(backendRoot, uri, action);
  const close = async () => {
    if (cleaned) return { status: 'PASS' };
    cleaned = true;
    senderSocket?.disconnect();
    for (const socket of sockets) socket.destroy();
    await Promise.all([gateway, controlServer].filter(Boolean).map((server) => new Promise((resolve) => server.close(resolve))));
    await stopChild(backend?.child);
    if (backend) await writeFile(join(outputRoot, `backend-device-${caseId}.log`), redact(backend.logs()));
    await mongo?.server.stop();
    await rm(runtime, { recursive: true, force: true });
    return { status: 'PASS', backendStopped: true, mongoStopped: true, controlServerStopped: true, runtimeRemoved: true };
  };
  try {
    mongo = await startMongo(backendRoot, join(outputRoot, 'mongo-binaries'));
    uri = databaseUri(mongo.uri, `device_${caseId.toLowerCase().replaceAll('-', '_')}`, runId);
    const reserved = createServer();
    const backendPort = await listen(reserved);
    await new Promise((resolve) => reserved.close(resolve));
    gateway = createServer((req, res) => {
      const pathname = new URL(req.url, 'http://127.0.0.1').pathname;
      requests.push({ method: req.method, pathname });
      if (outage || logoutFailure && pathname === '/api/auth/logout') {
        if (pathname === '/api/auth/logout') logoutFaults++;
        res.writeHead(503, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ success: false, message: 'Synthetic local transport outage' }));
        return;
      }
      const upstream = httpRequest({ hostname: '127.0.0.1', port: backendPort, method: req.method, path: req.url, headers: req.headers }, (response) => {
        res.writeHead(response.statusCode, response.headers); response.pipe(res);
      });
      upstream.on('error', () => { if (!res.headersSent) res.writeHead(502); res.end(); });
      req.pipe(upstream);
    });
    gateway.on('connection', (socket) => { sockets.add(socket); socket.once('close', () => sockets.delete(socket)); });
    // Socket.IO websocket upgrade forwards only to the disposable backend.
    gateway.on('upgrade', (req, socket, head) => {
      if (outage) return socket.destroy();
      const proxy = httpRequest({ hostname: '127.0.0.1', port: backendPort, path: req.url, headers: req.headers });
      proxy.on('upgrade', (response, upstreamSocket, upstreamHead) => {
        socket.write(`HTTP/1.1 ${response.statusCode} ${response.statusMessage}\r\n${Object.entries(response.headers).map(([key, value]) => `${key}: ${value}\r\n`).join('')}\r\n`);
        if (upstreamHead.length) socket.write(upstreamHead);
        if (head.length) upstreamSocket.write(head);
        sockets.add(upstreamSocket); upstreamSocket.once('close', () => sockets.delete(upstreamSocket));
        socket.pipe(upstreamSocket); upstreamSocket.pipe(socket);
        socket.once('close', () => upstreamSocket.destroy());
        upstreamSocket.once('error', () => socket.destroy());
      });
      proxy.on('error', () => socket.destroy()); proxy.end();
    });
    const apiPort = await listen(gateway);
    const apiOrigin = `http://10.0.2.2:${apiPort}`;
    backend = await startBackend(uri, backendPort, runtime, inbox, { extraEnv: { API_BASE_URL: apiOrigin } });
    const request = createHttp(`http://127.0.0.1:${backendPort}`);
    const people = {};
    for (const [index, label] of ['A', 'B', 'C'].entries()) {
      const phone = `+91999000100${index + 1}`;
      await request('/api/auth/request-otp', { method: 'POST', body: { phone } });
      const login = await request('/api/auth/verify-otp', { method: 'POST', body: { phone, otp: await capturedOtp(inbox, phone) } });
      const profile = await request('/api/users/me', { method: 'PUT', token: login.data.accessToken,
        body: { name: `Dr Synthetic Device ${label}`, institution: 'Vocle Synthetic Institute', speciality: 'Synthetic Medicine' } });
      assert.equal(profile.data.user.name, `Dr Synthetic Device ${label}`);
      people[label] = { phone, userId: profile.data.user._id, token: login.data.accessToken, refreshToken: login.data.refreshToken };
    }
    const created = await request('/api/spaces', { method: 'POST', token: people.A.token,
      body: { name: 'Synthetic Device Space', type: 'department' }, expectedStatus: 201 });
    const spaceId = created.data.space._id;
    await request('/api/spaces/join', { method: 'POST', token: people.B.token, body: { inviteCode: created.data.space.inviteCode } });
    const channelId = created.data.channels.find((item) => item.name === 'general')._id;
    const other = await request(`/api/spaces/${spaceId}/channels`, { method: 'POST', token: people.A.token,
      body: { name: 'synthetic-device-other' }, expectedStatus: 201 });
    const invites = [];
    if (caseId === 'FR-LINK-04') {
      for (let index = 0; index < 5; index++) {
        const made = await request('/api/spaces', { method: 'POST', token: people.A.token,
          body: { name: `Synthetic Device Invite ${index}`, type: 'department' }, expectedStatus: 201 });
        invites.push({ spaceId: made.data.space._id, code: made.data.space.inviteCode, name: made.data.space.name });
      }
      await db(async (connection) => connection.collection('spaces').updateOne({ _id: new connection.base.Types.ObjectId(invites[4].spaceId) },
        { $set: { 'settings.requireApproval': true } })); // Explicit approval prerequisite.
    }
    let handoffId;
    if (caseId === 'FR-JRN-06') {
      const made = await request('/api/handoffs', { method: 'POST', token: people.A.token,
        body: { spaceId, channelId, toUserId: people.B.userId, shiftDate: '2035-01-15T00:00:00.000Z', shiftType: 'night',
          shiftSummary: 'Synthetic device handoff', patients: [{ bedNumber: 'D-01', clinicalAlias: 'Synthetic device patient', pendingTasks: ['Synthetic follow-up'] }] }, expectedStatus: 201 });
      handoffId = made.data.handoff._id;
      await request(`/api/handoffs/${handoffId}/submit`, { method: 'POST', token: people.A.token });
      senderSocket = await connectSocket(null, `http://127.0.0.1:${backendPort}`, people.A.token);
      senderSocket.on('handoff_acknowledged', (payload) => { if (ackListening && payload?.handoffId === handoffId) ackEvents.push(payload.handoffId); });
    }
    fixture = { ...people, spaceId, channelId, otherChannelId: other.data.channel._id,
      invites: invites.slice(0, 4), pendingInvite: invites[4], handoffId };
    const oid = (connection, value) => new connection.base.Types.ObjectId(value);
    const membership = async (space, label) => db(async (connection) => {
      assert.ok(Object.values(fixture.invites).some((row) => row.spaceId === space) || fixture.pendingInvite?.spaceId === space);
      assert.ok(people[label]);
      const row = await connection.collection('spaces').findOne({ _id: oid(connection, space) });
      return { member: row.members.some((member) => String(member.userId) === people[label].userId),
        pendingCount: row.pendingRequests.filter((member) => String(member.userId) === people[label].userId).length };
    });
    const messages = (channel) => db(async (connection) => {
      assert.ok([channelId, fixture.otherChannelId].includes(channel));
      return connection.collection('messages').find({ channelId: oid(connection, channel) }).toArray();
    });
    const tokenState = (label, token) => db(async (connection) => {
      assert.ok(people[label]); assert.match(token, /^synthetic-device-/);
      const person = await connection.collection('users').findOne({ _id: oid(connection, people[label].userId) });
      return { present: person.fcmTokens.includes(token) };
    });
    const handoffState = () => db(async (connection) => ({
      handoff: await connection.collection('handoffs').findOne({ _id: oid(connection, handoffId) }),
      acknowledgeRequests: requests.filter((row) => row.method === 'POST' && row.pathname === `/api/handoffs/${handoffId}/acknowledge`).length,
      senderNotificationCount: await connection.collection('notifications').countDocuments({ userId: oid(connection, people.A.userId), referenceId: oid(connection, handoffId), type: 'handoff_acknowledged' }),
      senderEventHandoffIds: ackEvents,
    }));
    controlServer = createServer(async (req, res) => {
      res.setHeader('content-type', 'application/json');
      if (req.method !== 'POST' || req.headers['x-vocle-run'] !== runId) { res.writeHead(403); res.end('{}'); return; }
      try {
        const chunks = []; let size = 0;
        for await (const chunk of req) { size += chunk.length; if (size > 1024 * 1024) throw new Error('Control payload too large'); chunks.push(chunk); }
        const input = JSON.parse(Buffer.concat(chunks).toString() || '{}');
        const action = req.url.replace('/control/', '');
        let answer;
        switch (action) {
          case 'fixture': answer = fixture; break;
          case 'otp': assert.ok(people[input.label]); answer = { otp: await capturedOtp(inbox, people[input.label].phone) }; break;
          case 'result':
            assert.equal(input.id, caseId); assert.equal(input.runId, runId);
            assert.equal(input.phase, deviceCases[caseId].phases.at(-1));
            assert.equal(input.executed, true);
            assert.ok(['PASS', 'FAIL', 'ERROR', 'NEEDS_DECISION'].includes(input.status));
            input.error = input.error ? redact(input.error) : undefined;
            results.push(input); answer = { saved: true }; break;
          case 'checkpoint': assert.equal(input.runId, runId); checkpoints.push(input); answer = { saved: true }; break;
          case 'checkpoints': answer = { checkpoints }; break;
          case 'messages': answer = { messages: await messages(input.channelId) }; break;
          case 'await-message': {
            const rows = await observe(() => messages(input.channelId), (rows) => rows.some((row) => row.content.text === input.text), 'committed draft');
            const matching = rows.filter((row) => row.content.text === input.text); assert.equal(matching.length, 1);
            answer = { messageId: String(matching[0]._id) }; break;
          }
          case 'peer-message': {
            assert.ok([channelId, fixture.otherChannelId].includes(input.channelId));
            const reply = await request(`/api/channels/${input.channelId}/messages`, { method: 'POST', token: people.B.token,
              body: { content: { text: input.text } }, expectedStatus: 201 });
            answer = { messageId: reply.data.message._id }; break;
          }
          case 'outage': outage = input.enabled === true; if (outage) for (const socket of sockets) socket.destroy(); answer = { enabled: outage }; break;
          case 'logout-failure': logoutFailure = input.enabled === true; answer = { enabled: logoutFailure, injectedRequests: logoutFaults }; break;
          case 'background-resume': {
            await native('shell', 'input', 'keyevent', 'KEYCODE_HOME');
            await observe(foreground, (text) => resumed(text).length > 0 && !resumed(text).includes(devicePackage), 'native background');
            await observe(foreground, (text) => activityLifecycleStates(text, devicePackage).includes('STOPPED'), 'test activity onStop completion');
            if (input.recoverTransport === true) outage = false;
            await native('shell', 'am', 'start', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', '-f', '0x20000000', '-n', activity);
            await observe(foreground, (text) => resumed(text).includes(devicePackage), 'native foreground');
            answer = { backgroundObserved: true, stoppedObserved: true, foregroundObserved: true, transportOutageInjection: 'local HTTP/Socket.IO gateway' }; break;
          }
          case 'camera-permission': case 'notification-permission': {
            const permission = action === 'camera-permission' ? 'android.permission.CAMERA' : 'android.permission.POST_NOTIFICATIONS';
            await native('shell', 'pm', 'clear-permission-flags', devicePackage, permission, 'user-fixed');
            await native('shell', 'pm', input.granted ? 'grant' : 'revoke', devicePackage, permission);
            if (!input.granted) await native('shell', 'pm', 'set-permission-flags', devicePackage, permission, 'user-fixed');
            const state = await native('shell', 'dumpsys', 'package', devicePackage);
            assert.ok(state.includes(`${permission}: granted=${Boolean(input.granted)}`), 'Native permission transition did not take effect');
            answer = { granted: Boolean(input.granted) }; break;
          }
          case 'camera-permission-state': answer = { granted: (await native('shell', 'dumpsys', 'package', devicePackage)).includes('android.permission.CAMERA: granted=true') }; break;
          case 'token-state': answer = await tokenState(input.label, input.token); break;
          case 'await-token': answer = await observe(() => tokenState(input.label, input.token), (row) => row.present, 'token registration'); break;
          case 'membership': answer = await membership(input.spaceId, input.label); break;
          case 'await-pending': answer = await observe(() => membership(input.spaceId, input.label), (row) => row.pendingCount > 0, 'pending join'); break;
          case 'media-counts': answer = { uploadRequests: requests.filter((row) => row.method === 'POST' && row.pathname === '/api/media/upload').length, messageCount: (await messages(input.channelId)).length }; break;
          case 'media-fixtures': {
            // Android creates a valid MP4 of this run's synthetic test UI.
            // No file-extension-only stand-in for media compatibility.
            const mp4Path = join(runtime, 'synthetic.mp4');
            const deviceVideo = `/data/local/tmp/vocle_regression_${runId}.mp4`;
            await native('shell', 'screenrecord', '--time-limit', '1', deviceVideo);
            await native('pull', deviceVideo, mp4Path);
            await native('shell', 'rm', deviceVideo);
            answer = { pdf: syntheticPdf().toString('base64'),
              png: syntheticPng().toString('base64'),
              mp4: (await readFile(mp4Path)).toString('base64') }; break;
          }
          case 'observe-opener': {
            const detail = await observe(foreground, (text) => resumed(text).length > 0 &&
              !resumed(text).includes(devicePackage) && /content:\/\/com\.vocle\.regression/.test(text), 'external local document activity');
            await native('shell', 'am', 'start', '-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.LAUNCHER', '-f', '0x20000000', '-n', activity);
            answer = { externalActivityObserved: true, localUriObserved: true,
              activity: resumed(detail).trim() }; break;
          }
          case 'handoff-state': answer = await handoffState(); break;
          case 'listen-ack': ackListening = true; answer = { listening: true }; break;
          case 'await-ack': answer = await observe(handoffState, (row) => row.handoff.status === 'acknowledged' && row.senderNotificationCount > 0 && row.senderEventHandoffIds.length > 0, 'handoff sender convergence'); break;
          case 'sender-handoff': answer = (await request(`/api/handoffs/${handoffId}`, { token: people.A.token })).data; break;
          default: throw new Error('Unknown local control action');
        }
        // Never record fixture tokens, OTP values, or control authentication.
        controlRecords.push({ action, at: new Date().toISOString() });
        res.end(JSON.stringify(answer));
      } catch (error) {
        const action = req.url.replace('/control/', '');
        const applicationObservation = ['await-message', 'await-token', 'await-ack', 'await-pending'].includes(action) &&
          !/^Mongo/.test(error.name) || error.name === 'HttpContractError';
        res.end(JSON.stringify({ status: applicationObservation ? 'FAIL' : 'ERROR', error: redact(error.message) }));
      }
    });
    const controlPort = await listen(controlServer);
    return { apiOrigin, controlOrigin: `http://10.0.2.2:${controlPort}`, results, checkpoints, controlRecords, requests,
      close, runId, forceStop: () => native('shell', 'am', 'force-stop', devicePackage) };
  } catch (error) { error.deviceCleanup = await close(); throw error; }
}
