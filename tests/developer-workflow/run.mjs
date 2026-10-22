import { captureContext, executionIdentity } from './context.mjs';
import { localComparison } from './local-history.mjs';
import { mkdtemp, mkdir, cp, readFile, writeFile, rm, readdir, lstat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve, dirname, sep } from 'node:path';
import { randomUUID } from 'node:crypto';
import { git, tracked, applicationFile, fingerprint, run, cleanEnvironment } from './process.mjs';
import { hash, writeEvidence, assertionExecuted, securityOutcome } from './evidence.mjs';
import { writeQA } from './qa.mjs';
import { generate as generateDetailedReport } from '../reporting/report.mjs';
import { providerEvidence } from './cloudinary-evidence.mjs';

const root = resolve(import.meta.dirname, '../..');
const args = process.argv.slice(2), options = {};
const flags = new Set(['android', 'security', 'ci-checks']);
const values = new Set(['source', 'commit', 'output', 'previous', 'flutter-bin', 'docker-bin', 'docker-proxy', 'gitleaks-bin', 'cloudinary-output', 'reproduction', 'apk', 'profile', 'repository', 'branch-ref', 'pr-number']);
for (let i = 0; i < args.length; i++) {
  const key = args[i].replace(/^--/, '');
  if (flags.has(key)) options[key] = true;
  else if (values.has(key) && args[i + 1] && !args[i + 1].startsWith('--')) options[key] = args[++i];
  else throw new Error('Unknown or incomplete argument: ' + args[i]);
}
if (!['full', 'tooling', 'backend-smoke', 'security'].includes(options.profile || 'full')) throw new Error('Profile must be full, tooling, backend-smoke or security');
if (options.profile === 'security') options.security = true;
const source = resolve(options.source || root);
const output = resolve(options.output || join(root, 'tests/developer-workflow/output', new Date().toISOString().replace(/[:.]/g, '-') + '-' + randomUUID().slice(0, 8)));
// Fresh outputs prevent stale reports or pass markers being reused.
await mkdir(dirname(output), { recursive: true });
await mkdir(output, { recursive: false });
await mkdir(join(output, 'diagnostics'));
const catalog = JSON.parse(await readFile(join(root, 'tests/functional-regression/catalog.json'))).cases;
const rows = [], commandLine = options.reproduction || 'node tests/developer-workflow/run.mjs ' + args.map(a => JSON.stringify(a)).join(' ');
let scratch, target, harness, sourceInfo, harnessInfo, sourcePaths, before, docker, integrity = 'PASS', environment = {};
const ownedContainers = [];
const dockerOption = options['docker-bin'] || 'docker';
const dockerBin = /[\\/]/.test(dockerOption) ? resolve(dockerOption) : dockerOption;
const dockerArguments = argv => options['docker-proxy']
  ? [join(root, 'scripts/vocle_bootstrap.py'), '--proxy', resolve(options['docker-proxy']), ...argv] : argv;
