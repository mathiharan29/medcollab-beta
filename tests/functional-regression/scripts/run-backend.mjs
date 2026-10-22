import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { catalogCases, harnessRoot, selectBackend, suiteFiles } from './ci-contracts.mjs';

const output = resolve(process.env.VOCLE_OUTPUT_DIR || join(harnessRoot, 'output'));
const target = process.env.VOCLE_TARGET_DIR;
const scope = process.env.VOCLE_SCOPE || 'backend-all';
const affected = (process.env.VOCLE_AFFECTED_MODULES || '').split(',').filter(Boolean);
if (!target) throw new Error('VOCLE_TARGET_DIR is required');
const selected = selectBackend(await catalogCases(), scope, affected);
const newIds = selected.filter((item) => item.coverage === 'NEW').map((item) => item.id);
const runId = `ci${randomUUID().replaceAll('-', '').slice(0, 22)}`;
const diagnostics = join(output, 'diagnostics');
await mkdir(diagnostics, { recursive: true });
const attempts = [];
for (const [name, source, module] of [['sanity', 'src/sanity-adapter.mjs', null], ...Object.entries(suiteFiles).map(([prefix, file]) => [file, `suites/${file}.mjs`, prefix])]) {
  if (module && !selected.some((item) => item.coverage === 'NEW' && item.module === module)) continue;
  const env = { ...process.env, VOCLE_RUN_ID: runId, VOCLE_TARGET_DIR: target, VOCLE_OUTPUT_DIR: output, VOCLE_CASE_IDS: newIds.join(',') };
  const child = spawnSync(process.execPath, [join(harnessRoot, source)], { cwd: harnessRoot, env, encoding: 'utf8', timeout: 240000, maxBuffer: 10 * 1024 * 1024 });
  await writeFile(join(diagnostics, `${name}.log`), `${child.stdout || ''}${child.stderr || ''}`);
  attempts.push({ name, module, exitCode: child.status, signal: child.signal, spawnError: child.error?.message || null });
  console.log(`${name}: exit ${child.status ?? 'none'}${child.error ? ` (${child.error.message})` : ''}`);
}
await writeFile(join(output, 'execution.json'), `${JSON.stringify({ schemaVersion: 1, scope, runId, selectedIds: selected.map((item) => item.id), attempts }, null, 2)}\n`);
console.log(JSON.stringify({ scope, runId, selected: selected.length, moduleAttempts: attempts.length }, null, 2));
