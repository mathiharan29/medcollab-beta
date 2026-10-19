import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { readdir, readFile } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { validateStaticConfig } from './config.js';
import { expectedScenarioCount, scenarioGroups, scenarios, validateScenarioRegistry } from './scenarios.js';
import { writeExecutionReports, writePlannedReports } from './reporting.js';

const here = dirname(fileURLToPath(import.meta.url));
const outputDirectory = resolve(process.env.SANITY_OUTPUT_DIR || resolve(here, '..', 'output'));

async function main() {
  const failures = [...validateStaticConfig(), ...validateScenarioRegistry()];
  if (failures.length > 0) throw new Error(`Sanity harness contract failed:\n- ${failures.join('\n- ')}`);
  if (process.argv.includes('--live')) return runLive();
  if (!process.argv.includes('--self-check')) throw new Error('Use --self-check or --live.');
  const checks = ['static target configuration', 'isolation configuration', 'fixture identity contract', 'scenario registry'];
  await writePlannedReports({ outputDirectory, scenarios, checks });
  console.log(`Phase 1 self-check passed: ${expectedScenarioCount} planned scenarios; reports written to ${outputDirectory}.`);
}

const modules = ['live-runner.js', 'authentication-scenarios.js', 'spaces-and-channels-scenarios.js', 'messaging-scenarios.js', 'message-requests-and-conversations-scenarios.js', 'handoff-scenarios.js', 'media-scenarios.js', 'notification-scenarios.js', 'realtime-availability-scenarios.js', 'search-scenarios.js', 'support-scenarios.js'];
const execute = (file) => new Promise((resolveRun) => {
  console.log(`Starting sanity module: ${file}`);
  const startedAt = Date.now();
  const child = spawn(process.execPath, [resolve(here, file)], { stdio: 'inherit', env: process.env });
  let timedOut = false;
  const timer = setTimeout(() => { timedOut = true; child.kill('SIGKILL'); }, 60_000);
  child.on('exit', (code, signal) => { clearTimeout(timer); const outcome = { file, code: code ?? 1, timedOut, signal, durationMs: Date.now() - startedAt }; console.log(`Finished sanity module: ${JSON.stringify(outcome)}`); resolveRun(outcome); });
  child.on('error', (error) => { clearTimeout(timer); const outcome = { file, code: 1, error: error.message, durationMs: Date.now() - startedAt }; console.log(`Failed sanity module: ${JSON.stringify(outcome)}`); resolveRun(outcome); });
});

async function runLive() {
  const outcomes = [];
  for (const file of modules) outcomes.push(await execute(file));
  const files = await readdir(outputDirectory);
  const results = [];
  for (const file of files.filter((name) => name.endsWith('-results.json'))) {
    const parsed = JSON.parse(await readFile(resolve(outputDirectory, file), 'utf8'));
    results.push(...(parsed.results || []));
  }
  const startup = JSON.parse(await readFile(resolve(outputDirectory, 'startup-result.json'), 'utf8').catch(() => '{}'));
  if (startup.result) results.push({ id: 'startup-01', status: startup.result, durationMs: 0 });
  const report = await writeExecutionReports({ outputDirectory, scenarioGroups, results, metadata: { upstreamSha: process.env.SANITY_UPSTREAM_SHA, harnessSha: process.env.SANITY_HARNESS_SHA, modules: outcomes } });
  if (report.result !== 'passed' || outcomes.some((outcome) => outcome.code !== 0)) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
