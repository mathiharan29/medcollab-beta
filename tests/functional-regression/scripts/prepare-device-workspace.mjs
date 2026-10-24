import { spawnSync } from 'node:child_process';
import { createHash, randomUUID } from 'node:crypto';
import { cp, mkdir, mkdtemp, readFile, readdir, writeFile, rm } from 'node:fs/promises';
import { resolve, join, sep } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { captureContext, executionIdentity } from '../../developer-workflow/context.mjs';
import { devicePackage } from './device-contracts.mjs';

async function stripDesktopPlatforms(app) {
  // Flutter plugin registration creates Windows/Linux ephemeral symlinks. On
  // hosts without Developer Mode that fails pub get even for Android-only runs.
  for (const platform of ['windows', 'linux', 'macos']) {
    await rm(join(app, platform), { recursive: true, force: true, maxRetries: 3, retryDelay: 250 });
  }
}

const root = resolve(import.meta.dirname, '../../..');
export const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
export function command(bin, args, cwd, timeout = 30000) {
  const batch = process.platform === 'win32' && /\.(bat|cmd)$/i.test(bin);
  // Paths and arguments are passed as discrete values. No user shell fragments.
  if (batch && [bin, ...args].some((arg) => /[&|<>^%\r\n"]/.test(arg))) throw new Error('Unsafe batch argument');
  const result = spawnSync(batch ? 'cmd.exe' : bin,
    batch ? ['/d', '/s', '/c', `""${bin}" ${args.map((arg) => `"${arg}"`).join(' ')}"`] : args,
    { cwd, encoding: 'utf8', timeout, windowsHide: true, windowsVerbatimArguments: batch, shell: false });
  if (result.status !== 0) throw new Error(`${bin} failed (${result.status}): ${(result.stderr || result.error?.message || result.stdout || '').slice(-2500)}`);
  return result.stdout.trim();
}

export async function prepareDeviceWorkspace(sha = command('git', ['rev-parse', 'HEAD'], root), output) {
  if (!/^[a-f0-9]{40}$/.test(sha)) throw new Error('A complete source SHA is required');
  const runRoot = output ? resolve(output) : resolve(root, 'tests/functional-regression/output', `d-${randomUUID().slice(0, 8)}`);
  // Keep transient Flutter projects outside the IDE's watched repository tree.
  // This limits path length and avoids repository project discovery. Cleanup
  // still verifies deletion; retaining a target is never a PASS.
  await mkdir(resolve(runRoot, '..'), { recursive: true });
  await mkdir(runRoot, { recursive: false });
  if (!process.env.JAVA_HOME) throw new Error('Selected Android JDK requires JAVA_HOME');
  const target = await mkdtemp(join(tmpdir(), 'vocle-device-'));
  if (!resolve(target).startsWith(`${resolve(tmpdir())}${sep}vocle-device-`)) throw new Error('Unsafe isolated temporary target');
  try {
  const archive = join(runRoot, 'source.tar');
  command('git', ['archive', '--format=tar', `--output=${archive}`, sha], root);
  command('tar', ['-xf', archive, '-C', target], root);
  const app = join(target, 'medcollab-app');
  await stripDesktopPlatforms(app);
  const tests = 'medcollab-app/integration_test/functional_regression';
  await cp(join(root, tests), join(target, tests), { recursive: true });
  await mkdir(join(app, 'test_driver'), { recursive: true });
  const driver = 'medcollab-app/test_driver/functional_regression_driver.dart';
  await cp(join(root, driver), join(target, driver));
  const harnessHashes = {};
  harnessHashes[driver] = hash(await readFile(join(root, driver)));
  async function recordHarness(directory, relative = tests) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      const file = `${relative}/${entry.name}`;
      if (entry.isDirectory()) await recordHarness(join(directory, entry.name), file);
      else harnessHashes[file] = hash(await readFile(join(directory, entry.name)));
    }
  }
  await recordHarness(join(root, tests));
  for (const file of [
    'tests/functional-regression/scripts/device-contracts.mjs',
    'tests/functional-regression/scripts/device-server.mjs',
    'tests/functional-regression/scripts/run-device.mjs',
    'tests/functional-regression/scripts/prepare-device-workspace.mjs',
    'tests/functional-regression/providers/preload.cjs',
    'tests/functional-regression/src/config.mjs',
    'tests/functional-regression/src/runner.mjs',
    'tests/functional-regression/src/db.mjs',
    'tests/functional-regression/src/http.mjs',
    'tests/functional-regression/src/socket.mjs',
    'tests/functional-regression/src/fixtures.mjs',
  ]) harnessHashes[file] = hash(await readFile(join(root, file)));
  const pubspecPath = join(app, 'pubspec.yaml');
  const originalPubspec = await readFile(pubspecPath, 'utf8');
  if (!originalPubspec.includes('dev_dependencies:\n') && !originalPubspec.includes('dev_dependencies:\r\n')) throw new Error('Unexpected app pubspec');
  const overlay = originalPubspec.replace(/dev_dependencies:\r?\n/, 'dev_dependencies:\n  integration_test:\n    sdk: flutter\n  firebase_core_platform_interface: any\n  firebase_messaging_platform_interface: any\n  image_picker_platform_interface: any\n  camera_platform_interface: any\n');
  await writeFile(pubspecPath, overlay);
  const buildPath = join(app, 'android/app/build.gradle.kts');
  const originalBuild = await readFile(buildPath, 'utf8');
  if (!originalBuild.includes('applicationId = "com.example.medcollab_app"')) throw new Error('Unrecognized Android test package');
  await writeFile(buildPath, originalBuild.replace('applicationId = "com.example.medcollab_app"', `applicationId = "${devicePackage}"`));
  // Local synthetic HTTP only, in the test build's debug manifest.
  await writeFile(join(app, 'android/app/src/debug/AndroidManifest.xml'),
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android"><uses-permission android:name="android.permission.INTERNET"/><application android:usesCleartextTraffic="true" /></manifest>\n');
  const propertiesPath = join(app, 'android/gradle.properties');
  let properties = await readFile(propertiesPath, 'utf8');
  properties = properties.replace(/^org\.gradle\.java\.home=.*\r?\n?/gm, '')
    .replace(/-Djavax\.net\.ssl\.trustStore(?:Password|Type)?=\S+/g, '');
  properties += '\norg.gradle.java.home=' + resolve(process.env.JAVA_HOME).replaceAll('\\', '/') + '\n';
  if (process.env.VOCLE_ANDROID_TRUSTSTORE) {
    properties = properties.replace(/^(org\.gradle\.jvmargs=.*)$/m, '$1 -Djavax.net.ssl.trustStore=gradle-truststore.jks -Djavax.net.ssl.trustStorePassword=changeit');
    await cp(resolve(process.env.VOCLE_ANDROID_TRUSTSTORE), join(app, 'android/gradle-truststore.jks'));
  }
  await writeFile(propertiesPath, properties);
  const tracked = command('git', ['ls-tree', '-r', '--name-only', sha, 'medcollab-app/lib', 'medcollab-backend/src', 'medcollab-backend/package-lock.json'], root).split(/\r?\n/);
  const sourceHashes = {};
  for (const file of tracked) sourceHashes[file] = hash(await readFile(join(target, file)));
  const provenance = { context: captureContext(root), execution: executionIdentity(), executionMode: 'LOCAL_ONLY', sourceSha: sha, harnessSha: command('git', ['rev-parse', 'HEAD'], root),
    sourceKind: 'committed-fork-archive', sourceHashes, harnessHashes, temporaryTarget: target,
    originalPubspecHash: hash(originalPubspec), originalAppLockHash: hash(await readFile(join(app, 'pubspec.lock'))),
    isolatedTestOverlays: ['integration_test SDK and existing plugin interface dev dependencies (original versions verified unchanged)', `Android applicationId ${devicePackage}`, 'debug cleartext HTTP permission', ...(process.env.VOCLE_ANDROID_TRUSTSTORE ? ['JDK trusted CA store for committed Gradle SSL arguments'] : [])],
    userWorkingTreeCopied: false, releaseBuildAllowed: false };
  await writeFile(join(runRoot, 'provenance.json'), `${JSON.stringify(provenance, null, 2)}\n`);
  return { runRoot, target, app, provenance };
  } catch (error) {
    if (!resolve(target).startsWith(`${resolve(tmpdir())}${sep}vocle-device-`)) throw new Error('Unsafe device preparation cleanup path');
    await rm(target, { recursive: true, force: true, maxRetries: 3, retryDelay: 250 });
    throw error;
  }
}

export async function verifyDeviceSource(workspace) {
  for (const [file, expected] of Object.entries(workspace.provenance.sourceHashes)) {
    if (hash(await readFile(join(workspace.target, file))) !== expected) throw new Error(`Application source changed: ${file}`);
  }
  return { status: 'PASS', sourceSha: workspace.provenance.sourceSha, checkedFiles: Object.keys(workspace.provenance.sourceHashes).length };
}

export function verifyDeviceCleanupPath(workspace) {
  if (!resolve(workspace.target).startsWith(`${resolve(tmpdir())}${sep}vocle-device-`) ||
      workspace.target !== workspace.provenance.temporaryTarget) throw new Error('Unsafe device cleanup path');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const workspace = await prepareDeviceWorkspace(process.argv[2]);
  console.log(JSON.stringify({ runRoot: workspace.runRoot, target: workspace.target, app: workspace.app, provenance: await verifyDeviceSource(workspace) }, null, 2));
}
