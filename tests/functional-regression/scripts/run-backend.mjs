import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { catalogCases, harnessRoot, selectBackendRun, suiteFiles } from './ci-contracts.mjs';

const output = resolve(process.env.VOCLE_OUTPUT_DIR || join(harnessRoot, 'output'));
const target = process.env.VOCLE_TARGET_DIR;
const scope = process.env.VOCLE_SCOPE || 'backend-all';
const feature = scope === 'backend-feature' ? process.env.VOCLE_FEATURE : undefined;
const affected = (process.env.VOCLE_AFFECTED_MODULES || '').split(',').filter(Boolean);
if (!target) throw new Error('VOCLE_TARGET_DIR is required');
const selected = await selectBackendRun(await catalogCases(), scope, affected, feature);
if (feature !== undefined && existsSync(join(output, 'execution.json'))) throw new Error('Use a fresh backend feature output directory');
const newIds = selected.filter((item) => item.coverage === 'NEW').map((item) => item.id);
const sanityIds = selected.filter((item) => item.coverage === 'EXISTING').map((item) => item.id);
const runId = `ci${randomUUID().replaceAll('-', '').slice(0, 22)}`;
const diagnostics = join(output, 'diagnostics');
await mkdir(diagnostics, { recursive: true });
const attempts = [];
const executors = [
  ...(sanityIds.length ? [['sanity', 'src/sanity-adapter.mjs', null]] : []),
  ...Object.entries(suiteFiles).map(([prefix, file]) => [file, `suites/${file}.mjs`, prefix]),
];
for (const [name, source, module] of executors) {
  if (module && !selected.some((item) => item.coverage === 'NEW' && item.module === module)) continue;
  const env = { ...process.env, VOCLE_RUN_ID: runId, VOCLE_TARGET_DIR: target, VOCLE_OUTPUT_DIR: output, VOCLE_CASE_IDS: newIds.join(',') };
  delete env.SANITY_CASE_IDS;
  if (!module && scope === 'backend-feature') env.SANITY_CASE_IDS = sanityIds.join(',');
  const child = spawnSync(process.execPath, [join(harnessRoot, source)], { cwd: harnessRoot, env, encoding: 'utf8', timeout: module === 'NDL' ? 480000 : 240000, maxBuffer: 10 * 1024 * 1024 });
  await writeFile(join(diagnostics, `${name}.log`), `${child.stdout || ''}${child.stderr || ''}`);
  attempts.push({ name, module, exitCode: child.status, signal: child.signal, spawnError: child.error?.message || null });
  console.log(`${name}: exit ${child.status ?? 'none'}${child.error ? ` (${child.error.message})` : ''}`);
}
await writeFile(join(output, 'execution.json'), `${JSON.stringify({ schemaVersion: 1, scope, feature, runId, selectedIds: selected.map((item) => item.id), attempts }, null, 2)}\n`);
console.log(JSON.stringify({ scope, runId, selected: selected.length, moduleAttempts: attempts.length }, null, 2));
