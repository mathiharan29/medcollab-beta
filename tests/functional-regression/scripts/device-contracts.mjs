import assert from 'node:assert/strict';

export const deviceCases = Object.freeze({
  'FR-MED-08': { file: 'media_test.dart', phases: ['media'] },
  'FR-PUSH-05': { file: 'notifications_test.dart', phases: ['notification-grouping'] },
  'FR-PUSH-06': { file: 'notifications_test.dart', phases: ['notification-token'] },
  'FR-NAV-04': { file: 'lifecycle_test.dart', phases: ['resume'] },
  'FR-NAV-05': { file: 'lifecycle_test.dart', phases: ['session-seed', 'session-restore', 'session-empty'] },
  'FR-LINK-04': { file: 'invites_test.dart', phases: ['invites'] },
  'FR-JRN-05': { file: 'journeys_test.dart', phases: ['chat-journey'] },
  'FR-JRN-06': { file: 'journeys_test.dart', phases: ['handoff-seed', 'handoff-cold'] },
});
export const devicePackage = 'com.vocle.regression';
export const deviceSdk = '3.29.3';

export function classifyDeviceDiagnostics(text) {
  const infrastructureFailure = /DeviceInfrastructureError|could not uniquely locate/.test(text);
  return {
    infrastructureFailure,
    assertionFailure: !infrastructureFailure &&
      /TestFailure|Expected:|Application framework exception|emit was called after an event handler completed|Bad state: Cannot emit new states after calling close|EXCEPTION CAUGHT BY (?:RENDERING|FLUTTER FRAMEWORK)/.test(text),
  };
}

export function resumedActivityState(text) {
  return text.split(/\r?\n/).filter((line) =>
    /\b(?:mResumedActivity|topResumedActivity|ResumedActivity)\s*[:=]/.test(line)).join(' ');
}

// A different top activity can be resumed before our Activity has finished
// onStop. Wait for its own state before returning it to the foreground.
export function activityLifecycleStates(text, packageName) {
  return text.split(/\bpackageName=/).slice(1).flatMap((block) => {
    if (block.split(/\s/, 1)[0] !== packageName) return [];
    const state = block.match(/\bstate=([A-Z_]+)\b/);
    return state ? [state[1]] : [];
  });
}

export function emulatorOrigin(raw) {
  const url = new URL(raw);
  assert.equal(url.protocol, 'http:');
  assert.equal(url.hostname, '10.0.2.2');
  assert.ok(url.port);
  assert.equal(url.pathname, '/');
  assert.equal(url.search + url.hash + url.username + url.password, '');
  return url.origin;
}

export function emulatorSerial(raw) {
  assert.match(raw, /^emulator-\d+$/);
  return raw;
}

export function selectedDeviceCases(raw) {
  const ids = raw ? raw.split(',') : Object.keys(deviceCases);
  assert.ok(ids.length > 0);
  assert.equal(new Set(ids).size, ids.length);
  for (const id of ids) assert.ok(deviceCases[id], `Unknown device ID ${id}`);
  return ids;
}

// Restart evidence belongs to one run and must span distinct Android processes.
export function validateRestart(checkpoints, phases, runId) {
  const rows = phases.map((phase) => checkpoints.find((row) => row.phase === phase));
  assert.ok(rows.every(Boolean), 'Missing native restart phase');
  assert.ok(rows.every((row) => row.runId === runId && row.status === 'PASS'));
  assert.equal(new Set(rows.map((row) => row.processId)).size, phases.length,
    'Relaunch must execute in distinct processes');
  return rows;
}
