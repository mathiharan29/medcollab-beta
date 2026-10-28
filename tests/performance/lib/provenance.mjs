import { createHash } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { type, release } from 'node:os';
import schema from '../schemas/provenance.schema.json' with { type: 'json' };
import { assertSchema, digest, immutable, requireContract } from './core.mjs';
import { assertValidatedConfig } from './config.mjs';

export function captureProvenance(inputs) {
  const { config } = inputs;
  assertValidatedConfig(config);
  const provenance = {
    schemaVersion: 1, runId: config.runId, repository: config.repository,
    sourceSha: config.sourceSha, harnessSha: config.harnessSha, configHash: digest(config),
    lockfileHashes: [...inputs.lockfileHashes, { path: 'tests/performance/package-lock.json', sha256: createHash('sha256').update(readFileSync(new URL('../package-lock.json', import.meta.url))).digest('hex') }],
    runtime: {
      node: process.version,
      artillery: installedVersion('artillery'), socketIOClient: installedVersion('socket.io-client'),
      os: `${type()} ${release()}`, arch: process.arch,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    },
    environmentId: config.environment.id, topologyHash: config.environment.topologyHash,
    dataManifestHash: config.data.manifestHash, indexManifestHash: config.data.indexManifestHash,
    providerConfigHash: digest(config.providers), instrumentationHash: digest(config.instrumentation),
    executionIdentity: inputs.executionIdentity, capturedAt: Date.now(),
  };
  const result = immutable({ ...provenance, digest: digest(provenance) });
  assertSchema(result, schema);
  requireContract(new Set(result.lockfileHashes.map((item) => item.path)).size === result.lockfileHashes.length, 'DUPLICATE_LOCKFILE');
  requireContract(result.lockfileHashes.some((item) => item.path === 'medcollab-backend/package-lock.json'), 'SOURCE_LOCKFILE_EVIDENCE_REQUIRED');
  return result;
}
function installedVersion(name) {
  const location = new URL(`../node_modules/${name}/package.json`, import.meta.url);
  return existsSync(location) ? JSON.parse(readFileSync(location, 'utf8')).version : null;
}

export function assertProvenance(provenance, config) {
  assertValidatedConfig(config);
  assertSchema(provenance, schema);
  const { digest: recordedDigest, ...fields } = provenance;
  requireContract(digest(fields) === recordedDigest && provenance.configHash === digest(config) && provenance.runId === config.runId && provenance.sourceSha === config.sourceSha && provenance.harnessSha === config.harnessSha && provenance.environmentId === config.environment.id && provenance.topologyHash === config.environment.topologyHash && provenance.dataManifestHash === config.data.manifestHash && provenance.indexManifestHash === config.data.indexManifestHash && provenance.providerConfigHash === digest(config.providers) && provenance.instrumentationHash === digest(config.instrumentation), 'PROVENANCE_MISMATCH');
}
