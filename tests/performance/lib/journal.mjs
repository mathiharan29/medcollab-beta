import { constants, openSync, closeSync, writeSync, fsyncSync, fstatSync, lstatSync, readFileSync, realpathSync, unlinkSync } from 'node:fs';
import path from 'node:path';
import { performance } from 'node:perf_hooks';
import resourceSchema from '../schemas/resource.schema.json' with { type: 'json' };
import { assertSchema, canonical, digest, HarnessError, immutable, requireContract, withDeadline } from './core.mjs';
import { assertValidatedConfig } from './config.mjs';
import { assertTargetAuthorization } from './target.mjs';

const journals = new WeakMap();
const maxRecordBytes = 8192; // Above the strict resource schema's worst-case escaped record.
function owned(resource, authorization) {
  assertSchema(resource, resourceSchema);
  requireContract(resource.runId === authorization.runId && resource.environmentId === authorization.environmentId && resource.ownerIdentity === authorization.ownerIdentity && authorization.namespaces.includes(resource.namespace), 'RESOURCE_OWNERSHIP_MISMATCH');
}
function writeAll(fd, text) {
  const bytes = Buffer.from(text);
  let offset = 0;
  while (offset < bytes.length) {
    const count = writeSync(fd, bytes, offset, bytes.length - offset);
    requireContract(count > 0, 'JOURNAL_SHORT_WRITE');
    offset += count;
  }
  fsyncSync(fd);
}
export function createResourceJournal({ directory, config, authorization, cleanupAdapters = {}, resume = false }) {
  assertValidatedConfig(config);
  assertTargetAuthorization(authorization, resume ? 'cleanup' : 'create', config.runId, digest(config));
  const root = realpathSync(directory);
  requireContract(path.isAbsolute(directory) && !lstatSync(directory).isSymbolicLink(), 'UNSAFE_JOURNAL_ROOT');
  const journalId = digest({ runId: config.runId, configHash: digest(config) });
  const filename = path.join(root, `${journalId}.jsonl`);
  const lockname = `${filename}.lock`;
  const noFollow = constants.O_NOFOLLOW ?? 0;
  // A new signed lease may reclaim only this exact expired run-owned lock.
  if (resume) {
    try {
      const stat = lstatSync(lockname);
      requireContract(stat.isFile() && !stat.isSymbolicLink() && stat.size <= 4096 && stat.nlink === 1, 'UNSAFE_JOURNAL_LOCK');
      const lock = JSON.parse(readFileSync(lockname, 'utf8'));
      requireContract(lock.journalId === journalId && lock.runId === config.runId && lock.expiresAt < Date.now() && lock.leaseId !== authorization.leaseId, 'JOURNAL_LOCK_ACTIVE');
      unlinkSync(lockname);
    } catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  const lockFd = openSync(lockname, constants.O_CREAT | constants.O_EXCL | constants.O_WRONLY | noFollow, 0o600);
  let fd;
  try {
    writeAll(lockFd, canonical({ journalId, runId: config.runId, leaseId: authorization.leaseId, expiresAt: authorization.expiresAt }) + '\n');
    if (resume) requireContract(lstatSync(filename).isFile() && !lstatSync(filename).isSymbolicLink() && lstatSync(filename).nlink === 1, 'UNSAFE_JOURNAL_FILE');
    fd = openSync(filename, constants.O_RDWR | constants.O_APPEND | noFollow | (resume ? 0 : constants.O_CREAT | constants.O_EXCL), 0o600);
    const state = { config, authorization, cleanupAdapters, fd, filename, lockname, lockFd, journalId, resources: new Map(), events: [], bytes: 0, previousHash: '0'.repeat(64), closed: false, broken: false };
    requireContract(fstatSync(fd).size <= config.journalLimits.maxBytes, 'JOURNAL_BYTE_LIMIT');
    if (resume) {
      const text = readFileSync(fd, 'utf8');
      requireContract(text.endsWith('\n'), 'JOURNAL_PARTIAL_RECORD');
      for (const line of text.trimEnd().split('\n')) replay(state, JSON.parse(line));
      requireContract(state.events[0]?.kind === 'header' && state.events[0].configHash === digest(config), 'JOURNAL_CONFIG_MISMATCH');
    }
    const journal = Object.freeze({
      id: journalId,
      runId: config.runId,
      snapshot: () => immutable({ schemaVersion: 1, journalId, runId: config.runId, resources: [...state.resources.values()], lastHash: state.previousHash, broken: state.broken }),
      close() {
        if (state.closed) return;
        state.closed = true;
        closeSync(fd);
        closeSync(lockFd);
        // The exact lock belongs to this open handle; never delete another lease's lock.
        const lock = JSON.parse(readFileSync(lockname, 'utf8'));
        requireContract(lock.leaseId === authorization.leaseId && lock.journalId === journalId, 'JOURNAL_LOCK_CHANGED');
        unlinkSync(lockname);
      },
    });
    journals.set(journal, state);
    if (!resume) append(state, { kind: 'header', configHash: digest(config) });
    return journal;
  } catch (error) {
    if (fd !== undefined) closeSync(fd);
    closeSync(lockFd);
    // Keep the lock and partial journal as quarantine evidence on setup failure.
    throw error;
  }
}
function replay(state, event) {
  requireContract(state.events.length < state.config.journalLimits.maxEntries, 'JOURNAL_ENTRY_LIMIT');
  const { hash, ...fields } = event;
  requireContract(hash === digest(fields) && event.schemaVersion === 1 && event.journalId === state.journalId && event.sequence === state.events.length && event.previousHash === state.previousHash, 'JOURNAL_INTEGRITY_FAILURE');
  if (event.kind === 'intent') {
    owned(event.resource, state.authorization);
    requireContract(!state.resources.has(event.resourceKey), 'DUPLICATE_RESOURCE_INTENT');
    state.resources.set(event.resourceKey, { resourceKey: event.resourceKey, resource: event.resource, state: 'INTENT', failures: [], retryCount: 0, remainingRecords: 2 + 2 * state.config.journalLimits.cleanupAttempts });
  } else if (event.kind === 'cleanupIntent') {
    const current = state.resources.get(event.resourceKey);
    requireContract(current, 'UNKNOWN_CLEANUP_RESOURCE');
    requireContract(current.remainingRecords > 0, 'JOURNAL_RESERVATION_EXHAUSTED');
    current.remainingRecords -= 1;
    current.retryCount += 1;
  } else if (event.kind === 'transition') {
    const current = state.resources.get(event.resourceKey);
    requireContract(current && ['CREATED', 'AMBIGUOUS', 'NOT_CREATED', 'CLEANUP_COMPLETE', 'CLEANUP_FAILED'].includes(event.state), 'INVALID_RESOURCE_TRANSITION');
    requireContract(current.remainingRecords > 0, 'JOURNAL_RESERVATION_EXHAUSTED');
    current.remainingRecords -= 1;
    if (event.resource) {
      owned(event.resource, state.authorization);
      requireContract(event.resource.intentId === current.resource.intentId && event.resource.type === current.resource.type && event.resource.namespace === current.resource.namespace, 'RESOURCE_ACK_MISMATCH');
      current.resource = event.resource;
    }
    current.state = event.state;
    if (['CLEANUP_COMPLETE', 'NOT_CREATED'].includes(event.state)) current.remainingRecords = 0;
    if (event.errorClass) current.failures.push(event.errorClass);
  } else requireContract(event.kind === 'header' && event.sequence === 0, 'UNKNOWN_JOURNAL_EVENT');
  state.events.push(event);
  state.previousHash = hash;
  state.bytes += Buffer.byteLength(canonical(event) + '\n');
}
function append(state, fields) {
  requireContract(!state.closed && !state.broken, 'JOURNAL_NOT_WRITABLE');
  const body = { schemaVersion: 1, journalId: state.journalId, sequence: state.events.length, previousHash: state.previousHash, ...fields };
  const event = immutable({ ...body, hash: digest(body) });
  const text = canonical(event) + '\n';
  requireContract(Buffer.byteLength(text) <= maxRecordBytes, 'JOURNAL_RECORD_LIMIT');
  requireContract(state.events.length < state.config.journalLimits.maxEntries && state.bytes + Buffer.byteLength(text) <= state.config.journalLimits.maxBytes, 'JOURNAL_LIMIT');
  requireContract(fstatSync(state.fd).size === state.bytes, 'JOURNAL_CONCURRENT_WRITER');
  try { writeAll(state.fd, text); replay(state, event); }
  catch { state.broken = true; throw new HarnessError('JOURNAL_WRITE_FAILED'); }
}
function getState(journal) {
  const state = journals.get(journal);
  requireContract(state && !state.closed && !state.broken, 'OWNED_JOURNAL_REQUIRED');
  return state;
}
export function registerOwnedResource(journal, resource) {
  const state = getState(journal);
  assertTargetAuthorization(state.authorization, 'create', state.config.runId, digest(state.config));
  const copy = immutable(resource);
  owned(copy, state.authorization);
  requireContract(copy.leaseId === state.authorization.leaseId, 'RESOURCE_LEASE_MISMATCH');
  const resourceKey = digest({ runId: copy.runId, type: copy.type, intentId: copy.intentId });
  requireContract(!state.resources.has(resourceKey), 'DUPLICATE_RESOURCE_INTENT');
  const pendingRecords = [...state.resources.values()].reduce((sum, item) => sum + item.remainingRecords, 0);
  const newRecords = 1 + 2 + 2 * state.config.journalLimits.cleanupAttempts;
  requireContract(state.events.length + pendingRecords + newRecords <= state.config.journalLimits.maxEntries && state.bytes + (pendingRecords + newRecords) * maxRecordBytes <= state.config.journalLimits.maxBytes, 'JOURNAL_CLEANUP_CAPACITY_REQUIRED');
  append(state, { kind: 'intent', resourceKey, resource: copy }); // fsync before caller creates anything.
  return immutable({ journalId: state.journalId, resourceKey, runId: copy.runId });
}
export function recordResourceOutcome(journal, reference, outcome, acknowledgedResource = null, absenceEvidence = null) {
  const state = getState(journal);
  const current = state.resources.get(reference.resourceKey);
  requireContract(reference.journalId === state.journalId && current && ['INTENT', 'AMBIGUOUS'].includes(current.state) && ['CREATED', 'AMBIGUOUS', 'NOT_CREATED'].includes(outcome), 'INVALID_RESOURCE_ACK');
  requireContract(reference.runId === state.config.runId, 'RESOURCE_REFERENCE_RUN_MISMATCH');
  requireContract(!(current.state === 'AMBIGUOUS' && outcome === 'AMBIGUOUS'), 'DUPLICATE_AMBIGUOUS_OUTCOME');
  if (acknowledgedResource) {
    owned(acknowledgedResource, state.authorization);
    requireContract(acknowledgedResource.intentId === current.resource.intentId && acknowledgedResource.type === current.resource.type && acknowledgedResource.namespace === current.resource.namespace && acknowledgedResource.leaseId === current.resource.leaseId && (current.resource.id === null || current.resource.id === acknowledgedResource.id), 'RESOURCE_ACK_MISMATCH');
  }
  if (outcome === 'NOT_CREATED') requireContract(current.state === 'INTENT' && absenceEvidence?.neverDispatched === true, 'ABSENCE_CANNOT_BE_INFERRED');
  if (outcome === 'CREATED') requireContract((acknowledgedResource ?? current.resource).id !== null, 'EXACT_RESOURCE_ID_REQUIRED');
  append(state, { kind: 'transition', resourceKey: reference.resourceKey, state: outcome, ...(acknowledgedResource ? { resource: immutable(acknowledgedResource) } : {}) });
}
export async function cleanupOwnedResources(journal, authorization) {
  const state = getState(journal);
  assertTargetAuthorization(authorization, 'cleanup', state.config.runId, digest(state.config));
  const deadline = performance.now() + state.config.deadlines.cleanupMs;
  const failures = [];
  let blocked = false;
  // Fault restoration belongs to Phase 14 and must precede ordinary deletion.
  if ([...state.resources.values()].some((item) => item.resource.type === 'fault' && item.state !== 'CLEANUP_COMPLETE')) return immutable({ status: 'BLOCKED', remaining: state.resources.size, failures: ['FAULT_RESTORATION_REQUIRED'] });
  for (const item of [...state.resources.values()].reverse()) {
    if (['CLEANUP_COMPLETE', 'NOT_CREATED'].includes(item.state)) continue;
    owned(item.resource, authorization);
    const adapter = state.cleanupAdapters[item.resource.type];
    if (item.resource.id === null || !adapter?.verifyOwnership || !adapter?.remove || !adapter?.verifyAbsent) {
      blocked = true; failures.push('EXACT_CLEANUP_PREREQUISITE_MISSING'); continue;
    }
    for (let attempt = item.retryCount; attempt < state.config.journalLimits.cleanupAttempts; attempt += 1) {
      let errorClass = null;
      try {
        assertTargetAuthorization(authorization, 'cleanup', state.config.runId, digest(state.config));
        const remainingMs = Math.floor(deadline - performance.now());
        requireContract(remainingMs > 0, 'DEADLINE_EXCEEDED');
        append(state, { kind: 'cleanupIntent', resourceKey: item.resourceKey });
        await withDeadline(async (signal) => {
          if (await adapter.verifyAbsent(immutable(item.resource), authorization, signal) === true) return;
          requireContract(!signal.aborted, 'DEADLINE_EXCEEDED');
          const evidence = await adapter.verifyOwnership(immutable(item.resource), authorization, signal);
          requireContract(evidence?.owned === true && evidence.id === item.resource.id && evidence.namespace === item.resource.namespace && evidence.ownerIdentity === item.resource.ownerIdentity && evidence.runId === item.resource.runId && evidence.environmentId === item.resource.environmentId && evidence.leaseId === item.resource.leaseId, 'INDEPENDENT_OWNERSHIP_CHECK_FAILED');
          requireContract(item.resource.path === null || evidence.path === item.resource.path, 'INDEPENDENT_OWNERSHIP_CHECK_FAILED');
          requireContract(!signal.aborted, 'DEADLINE_EXCEEDED');
          assertTargetAuthorization(authorization, 'cleanup', state.config.runId, digest(state.config));
          await adapter.remove(immutable(item.resource), authorization, signal);
          requireContract(!signal.aborted, 'DEADLINE_EXCEEDED');
          requireContract(await adapter.verifyAbsent(immutable(item.resource), authorization, signal) === true, 'CLEANUP_NOT_VERIFIED');
        }, Math.min(remainingMs, state.config.deadlines.operationMs));
      } catch (error) { errorClass = error instanceof HarnessError ? error.code : 'CLEANUP_ADAPTER_ERROR'; }
      append(state, { kind: 'transition', resourceKey: item.resourceKey, state: errorClass ? 'CLEANUP_FAILED' : 'CLEANUP_COMPLETE', ...(errorClass ? { errorClass } : {}) });
      if (!errorClass) break;
      failures.push(errorClass);
      // No retry while prior work may still be running or ownership is uncertain.
      if (['DEADLINE_EXCEEDED', 'INDEPENDENT_OWNERSHIP_CHECK_FAILED', 'TARGET_AUTHORIZATION_REQUIRED'].includes(errorClass)) break;
    }
  }
  const remaining = [...state.resources.values()].filter((item) => !['CLEANUP_COMPLETE', 'NOT_CREATED'].includes(item.state)).length;
  return immutable({ status: remaining ? (blocked ? 'BLOCKED' : 'FAILED') : 'COMPLETE', remaining, failures: [...new Set(failures)] });
}
export async function withOwnedResources(journal, authorization, operation) {
  const state = getState(journal);
  assertTargetAuthorization(authorization, 'create', state.config.runId, digest(state.config));
  requireContract(typeof operation === 'function', 'OWNED_OPERATION_REQUIRED');
  let value;
  let primaryFailure = null;
  let cleanup;
  try { value = await operation(); }
  catch (error) { primaryFailure = error instanceof HarnessError ? error.code : 'OWNED_OPERATION_ERROR'; }
  finally {
    try {
      cleanup = ['DEADLINE_EXCEEDED', 'ABORTED'].includes(primaryFailure)
        ? immutable({ status: 'BLOCKED', remaining: journal.snapshot().resources.filter((item) => !['CLEANUP_COMPLETE', 'NOT_CREATED'].includes(item.state)).length, failures: ['WORKER_QUIESCENCE_REQUIRED'] })
        : await cleanupOwnedResources(journal, authorization);
    }
    catch { cleanup = immutable({ status: 'FAILED', remaining: journal.snapshot().resources.filter((item) => !['CLEANUP_COMPLETE', 'NOT_CREATED'].includes(item.state)).length, failures: ['CLEANUP_JOURNAL_ERROR'] }); }
    try { journal.close(); }
    catch { cleanup = immutable({ ...cleanup, status: 'FAILED', failures: [...new Set([...cleanup.failures, 'JOURNAL_CLOSE_ERROR'])] }); }
  }
  if (primaryFailure || cleanup.status !== 'COMPLETE') {
    const error = new HarnessError(primaryFailure ? 'OWNED_OPERATION_FAILED' : 'OWNED_CLEANUP_FAILED');
    error.primaryFailure = primaryFailure;
    error.cleanup = cleanup;
    throw error;
  }
  return Object.freeze({ value, cleanup });
}
