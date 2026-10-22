import { execFileSync } from 'node:child_process';
import { appendFile } from 'node:fs/promises';
import { suiteFiles } from './ci-contracts.mjs';

const all = Object.keys(suiteFiles);
const mappings = [
  [/\/features\/auth\/|\/services\/(otp|msg91Widget)\./, ['AUTH', 'PRO', 'JRN']],
  [/\/features\/users\//, ['PRO', 'DISC', 'JRN']],
  [/\/features\/spaces\//, ['SPC', 'CH', 'HOF', 'RT', 'SRCH', 'JRN']],
  [/\/features\/channels\//, ['CH', 'DM', 'MSG', 'THR', 'SOC', 'RT', 'SRCH', 'JRN']],
  [/\/features\/message-requests\//, ['REQ', 'DM', 'NOT', 'JRN']],
  [/\/features\/messages\//, ['MSG', 'THR', 'SOC', 'NOT', 'RT', 'SRCH', 'MED', 'JRN']],
  [/\/features\/media\/|\/utils\/localMediaStorage\./, ['MED', 'MSG', 'JRN']],
  [/\/features\/handoffs\//, ['HOF', 'NOT', 'SRCH', 'JRN']],
  [/\/features\/notifications\/|\/services\/notification\./, ['NOT', 'PUSH', 'JRN']],
  [/\/features\/search\//, ['SRCH', 'JRN']],
  [/\/features\/(support|dev)\//, ['SUP']],
];
export function affectedModules(paths) {
  const selected = new Set();
  for (const path of paths) {
    if (path.startsWith('tests/') || path.startsWith('.github/workflows/') || path.startsWith('medcollab-backend/') && !path.startsWith('medcollab-backend/src/features/') && !mappings.some(([pattern]) => pattern.test(path))) return all;
    if (!path.startsWith('medcollab-backend/')) continue;
    const matching = mappings.filter(([pattern]) => pattern.test(path));
    if (!matching.length) return all;
    for (const [, modules] of matching) for (const module of modules) selected.add(module);
  }
  return selected.size ? all.filter((module) => selected.has(module)) : all;
}
export function affectsFlutter(paths) {
  if (!paths.length) return true; // Unknown diff: validate conservatively.
  return paths.some((path) => path.startsWith('medcollab-app/') ||
      path.startsWith('tests/reporting/') ||
    path === 'tests/functional-regression/scripts/aggregate-flutter.mjs' ||
    path === '.github/workflows/vocle-functional-regression.yml' ||
    path === 'tests/functional-regression/scripts/affected-modules.mjs');
}
if (process.argv[1] && process.argv[1].replaceAll('\\', '/').endsWith('/affected-modules.mjs')) {
  const base = process.env.VOCLE_BASE_SHA;
  let paths = [];
  if (/^[a-f0-9]{40}$/.test(base || '') && base !== '0'.repeat(40)) {
    try { paths = execFileSync('git', ['diff', '--name-only', base, 'HEAD'], { encoding: 'utf8' }).trim().split(/\r?\n/).filter(Boolean); }
    catch { paths = ['tests/functional-regression/unknown']; }
  }
  const modules = affectedModules(paths);
  const flutterChanged = affectsFlutter(paths);
  if (process.env.GITHUB_OUTPUT) await appendFile(process.env.GITHUB_OUTPUT,
    `modules=${modules.join(',')}\nflutter_changed=${flutterChanged}\n`);
  console.log(JSON.stringify({ changedPaths: paths, modules, flutterChanged }));
}