const cancellation = new AbortController();
const cancel = () => { console.error('Cancellation requested; cleaning up owned test resources.'); cancellation.abort(); };
for (const name of process.platform === 'win32' ? ['SIGINT', 'SIGTERM', 'SIGBREAK'] : ['SIGINT', 'SIGTERM']) process.on(name, cancel);
const env = { ...cleanEnvironment(), TZ: 'UTC', CI: 'true', FLUTTER_SUPPRESS_ANALYTICS: 'true', DART_SUPPRESS_ANALYTICS: 'true' };
async function execute(bin, argv, options = {}) {
  if (cancellation.signal.aborted) throw new Error('Run cancelled');
  const result = await run(bin, bin === dockerBin ? dockerArguments(argv) : argv, { ...options, signal: cancellation.signal });
  if (result.aborted) throw new Error('Run cancelled');
  return result;
}
const image = 'node:22.20.0-bookworm@sha256:915acd9e9b885ead0c620e27e37c81b74c226e0e1c8177f37a60217b6eabb0d7';
const add = (id, status, required, extra = {}) => rows.push({ id, status, required, executed: false, module: 'TOOLING', ...extra });
async function command(id, bin, argv, cwd, required = true, extra = {}) {
  console.log(`Running ${id}`);
  if (bin === dockerBin && argv[0] === 'run') {
    const name = 'vocle-dev-' + randomUUID();
    const user = typeof process.getuid === 'function' ? ['--user', `${process.getuid()}:${process.getgid()}`] : [];
    ownedContainers.push(name); argv = ['run', '--name', name, ...user, ...argv.slice(1)];
  }
  const log = join(output, 'diagnostics', id + '.log');
  const result = await execute(bin, argv, { cwd, env, timeout: 30 * 60 * 1000, log });
  add(id, result.error || result.timedOut ? 'ERROR' : result.code === 0 ? 'PASS' : extra.infrastructure || (extra.failureCodes && !extra.failureCodes.includes(result.code)) ? 'ERROR' : 'FAIL', required,
    { executed: !result.error, error: result.code === 0 ? undefined : (result.error || (result.timedOut ? 'Command deadline exceeded' : result.stderr.slice(-1500) || 'Nonzero exit ' + result.code)), artifacts: ['diagnostics/' + id + '.log'], ...extra });
  return result;
}
const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';
const flutterOption = options['flutter-bin'] || (process.platform === 'win32' ? 'flutter.bat' : 'flutter');
const flutter = /[\\/]/.test(flutterOption) ? resolve(flutterOption) : flutterOption;
async function overlay(directory, paths, destination) {
  for (const file of paths) {
    if (/(^|\/)\.env(?:\.|$)/.test(file) && !file.endsWith('.env.example')) throw new Error('Credential file cannot enter test workspace');
    const full = join(directory, file), dest = join(destination, file);
    try {
      if (!(await lstat(full)).isFile()) throw new Error('Symlink/non-regular input refused: ' + file);
      await mkdir(dirname(dest), { recursive: true }); await cp(full, dest);
    } catch (e) { if (e.code === 'ENOENT') await rm(dest, { force: true }); else throw e; }
  }
}
async function clone(directory, destination, sha) {
  const result = await execute('git', ['clone', '--no-hardlinks', '--no-checkout', '--', directory, destination], { env });
  if (result.code !== 0) throw new Error('Source clone failed: ' + result.stderr);
  git(destination, ['checkout', '--detach', sha]);
}
function unavailable(cases, reason, required) {
  for (const c of cases) add(c.id, 'BLOCKED', required, { ...c, exclusion: reason });
}
try {
  if (Number(process.versions.node.split('.')[0]) < 22) throw new Error('Node >=22 is required');
  const head = git(source, ['rev-parse', 'HEAD']);
  if (options.commit && !/^[a-f0-9]{40}$/.test(options.commit)) throw new Error('Provide a complete 40-character commit SHA');
  const sha = options.commit || head;
  git(source, ['cat-file', '-e', sha + '^{commit}']);
  scratch = await mkdtemp(join(tmpdir(), 'vocle-dev-'));
  target = join(scratch, 'target'); harness = join(scratch, 'harness');
  await clone(source, target, sha);
  const sourceTracked = tracked(source).filter(applicationFile);
  const untracked = git(source, ['ls-files', '--others', '--exclude-standard', '-z']).split('\0').filter(Boolean).filter(applicationFile).filter(f => !f.includes('/node_modules/'));
  if (!options.commit) await overlay(source, [...sourceTracked, ...untracked], target);
  sourcePaths = [...tracked(target).filter(applicationFile), ...(!options.commit ? untracked : [])];
  before = await fingerprint(target, sourcePaths);
  const dirtyStatus = git(source, ['status', '--porcelain', '--', 'medcollab-app', 'medcollab-backend']);
  sourceInfo = { sha, kind: options.commit || !dirtyStatus ? 'commit' : 'working-tree', dirtyStatus: options.commit ? '' : dirtyStatus, ...before, verified: true, snapshot: true };
  const harnessSha = git(root, ['rev-parse', 'HEAD']);
  await clone(root, harness, harnessSha);
  const harnessPaths = [...tracked(root), ...git(root, ['ls-files', '--others', '--exclude-standard', '-z']).split('\0').filter(Boolean)]
    .filter(f => f === '.gitleaks.toml' || /^(tests\/(functional-regression|sanity|developer-workflow|reporting)\/|medcollab-app\/(test|integration_test|test_driver)\/|medcollab-backend\/scripts\/security|\.github\/workflows\/|scripts\/(Test-Vocle|test_vocle(?:_cloudinary)?\.py$|vocle_(bootstrap|android)\.py$|vocle-runtime-lock\.json$|Setup-VocleWsl\.ps1$))/.test(f))
    .filter(f => !/\/(node_modules|output)\//.test(f));
  await overlay(root, harnessPaths, harness);
  harnessInfo = { sha: harnessSha, ...(await fingerprint(harness, harnessPaths)), verified: true };
  // Test definitions come from the harness; application bytes stay from the selected source.
  await cp(join(harness, 'medcollab-app/test'), join(target, 'medcollab-app/test'), { recursive: true });
  const backendScripts = harnessPaths.filter(f => f.startsWith('medcollab-backend/scripts/security'));
  await overlay(harness, backendScripts, target);
  environment = { node: process.version, platform: process.platform, timezone: 'UTC', backendImage: image, flutterRequired: '3.29.3', backendLock: hash(await readFile(join(target, 'medcollab-backend/package-lock.json'))), flutterLock: hash(await readFile(join(target, 'medcollab-app/pubspec.lock'))) };
  await command('catalog-validation', process.execPath, [join(harness, 'tests/functional-regression/scripts/validate-catalog.mjs')], harness);
  await command('ci-device-contracts', process.execPath, ['--test', join(harness, 'tests/functional-regression/scripts/ci-contracts.test.mjs'), join(harness, 'tests/functional-regression/scripts/device-contracts.test.mjs')], harness);
  await command('functional-classification', process.execPath, [join(harness, 'tests/functional-regression/src/runner.mjs'), '--self-check'], harness);
  if (options['ci-checks']) {
    await command('ci-workflow-reporting-contracts', process.execPath, ['--test', ...['developer-workflow/workflow.test.mjs', 'developer-workflow/process.test.mjs', 'developer-workflow/cloudinary-local.test.cjs', 'developer-workflow/cloudinary-evidence.test.mjs', 'reporting/report.test.mjs', 'reporting/workflow-adapters.test.mjs'].map(file => join(harness, 'tests', file))], harness);
    const python = process.env.VIRTUAL_ENV ? join(process.env.VIRTUAL_ENV, process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python') : process.platform === 'win32' ? 'python' : 'python3';
    await command('ci-python-environment', python, ['-c', 'import pytest, requests, httpx; print("pytest, requests, and httpx imported successfully")'], harness);
    await command('ci-python-launcher-contracts', python, ['-B', '-m', 'unittest', 'discover', '-s', 'tests/developer-workflow', '-p', 'test_*.py', '-v'], harness);
    await command('ci-gitleaks', options['gitleaks-bin'] || 'gitleaks', ['git', '--no-banner', '--redact=100', '--config=' + join(harness, '.gitleaks.toml'), '--report-format=json', '--report-path=' + join(output, 'gitleaks.json'), '--log-opts=' + sha, source], harness);
  }
  const install = await command('backend-locked-dependencies', npm, ['ci', '--ignore-scripts', '--no-audit', '--no-fund'], join(target, 'medcollab-backend'), true, { infrastructure: true });
  if (install.code === 0) {
    for (const script of ['security-manifest-check.js', 'security-media/check.js', 'security-media/self-test.js', 'security-data/check.js', 'security-data/self-test.js', 'security-cloudinary/check.js', 'security-cloudinary/self-test.js', 'security-cloudinary/transport-test.js']) {
      await command('security-' + script.replaceAll('/', '-').replace('.js', ''), process.execPath, [join(target, 'medcollab-backend/scripts', script)], target);
    }
  } else add('security-offline', 'BLOCKED', true, { exclusion: 'Pinned backend dependencies unavailable' });
  const sanityInstall = await command('sanity-locked-dependencies', npm, ['ci', '--ignore-scripts', '--no-audit', '--no-fund'], join(harness, 'tests/sanity'), true, { infrastructure: true });
  if (sanityInstall.code === 0) await command('sanity-self-check', process.execPath, [join(harness, 'tests/sanity/src/runner.js'), '--self-check'], harness);
  else add('sanity-self-check', 'BLOCKED', true, { exclusion: 'Pinned sanity dependencies unavailable' });
  if (['full', 'backend-smoke'].includes(options.profile || 'full')) {
    // Backend runtime uses precisely the existing CI network-none preparation and runners.
    docker = await execute(dockerBin, ['info', '--format', '{{.OSType}}'], { env, timeout: 20000 });
    environment.docker = docker.code === 0 ? docker.stdout.trim() : 'unavailable';
    const smoke = options.profile === 'backend-smoke';
    const backend = smoke ? [{ id: 'harness-smoke', module: 'HARNESS', tier: 'B' }] : catalog.filter(c => c.tier === 'B');
    if (docker.code !== 0 || docker.stdout.trim() !== 'linux') unavailable(backend, 'Linux Docker engine unavailable; network-none isolation is required', true);
    else {
      const backendOut = join(output, 'backend'); await mkdir(backendOut);
      const mounts = ['--mount', `type=bind,source=${target},target=/target`, '--mount', `type=bind,source=${harness},target=/harness`, '--mount', `type=bind,source=${backendOut},target=/output`];
      const prep = await command('docker-prepare', dockerBin, ['run', '--rm', ...mounts, '-e', 'HOME=/tmp', image, 'sh', '-ec', 'cd /target/medcollab-backend && npm ci --ignore-scripts; cd /harness/tests/sanity && npm ci --ignore-scripts; node /harness/tests/functional-regression/scripts/prepare-mongo.mjs /target /output'], root);
      if (prep.code !== 0) unavailable(backend, 'Docker dependency/Mongo preparation failed', true);
      else {
        environment.mongoBinaries = await fingerprint(join(backendOut, 'mongo-binaries'), (await readdir(join(backendOut, 'mongo-binaries'))).filter(f => !f.endsWith('.lock')));
        await command('backend-driver', dockerBin, ['run', '--rm', '--network', 'none', '--read-only', '--tmpfs', '/tmp:rw,exec', '--mount', `type=bind,source=${target},target=/target,readonly`, '--mount', `type=bind,source=${harness},target=/harness,readonly`, '--mount', `type=bind,source=${backendOut},target=/output`, '-e', 'HOME=/tmp', '-e', 'TZ=UTC', '-e', 'VOCLE_TARGET_DIR=/target', '-e', 'VOCLE_OUTPUT_DIR=/output', '-e', 'VOCLE_SCOPE=backend-all', image, 'sh', '-ec', 'node /harness/tests/functional-regression/scripts/preflight-isolation.mjs && node /harness/tests/functional-regression/' + (smoke ? 'src/runner.mjs --smoke' : 'scripts/run-backend.mjs')], root);
        const execution = smoke ? null : JSON.parse(await readFile(join(backendOut, 'execution.json')));
        const reports = [];
        if (smoke) reports.push(JSON.parse(await readFile(join(backendOut, 'smoke/results.json'))));
        for (const entry of await readdir(backendOut, { withFileTypes: true })) {
          if (!smoke && entry.isDirectory() && entry.name.endsWith('-' + execution.runId) && !entry.name.startsWith('sanity-original')) reports.push(JSON.parse(await readFile(join(backendOut, entry.name, 'results.json'))));
        }
        const observed = reports.flatMap(r => r.results);
        if (new Set(observed.map(r => r.id)).size !== observed.length || observed.some(r => !backend.some(c => c.id === r.id))) throw new Error('Backend report IDs duplicated or unexpected');
        for (const c of backend) {
          const actual = observed.find(r => r.id === c.id);
          add(c.id, actual?.status || 'ERROR', true, { ...c, ...actual, executed: assertionExecuted(actual), artifacts: ['backend/'], error: actual?.error || (!actual ? 'No result for selected ID' : undefined) });
        }
        const clean = reports.length > 0 && reports.every(r => r.cleanup?.status === 'PASS' && r.complete && (smoke || (r.targetSha === sha && r.harnessSha === harnessInfo.sha))) && (await readdir(join(backendOut, 'runtime')).catch(() => [])).length === 0;
        add('backend-evidence-integrity', clean ? 'PASS' : 'ERROR', true, { executed: true, error: clean ? undefined : 'Incomplete module report, source mismatch or cleanup failure' });
      }
    }
    if (!smoke) {
    const app = join(target, 'medcollab-app');
    const version = await execute(flutter, ['--version', '--machine'], { cwd: app, env, timeout: 60000 });
    let sdk, flutterRoot; try { const info = JSON.parse(version.stdout); sdk = info.frameworkVersion; flutterRoot = info.flutterRoot; } catch { /* report unavailable */ }
    environment.flutter = sdk || 'unavailable';
    if (sdk !== '3.29.3') {
      unavailable(catalog.filter(c => c.tier === 'F'), 'Pinned Flutter 3.29.3 unavailable; actual SDK ' + (sdk || 'unknown'), true);
      add('flutter-retained', 'BLOCKED', true, { exclusion: 'Pinned Flutter SDK unavailable' });
      add('flutter-analysis', 'BLOCKED', true, { exclusion: 'Pinned Flutter SDK unavailable' });
    } else {
      const deps = await command('flutter-locked-dependencies', flutter, ['pub', 'get', '--enforce-lockfile'], app);
      if (deps.code !== 0) {
        unavailable(catalog.filter(c => c.tier === 'F'), 'Locked Flutter dependencies unavailable', true);
        add('flutter-retained', 'BLOCKED', true, { exclusion: 'Locked Flutter dependencies unavailable' });
        add('flutter-analysis', 'BLOCKED', true, { exclusion: 'Locked Flutter dependencies unavailable' });
      }
      else {
        // Use this Flutter SDK's analyzer directly. Flutter 3.29.3's wrapper scans
        // SDK development examples even for a single app, which fails on some Windows archives.
        const dart = join(flutterRoot, 'bin/cache/dart-sdk/bin', process.platform === 'win32' ? 'dart.exe' : 'dart');
        await command('flutter-analysis', dart, ['analyze', '--format', 'machine'], app, true, { failureCodes: [1, 2, 3] });
        const tests = await execute(flutter, ['test', '--no-pub', '--reporter', 'json', 'test/functional_regression'], { cwd: app, env, timeout: 12 * 60 * 1000, log: join(output, 'diagnostics/flutter-catalog.log') });
        await writeFile(join(output, 'flutter.ndjson'), tests.stdout);
        const flutterProvenance = join(output, 'flutter-provenance.json');
        await writeFile(flutterProvenance, JSON.stringify({ source: sourceInfo, harnessSha: harnessInfo.sha,
          sourceKind: sourceInfo.kind, inputSha256: hash(tests.stdout) }));
        const aggregate = await command('flutter-aggregation', process.execPath, [join(harness, 'tests/functional-regression/scripts/aggregate-flutter.mjs'), join(output, 'flutter.ndjson'), join(output, 'flutter'), flutterProvenance], harness);
        if (aggregate.code !== 0) unavailable(catalog.filter(c => c.tier === 'F'), 'Flutter report aggregation failed', true);
        else {
          const report = JSON.parse(await readFile(join(output, 'flutter.json')));
          for (const c of catalog.filter(c => c.tier === 'F')) {
            const actual = report.cases.find(r => r.id === c.id);
            add(c.id, actual?.status || 'ERROR', true, { ...c, ...actual, executed: assertionExecuted(actual), artifacts: ['flutter.ndjson', 'flutter.json'], error: actual?.evidence || (!actual ? 'Missing Flutter case' : undefined) });
          }
          if (tests.error || tests.timedOut || (tests.code !== 0 && report.cases.every(r => r.status === 'PASS'))) add('flutter-driver', 'ERROR', true, { executed: true, error: 'Flutter driver failure/timeout inconsistent with report' });
        }
        const retained = (await readdir(join(app, 'test'))).filter(f => f.endsWith('_test.dart')).map(f => 'test/' + f);
        if (!retained.length) add('flutter-retained', 'ERROR', true, { error: 'No retained tests discovered' });
        else await command('flutter-retained', flutter, ['test', '--no-pub', ...retained], app);
      }
    }
    // The existing Android runner only supports committed archives. Dirty input remains explicit.
    if (options.android && sourceInfo.kind === 'commit' && source === root) {
      const androidSdk = env.ANDROID_HOME || env.ANDROID_SDK_ROOT;
      const adb = androidSdk ? ['--adb-bin=' + join(androidSdk, 'platform-tools', process.platform === 'win32' ? 'adb.exe' : 'adb')] : [];
      const device = await command('android-driver', process.execPath, [join(root, 'tests/functional-regression/scripts/run-device.mjs'), '--source-sha=' + sha, '--flutter-bin=' + flutter, '--output=' + join(output, 'android'), ...adb], root, true);
      let deviceReport; try { deviceReport = JSON.parse(device.stdout.trim().split(/\r?\n/).at(-1)); } catch { /* explicit missing report */ }
      if (deviceReport?.reportDirectory) {
        const report = JSON.parse(await readFile(join(deviceReport.reportDirectory, 'results.json')));
        if (resolve(deviceReport.reportDirectory) !== join(output, 'android')) throw new Error('Android results escaped the current run folder');
        for (const c of catalog.filter(c => c.tier === 'D')) { const actual = report.cases.find(r => r.id === c.id); add(c.id, actual?.status || 'ERROR', true, { ...c, ...actual, executed: assertionExecuted(actual), artifacts: ['android/'] }); }
      } else unavailable(catalog.filter(c => c.tier === 'D'), 'Android runner produced no usable report', true);
    } else unavailable(catalog.filter(c => c.tier === 'D'), options.android ? 'Existing Android runner requires a committed source revision available in this harness checkout' : 'Optional Android lane: rerun with --android on an isolated emulator', Boolean(options.android));
    add('backend-legacy-jest', 'BLOCKED', false, { exclusion: 'Two retained Jest files exist, but Jest and a Jest runner are absent from the lockfile; backend npm test is a placeholder. No assertion execution claimed.' });
    }
  }
  if (options.profile === 'security') {
    docker = await execute(dockerBin, ['info', '--format', '{{.OSType}}'], { env, timeout: 20000 });
    environment.docker = docker.code === 0 ? docker.stdout.trim() : 'unavailable';
  }
  if (options.security || (options.profile || 'full') === 'full') {
    if (options.security && docker?.code === 0 && docker.stdout.trim() === 'linux') {
      const securityOut = join(output, 'security'); await mkdir(securityOut);
      const securityPrep = await command('security-runtime-prepare', dockerBin, ['run', '--rm', '--mount', `type=bind,source=${target},target=/target`, '--mount', `type=bind,source=${harness},target=/harness,readonly`, '--mount', `type=bind,source=${securityOut},target=/output`, '-e', 'HOME=/tmp', image, 'sh', '-ec', 'cd /target/medcollab-backend && npm ci --ignore-scripts; mkdir -p /target/medcollab-backend/uploads; node /harness/tests/functional-regression/scripts/prepare-mongo.mjs /target /output'], root, true, { infrastructure: true });
      if (securityPrep.code === 0) {
        const securityRun = await command('security-runtime-driver', dockerBin, ['run', '--rm', '--network', 'none', '--read-only', '--tmpfs', '/tmp:rw,exec', '--tmpfs', '/target/medcollab-backend/uploads:rw,noexec,nosuid', '--mount', `type=bind,source=${target},target=/target,readonly`, '--mount', `type=bind,source=${harness},target=/harness,readonly`, '--mount', `type=bind,source=${securityOut},target=/output`, '-e', 'HOME=/tmp', image, 'node', '/harness/tests/developer-workflow/security-runtime.mjs'], root, true, { infrastructure: true });
        const files = ['vocle-media-results', 'vocle-data-results', 'vocle-security-results'];
        for (const dir of files) {
          try {
            const result = JSON.parse(await readFile(join(securityOut, dir, 'results.json')));
            const measured = result.cases || result.results || [];
            if (result.infrastructureFailure || measured.length !== result.planned || result.executed !== measured.length) {
              add('security-completeness-' + dir, 'ERROR', true, { error: 'Original suite did not complete: ' + measured.length + '/' + result.planned, artifacts: ['security/' + dir + '/results.json'] });
            }
            for (const r of measured) {
              const status = securityOutcome(r);
              const catalogId = r.caseId || r.id;
              if (!catalogId) throw new Error('Security result has no original catalog ID');
              // Media reuses baseline discovery IDs. Keep each measured suite
              // execution separate, and retain its unchanged catalog ID.
              add(dir + ':' + catalogId, status, false, { catalogId, suite: dir, recordedStatus: r.status, classification: r.classification,
                executed: true, module: r.module || 'SECURITY', expected: JSON.stringify(r.expected), error: status === 'PASS' ? undefined : JSON.stringify(r.actual || r.classification), artifacts: ['security/' + dir + '/results.json'] });
            }
          } catch (e) { add('security-report-' + dir, 'ERROR', true, { error: 'Missing/invalid security evidence: ' + e.message }); }
        }
        if (securityRun.code !== 0) integrity = 'ERROR';
      }
    } else add('security-runtime', 'BLOCKED', Boolean(options.security), { exclusion: options.security ? 'Requested security runtime requires Linux Docker isolation' : 'Optional: --security reuses existing media, data and 691-case discovery runners in network-none Docker. Cloudinary uses the separate prompted launcher.' });
    if (!options['cloudinary-output']) add('provider-accounts', 'BLOCKED', false, { exclusion: 'Private test credentials required: add --cloudinary --test-cloud APPROVED_TEST_CLOUD, or run scripts/test_vocle_cloudinary.py separately. Reuses existing Cloudinary assertions and scoped cleanup.' });
    add('ios-physical-device', 'BLOCKED', false, { exclusion: 'QA-only: platform hardware/runner required; existing coverage makes no iOS claim' });
    if (options.apk) {
      const apkPath = resolve(options.apk);
      add('submitted-apk', 'BLOCKED', false, { exclusion: 'Arbitrary APK cannot establish source binding or execute instrumented Flutter assertions. Use the existing Android runner to build from the exact SHA.', apk: { sha256: hash(await readFile(apkPath)), bytes: (await lstat(apkPath)).size } });
    }
  }
  if (options['cloudinary-output']) {
    try {
      const provider = await providerEvidence(resolve(options['cloudinary-output']), sha, harness);
      await cp(join(resolve(options['cloudinary-output']), 'vocle-cloudinary-results'), join(output, 'cloudinary'), { recursive: true });
      rows.push(...provider.rows);
      add('cloudinary-evidence-integrity', 'PASS', true, { executed: true, artifacts: ['cloudinary/'] });
    } catch (error) { add('cloudinary-evidence-integrity', 'ERROR', true, { error: error.message }); }
  }
  const after = await fingerprint(target, sourcePaths);
  const changedSourceFiles = sourcePaths.filter(file => before.hashes[file] !== after.hashes[file]);
  const generated = file => /^medcollab-app\/(linux|windows)\/flutter\/(generated_plugin_registrant\.(cc|h)|generated_plugins\.cmake)$/.test(file);
  await writeFile(join(output, 'source-integrity.json'), JSON.stringify({ changedSourceFiles, generatedBuildOutputs: changedSourceFiles.filter(generated), immutableSourceChanges: changedSourceFiles.filter(file => !generated(file)), before: before.fingerprint, after: after.fingerprint }, null, 2));
  if (changedSourceFiles.some(file => !generated(file))) { integrity = 'ERROR'; add('source-integrity', 'ERROR', true, { executed: true, error: 'Selected application source/lockfile changed during testing: ' + changedSourceFiles.filter(file => !generated(file)).join(', '), artifacts: ['source-integrity.json'] }); }
  else add('source-integrity', 'PASS', true, { executed: true });
  if ((await fingerprint(harness, harnessPaths)).fingerprint !== harnessInfo.fingerprint) { integrity = 'ERROR'; add('harness-integrity', 'ERROR', true, { executed: true, error: 'Test definitions changed during execution' }); }
  else add('harness-integrity', 'PASS', true, { executed: true });
} catch (error) {
  integrity = 'ERROR'; add('workflow-infrastructure', 'ERROR', true, { error: error.message });
  if ((options.profile || 'full') === 'full') unavailable(catalog.filter(c => !rows.some(r => r.id === c.id)), 'Orchestration/setup failed; no testcase execution evidence', true);
} finally {
  for (const name of ownedContainers) {
    const present = await run(dockerBin, dockerArguments(['container', 'ls', '--all', '--filter', 'name=^/' + name + '$', '--format', '{{.Names}}']), { env, timeout: 15000 });
    if (present.code !== 0 || (present.stdout.trim() && (await run(dockerBin, dockerArguments(['rm', '--force', name]), { env, timeout: 30000 })).code !== 0)) {
      integrity = 'ERROR'; add('container-cleanup-' + name, 'ERROR', true, { error: 'Cannot verify removal of owned container ' + name });
    }
  }
  if (scratch) {
    try {
      if (!resolve(scratch).startsWith(resolve(tmpdir()) + sep + 'vocle-dev-')) throw new Error('Unsafe cleanup target');
      await rm(scratch, { recursive: true, force: true, maxRetries: 3, retryDelay: 500 });
      add('workspace-cleanup', 'PASS', true, { executed: true });
    } catch (e) { integrity = 'ERROR'; add('workspace-cleanup', 'ERROR', true, { executed: true, error: e.message }); }
  }
  try {
    for (const folder of ['backend/mongo-binaries', 'security/mongo-binaries']) {
      await rm(join(output, folder), { recursive: true, force: true, maxRetries: 3, retryDelay: 500 });
    }
    add('runtime-binary-cleanup', 'PASS', true, { executed: true });
  } catch (e) { integrity = 'ERROR'; add('runtime-binary-cleanup', 'ERROR', true, { executed: true, error: e.message }); }
}
sourceInfo ||= { sha: null, kind: 'unverified', verified: false };
harnessInfo ||= { sha: null, verified: false };
for (const row of rows) {
  row.definitionFingerprint = hash(JSON.stringify({ id: row.id, expected: row.expected, harness: harnessInfo.fingerprint }));
  row.environmentFingerprint = hash(JSON.stringify(environment));
}
const report = { context: captureContext(source, { repository: options.repository, branchRef: options['branch-ref'], prNumber: options['pr-number'] }), execution: executionIdentity(), scope: options.profile || 'full', source: sourceInfo, harness: harnessInfo, environment, integrity, reproduction: commandLine, results: rows };
const manifest = await writeEvidence(output, report);
await writeQA(output, report, JSON.parse(await readFile(join(root, 'tests/developer-workflow/ownership.json'))));
await generateDetailedReport({ inputObject: report, output: join(output, 'detailed'), suite: 'developer', statuses: ['PASS','FAIL','ERROR','BLOCKED','NEEDS_DECISION','SKIP','OBSERVATION'], artifact: 'developer-qa evidence (detailed directory)' });
if ((options.profile || 'full') === 'full') {
  const selected = catalog.filter(c => options.android || c.tier !== 'D');
  const ids = new Set(selected.map(c => c.id));
  const functional = rows.filter(row => ids.has(row.id));
  if (functional.length !== selected.length) throw new Error('Functional report is missing selected catalog IDs');
  await generateDetailedReport({ inputObject: { ...report, results: functional, selectedIds: selected.map(c => c.id) }, output: dirname(output), suite: 'developer', artifact: 'Functional cases from this invocation only; original evidence under evidence/' });
  await writeQA(dirname(output), { ...report, results: functional }, JSON.parse(await readFile(join(root, 'tests/developer-workflow/ownership.json'))));
  await writeFile(join(dirname(output), 'functional-summary.json'), JSON.stringify({ source: sourceInfo, harness: harnessInfo, registered: selected.length, executed: functional.filter(row => row.executed).length,
    counts: Object.fromEntries(['PASS', 'FAIL', 'ERROR', 'BLOCKED', 'NEEDS_DECISION', 'SKIP'].map(status => [status, functional.filter(row => row.status === status).length])),
    unexecuted: functional.filter(row => !row.executed).map(row => ({ id: row.id, status: row.status, error: row.error || row.exclusion })) }, null, 2) + '\n');
}
await localComparison({ currentDirectory: output, resultRoot: join(source, 'test-results'), previousDirectory: options.previous && resolve(options.previous), output: join(output, 'comparison') });
console.log(JSON.stringify({ output, gate: manifest.gate, scope: report.scope, executed: manifest.executedIds.length, source: sourceInfo.sha, kind: sourceInfo.kind }, null, 2));
if (manifest.gate !== 'PASS') process.exitCode = 1;
