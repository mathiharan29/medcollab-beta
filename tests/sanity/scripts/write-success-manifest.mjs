import { captureContext, executionIdentity } from '../../developer-workflow/context.mjs';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const output = process.env.SANITY_OUTPUT_DIR;
const upstreamSha = process.env.SANITY_UPSTREAM_SHA;
const harnessSha = process.env.SANITY_HARNESS_SHA;
const suiteFingerprint = process.env.SUITE_FINGERPRINT;
const runId = Number(process.env.GITHUB_RUN_ID);
const attempt = Number(process.env.GITHUB_RUN_ATTEMPT);
if (!output || ![upstreamSha, harnessSha].every((sha) => /^[a-f0-9]{40}$/.test(sha || '')) || !/^[a-f0-9]{64}$/.test(suiteFingerprint || '') || !Number.isSafeInteger(runId) || !Number.isSafeInteger(attempt)) {
  throw new Error('Success-manifest provenance is incomplete.');
}

const report = JSON.parse(readFileSync(join(output, 'sanity-report.json'), 'utf8'));
const ids = (report.scenarios || []).map((scenario) => scenario.id);
if (report.result !== 'passed' || report.expectedScenarioCount !== 48 || report.passedScenarioCount !== 48 || report.failedScenarioCount !== 0 || report.blockedScenarioCount !== 0 || ids.length !== 48 || new Set(ids).size !== 48 || report.scenarios.some((scenario) => scenario.status !== 'passed') || report.metadata?.upstreamSha !== upstreamSha || report.metadata?.harnessSha !== harnessSha) {
  throw new Error('A complete passing report is required before success evidence can be published.');
}

const manifest = {
  context: captureContext(process.cwd()),
  execution: executionIdentity(),
  schemaVersion: 1,
  upstreamRepository: 'mathiharan29/medcollab-beta',
  upstreamRef: 'refs/heads/master',
  upstreamSha,
  harnessSha,
  suiteFingerprint,
  runId,
  attempt,
  expectedScenarioCount: 48,
  passedScenarioCount: 48,
  completedAt: new Date().toISOString(),
  result: 'PASS',
};
writeFileSync(join(output, 'success-manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, { flag: 'wx', mode: 0o600 });
console.log('Complete passing sanity manifest created.');
