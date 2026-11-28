import { createHash } from 'node:crypto';
import schema from '../schemas/actor-profile.schema.json' with { type: 'json' };
import { assertSchema, digest, finiteInteger, identifier, immutable, requireContract } from './core.mjs';

export function allocateActors(seed, profile, workerPartition) {
  const dimensions = immutable(profile);
  assertSchema(dimensions, schema);
  requireContract(identifier(seed) && finiteInteger(workerPartition.index) && finiteInteger(workerPartition.count, 1, 1000000) && workerPartition.index < workerPartition.count && dimensions.users * dimensions.devicesPerUser <= dimensions.maxActors, 'INVALID_ACTOR_PARTITION');
  const actors = [];
  for (let globalIndex = workerPartition.index; globalIndex < dimensions.users; globalIndex += workerPartition.count) {
    const userId = `synthetic-user-${digest({ version: 1, seed, runId: dimensions.runId, globalIndex }).slice(0, 32)}`;
    actors.push({ userId, globalIndex, identityRef: `SYNTHETIC-ACCOUNT-${String(globalIndex).padStart(8, '0')}`, devices: Array.from({ length: dimensions.devicesPerUser }, (_, deviceIndex) => ({ actorDeviceId: `${userId}-device-${deviceIndex}`, deviceIndex })) });
  }
  const manifest = { schemaVersion: 1, runId: dimensions.runId, seed, profile: dimensions, workerPartition: immutable(workerPartition), actors };
  return immutable({ ...manifest, digest: digest(manifest) });
}
export function createSeededRandom(seed, stream, maxDraws) {
  requireContract(identifier(seed) && identifier(stream) && finiteInteger(maxDraws, 1), 'INVALID_RANDOM_STREAM');
  let counter = 0;
  return Object.freeze({
    next() {
      requireContract(counter < maxDraws, 'RANDOM_DRAW_LIMIT');
      const bytes = createHash('sha256').update(JSON.stringify([1, seed, stream, counter++])).digest();
      return Number(bytes.readBigUInt64BE(0) >> 11n) / 9007199254740992;
    },
  });
}

// Fixture definitions only: later adapters create real owned resources and journal IDs.
// No phone number, auth credential, database document or business graph is fabricated.
export function defineSyntheticResource({ runId, type, key, ownerActorId }) {
  requireContract([runId, type, key, ownerActorId].every(identifier), 'INVALID_SYNTHETIC_RESOURCE');
  return immutable({ schemaVersion: 1, runId, type, key, ownerActorId, fixtureId: `synthetic-${digest({ runId, type, key, ownerActorId }).slice(0, 32)}` });
}
