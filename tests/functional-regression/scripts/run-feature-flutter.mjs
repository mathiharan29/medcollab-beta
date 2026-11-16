import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { closeSync, existsSync, mkdirSync, openSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, dirname, join, relative, resolve } from 'node:path';
import { catalogCases } from './ci-contracts.mjs';
import { featureExecutors } from './feature-executors.mjs';
import { loadFeature } from './feature-registry.mjs';

const root = resolve(import.meta.dirname, '../../..');
const feature = process.env.VOCLE_FEATURE;
const cases = await catalogCases();
const selected = (await loadFeature(feature, cases)).filter(row => row.tier === 'F');
if (!selected.length) throw new Error(`No Flutter cases for ${feature}`);
if (!process.env.VOCLE_FEATURE_OUTPUT) throw new Error('VOCLE_FEATURE_OUTPUT is required');

const output = resolve(process.env.VOCLE_FEATURE_OUTPUT, 'flutter');
if (existsSync(output)) throw new Error('Use a fresh Flutter feature output directory');
const executors = await featureExecutors(root, cases);
const app = join(root, 'medcollab-app');
const paths = [...new Set(selected.map(row => relative(app, resolve(root, executors.get(row.id)))))];
const ids = selected.map(row => row.id);
const pattern = `(?:^|[^a-zA-Z0-9_-])(?:${ids.join('|')})(?=$|[^a-zA-Z0-9_-])`;
const git = (...args) => execFileSync('git', ['-C', root, ...args], { encoding: 'utf8', windowsHide: true }).trim();
const target = process.env.VOCLE_TARGET_SHA;
const head = git('rev-parse', 'HEAD');
function verifySource() {
  if (git('rev-parse', 'HEAD') !== head) throw new Error('Flutter checkout moved during execution');
  if (target && (target !== head || git('status', '--porcelain', '--untracked-files=no', '--',
    'medcollab-app/lib', 'medcollab-app/test', 'medcollab-app/assets', 'medcollab-app/pubspec.yaml', 'medcollab-app/pubspec.lock'))) {
    throw new Error('Flutter source, tests or locked inputs differ from the selected commit');
  }
}
verifySource();

let flutter = process.env.VOCLE_FLUTTER_BIN || 'flutter';
const args = ['test', '--no-pub', '--reporter=json', '--name', pattern, ...paths];
if (process.platform === 'win32' && basename(flutter).toLowerCase() === 'flutter.bat') {
  const cache = join(dirname(resolve(flutter)), 'cache');
  flutter = join(cache, 'dart-sdk/bin/dart.exe');
  args.unshift(join(cache, 'flutter_tools.snapshot'));
}
mkdirSync(output, { recursive: true });
const events = join(output, 'events.ndjson');
const stdout = openSync(events, 'w');
const stderr = openSync(join(output, 'stderr.log'), 'w');
let run;
try {
  run = spawnSync(flutter, args, { cwd: app, stdio: ['ignore', stdout, stderr], windowsHide: true, timeout: 720000 });
} finally {
  closeSync(stdout);
  closeSync(stderr);
}
if (run.error) throw run.error;
verifySource();
const original = [events, join(output, 'report')];
if (target) {
  const provenance = join(output, 'provenance.json');
  writeFileSync(provenance, JSON.stringify({
    inputSha256: createHash('sha256').update(readFileSync(events)).digest('hex'),
    harnessSha: head, source: { sha: target, kind: 'commit', verified: true },
  }));
  original.push(provenance);
}
const aggregate = spawnSync(process.execPath, [join(import.meta.dirname, 'aggregate-flutter.mjs'), ...original], {
  stdio: 'inherit', windowsHide: true,
});
process.exitCode = aggregate.status === 0 ? run.status ?? 1 : 1;
