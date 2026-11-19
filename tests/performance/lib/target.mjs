import { createPublicKey, verify } from 'node:crypto';
import { isIP } from 'node:net';
import policyData from '../config/target-policy.json' with { type: 'json' };
import policySchema from '../schemas/target-policy.schema.json' with { type: 'json' };
import evidenceSchema from '../schemas/identity-evidence.schema.json' with { type: 'json' };
import { assertSchema, canonical, digest, immutable, requireContract, sameSet } from './core.mjs';
import { assertValidatedConfig } from './config.mjs';

const issued = new WeakSet();
const policy = immutable(policyData);
export function assertIsolatedTarget(config, identityEvidence) {
  assertValidatedConfig(config);
  assertSchema(policy, policySchema);
  const evidence = immutable(identityEvidence);
  assertSchema(evidence, evidenceSchema);
  const p = evidence.payload;
  const key = policy.trustedKeys.find((item) => item.id === p.keyId);
  const target = policy.targets.find((item) => item.serviceId === config.target.serviceId && item.environmentId === config.environment.id);
  requireContract(key && target, 'TARGET_NOT_ALLOWLISTED');
  const publicKey = createPublicKey(key.publicKeyPem);
  requireContract(publicKey.asymmetricKeyType === 'ed25519', 'UNSUPPORTED_AUTHORITY_KEY');
  requireContract(verify(null, Buffer.from(canonical(p)), publicKey, Buffer.from(evidence.signature, 'base64')), 'INVALID_IDENTITY_SIGNATURE');
  const url = new URL(config.target.url);
  const host = url.hostname.toLowerCase().replace(/\.$/, '');
  requireContract(!policy.productionHosts.some((name) => host === name || host.endsWith(`.${name}`)), 'PRODUCTION_TARGET_FORBIDDEN');
  requireContract(target.origin === url.origin && p.origin === url.origin && p.serviceId === target.serviceId && p.environmentId === target.environmentId, 'TARGET_IDENTITY_MISMATCH');
  requireContract(target.topologyHash === config.environment.topologyHash && p.topologyHash === target.topologyHash, 'TOPOLOGY_MISMATCH');
  requireContract(sameSet(config.target.addresses, target.addresses) && sameSet(p.resolvedAddresses, target.addresses) && p.resolvedAddresses.every((address) => isIP(address)), 'TARGET_ADDRESS_DRIFT');
  requireContract(p.runId === config.runId && p.authorizationRef === config.authorizationRef && p.sourceSha === config.sourceSha && p.harnessSha === config.harnessSha && p.configHash === digest(config), 'RUN_AUTHORIZATION_MISMATCH');
  requireContract(p.ownerIdentity === target.ownerIdentity && sameSet(p.namespaces, target.namespaces), 'OWNERSHIP_SCOPE_MISMATCH');
  const now = Date.now();
  requireContract(p.issuedAt <= now && p.expiresAt > now && p.expiresAt - p.issuedAt <= config.deadlines.totalMs, 'EXPIRED_OR_UNBOUNDED_LEASE');
  for (const [name, value] of Object.entries(config.budgets)) {
    if (typeof value === 'number') requireContract(name === 'diskReserveBytes' ? value >= target.budgetCeilings[name] : value <= target.budgetCeilings[name], 'AUTHORIZED_BUDGET_EXCEEDED');
    else requireContract(value === target.budgetCeilings[name], 'BUDGET_UNIT_MISMATCH');
  }
  const authorization = immutable({ ...p, targetUrl: url.origin, addressSet: p.resolvedAddresses, evidenceHash: digest(evidence) });
  issued.add(authorization);
  return authorization;
}
export function assertTargetAuthorization(authorization, permission, runId, configHash) {
  requireContract(issued.has(authorization) && authorization.runId === runId && (!configHash || authorization.configHash === configHash) && authorization.permissions.includes(permission) && authorization.expiresAt > Date.now(), 'TARGET_AUTHORIZATION_REQUIRED');
}
// Reporting expired/aborted work is permitted; this does not authorize any I/O.
export function assertHistoricalAuthorization(authorization, config) {
  requireContract(issued.has(authorization) && authorization.runId === config.runId && authorization.configHash === digest(config), 'RUN_AUTHORIZATION_EVIDENCE_REQUIRED');
}
export function assertPinnedDestination(authorization, { url, address, runId }) {
  assertTargetAuthorization(authorization, 'observe', runId);
  const destination = new URL(url);
  const origin = new URL(authorization.targetUrl);
  const protocol = destination.protocol.replace('ws:', 'http:').replace('wss:', 'https:');
  requireContract(!destination.username && !destination.password && !destination.hash && protocol === origin.protocol && destination.host === origin.host && authorization.addressSet.includes(address), 'UNAPPROVED_DESTINATION');
  // Adapters must call this for actual pinned TCP peer/address and every redirect.
  // No resolver, HTTP client or socket is created here; redirects stay disabled.
}
