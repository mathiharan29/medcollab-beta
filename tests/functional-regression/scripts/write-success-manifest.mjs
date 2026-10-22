import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { catalogCases, environmentContractVersion, selectBackend, upstreamRef, upstreamRepository } from './ci-contracts.mjs';

const output = resolve(process.argv[2] || '');
const reportArtifactDigest = process.argv[3];
if (!/^sha256:[a-f0-9]{64}$/.test(reportArtifactDigest || '')) throw new Error('Validated report artifact digest required');
const manifest = JSON.parse(await readFile(join(output, 'manifest.json'), 'utf8'));
const provenance = JSON.parse(await readFile(join(output, 'provenance.json'), 'utf8'));
const cleanup = JSON.parse(await readFile(join(output, 'cleanup.json'), 'utf8'));
const resultsBytes = await readFile(join(output, 'results.json'));
const results = JSON.parse(resultsBytes).results;
const expectedIds = selectBackend(await catalogCases(), 'backend-all').map((item) => item.id);
if (manifest.result !== 'PASS' || manifest.verifiedBackendAll !== true || manifest.scope !== 'backend-all' || manifest.sourceKind !== 'pr-head' ||
    JSON.stringify(manifest.selectedIds) !== JSON.stringify(expectedIds) || JSON.stringify(results.map((item) => item.id)) !== JSON.stringify(expectedIds) ||
    results.some((item) => item.status !== 'PASS') || provenance.status !== 'PASS' || cleanup.status !== 'PASS' ||
    provenance.targetSha !== manifest.targetSha || provenance.harnessSha !== manifest.harnessSha) throw new Error('Full backend validation was not successful');
const evidence = { ...manifest, targetRepository: upstreamRepository, targetRef: manifest.context?.branchRef || null, environmentContractVersion, provenance, cleanup,
  resultsSha256: createHash('sha256').update(resultsBytes).digest('hex'), reportArtifactDigest };
await writeFile(join(output, 'success-manifest.json'), `${JSON.stringify(evidence, null, 2)}\n`);
console.log(JSON.stringify({ verifiedBackendAll: true, targetSha: manifest.targetSha, runId: manifest.runId, attempt: manifest.attempt }));
