import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../../..');
const app = resolve(root, 'medcollab-app');
const expectedSdk = '3.29.3';
const cases = {
  'FR-MED-08': 'media_test.dart',
  'FR-PUSH-05': 'notifications_test.dart',
  'FR-PUSH-06': 'notifications_test.dart',
  'FR-NAV-04': 'lifecycle_test.dart',
  'FR-NAV-05': 'lifecycle_test.dart',
  'FR-LINK-04': 'invites_test.dart',
  'FR-JRN-05': 'journeys_test.dart',
  'FR-JRN-06': 'journeys_test.dart',
};
const reasons = [];
const isolatedOverlay = process.argv.includes('--isolated-overlay');
const result = {
  kind: 'device-preflight',
  ready: false,
  requiredBuildMode: 'debug',
  cases: Object.keys(cases),
  sdk: null,
  emulator: null,
  dependencyMode: isolatedOverlay ? 'committed-archive-test-overlay' : 'working-app',
  reasons,
};

function run(command, args, cwd = root) {
  const batch = process.platform === 'win32' && command.toLowerCase().endsWith('.bat');
  const child = spawnSync(batch ? 'cmd.exe' : command, batch
    ? ['/d', '/c', 'call', command, ...args]
    : args, {
    cwd,
    encoding: 'utf8',
    timeout: 15000,
    windowsHide: true,
    shell: false,
  });
  return child.status === 0 ? child.stdout.trim() : null;
}

const apiArg = process.argv.find((arg) => arg.startsWith('--api-url='));
if (!apiArg) {
  reasons.push('Provide --api-url=http://10.0.2.2:<local-port> for a disposable synthetic backend.');
} else {
  try {
    const url = new URL(apiArg.slice('--api-url='.length));
    if (
      url.protocol !== 'http:' ||
      url.hostname !== '10.0.2.2' ||
      !url.port ||
      url.pathname !== '/' ||
      url.search ||
      url.hash ||
      url.username ||
      url.password
    ) {
      throw new Error('unsafe API origin');
    }
    result.apiOrigin = url.origin;
  } catch {
    reasons.push('API origin must be plain HTTP on Android emulator host 10.0.2.2 with an explicit local port.');
  }
}

const pubspec = readFileSync(resolve(app, 'pubspec.yaml'), 'utf8');
if (!isolatedOverlay && !/^\s{2}integration_test:\s*$/m.test(pubspec)) {
  reasons.push('App pubspec.yaml has no integration_test SDK dependency.');
}
const dirtyLock = run('git', ['status', '--porcelain', '--', 'medcollab-app/pubspec.lock']);
if (dirtyLock === null) {
  reasons.push('Could not verify the committed Flutter lockfile.');
} else if (dirtyLock && !isolatedOverlay) {
  reasons.push('App pubspec.lock has uncommitted work; preserve it and use an isolated checkout.');
}
result.userLockfileDirty = Boolean(dirtyLock);
result.userWorkingFilesExcluded = isolatedOverlay;

const flutterArg = process.argv.find((arg) => arg.startsWith('--flutter-bin='));
const flutterBin = flutterArg ? flutterArg.slice('--flutter-bin='.length) : process.platform === 'win32'
  ? resolve('C:/flutter/bin/flutter.bat')
  : 'flutter';
const sdkText = run(flutterBin, ['--version', '--machine'], app);
if (sdkText) {
  try {
    result.sdk = JSON.parse(sdkText).frameworkVersion ?? null;
  } catch {
    reasons.push('Flutter SDK version output could not be parsed.');
  }
} else {
  reasons.push('Flutter SDK is unavailable.');
}
if (result.sdk && result.sdk !== expectedSdk) {
  reasons.push(`Flutter SDK ${result.sdk} differs from the lockfile-validated ${expectedSdk}.`);
}

const adbBin = process.platform === 'win32'
  ? resolve(process.env.USERPROFILE ?? 'C:/Users/Default', 'AppData/Local/Android/Sdk/platform-tools/adb.exe')
  : 'adb';
const adbText = run(adbBin, ['devices', '-l']);
if (adbText === null) {
  reasons.push('ADB is unavailable.');
} else {
  const attached = adbText.split(/\r?\n/).filter((line) => /^\S+\s+device\b/.test(line));
  const online = attached.filter((line) => /^emulator-\d+\s+device\b/.test(line));
  if (online.length !== 1 || attached.length !== 1) {
    reasons.push(`Expected exactly one online Android emulator and no physical device; found ${online.length} emulator(s) and ${attached.length - online.length} other device(s).`);
  } else {
    result.emulator = online[0].split(/\s+/)[0];
  }
}

const testDir = resolve(app, 'integration_test/functional_regression');
for (const [id, file] of Object.entries(cases)) {
  if (!existsSync(resolve(testDir, file))) {
    reasons.push(`${id} integration test file ${file} is missing.`);
  }
}

result.ready = reasons.length === 0;
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
process.exitCode = result.ready ? 0 : 2;
