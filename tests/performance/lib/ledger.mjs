import contract from '../config/contract.json' with { type: 'json' };
import contextSchema from '../schemas/stage-context.schema.json' with { type: 'json' };
import { assertSchema, canonical, finiteInteger, identifier, immutable, requireContract } from './core.mjs';
const handles = new WeakSet();

export function createActionLedger({ runId, caseIds, operationIds, clockDomainId, limits }) {
  requireContract(identifier(runId) && identifier(clockDomainId) && [limits.maxActions, limits.maxStages, limits.maxBytes].every((value) => finiteInteger(value, 1)), 'INVALID_LEDGER_CONFIG');
  const actions = new Map();
  const lastTimes = new Map();
  let sequence = 0;
  let byteCount = 0;
  function capacity(value, stages = 0) {
    const bytes = Buffer.byteLength(canonical(value));
    requireContract(byteCount + bytes <= limits.maxBytes && sequence + stages <= limits.maxStages, 'LEDGER_LIMIT');
    byteCount += bytes;
  }
  function action(id) { const item = actions.get(id); requireContract(item, 'UNKNOWN_ACTION'); return item; }
  function stage(actionId, name, monotonicTime, context) {
    const item = action(actionId);
    requireContract(contract.stageNames.includes(name) && Number.isFinite(monotonicTime) && monotonicTime >= 0, 'INVALID_STAGE');
    const metadata = immutable(context);
    assertSchema(metadata, contextSchema);
    requireContract(identifier(metadata.clockDomainId) && identifier(metadata.attemptId), 'STAGE_CLOCK_ATTEMPT_REQUIRED');
    const clockKey = `${metadata.attemptId}/${metadata.clockDomainId}`;
    const previousTime = lastTimes.get(actionId).get(clockKey);
    requireContract(previousTime === undefined || monotonicTime >= previousTime, 'NONMONOTONIC_STAGE');
    if (name === 'received') requireContract(metadata.messageId && metadata.actorDeviceId && metadata.eventCopyId, 'DELIVERY_CORRELATION_REQUIRED');
    if (['accepted', 'persisted'].includes(name)) requireContract(metadata.messageId, 'PERSISTENCE_CORRELATION_REQUIRED');
    const event = immutable({ sequence, stage: name, monotonicTime, context: metadata });
    capacity(event, 1);
    item.stages.push(event);
    lastTimes.get(actionId).set(clockKey, monotonicTime);
    sequence += 1;
    return event;
  }
  function delivery(item) {
    const receipts = item.stages.filter((event) => event.stage === 'received');
    const persistedIds = [...new Set(item.stages.filter((event) => event.stage === 'persisted').map((event) => event.context.messageId))];
    const received = new Set(receipts.filter((event) => persistedIds.includes(event.context.messageId)).map((event) => event.context.actorDeviceId));
    const expected = item.expectedAudience;
    return {
      persistedIds, copies: receipts.length,
      uniqueReceipts: [...new Set(receipts.map((event) => `${event.context.messageId}/${event.context.actorDeviceId}`))].length,
      missingDevices: expected === null ? null : expected.filter((id) => !received.has(id)),
      unexpectedDevices: expected === null ? null : [...received].filter((id) => !expected.includes(id)),
      uncorrelatedCopies: receipts.filter((event) => !persistedIds.includes(event.context.messageId)).length,
    };
  }
  // Functions are bound to this run's ledger; no global singleton/cross-run state.
  const ledger = Object.freeze({
    runId,
    clockDomainId,
    beginAction({ actionId, caseId, variant, operationId, scheduledTime }) {
      requireContract(identifier(actionId) && identifier(variant) && caseIds.includes(caseId) && operationIds.includes(operationId) && !actions.has(actionId) && actions.size < limits.maxActions, 'INVALID_ACTION');
      const item = { actionId, caseId, variant, operationId, expectedAudience: null, stages: [], outcome: null };
      capacity(item);
      actions.set(actionId, item);
      lastTimes.set(actionId, new Map());
      stage(actionId, 'scheduled', scheduledTime, { clockDomainId, attemptId: 'initial' });
    },
    expectAudience(actionId, actorDeviceIds) {
      const item = action(actionId);
      requireContract(item.expectedAudience === null && Array.isArray(actorDeviceIds) && actorDeviceIds.every(identifier) && new Set(actorDeviceIds).size === actorDeviceIds.length && actorDeviceIds.length <= limits.maxStages, 'INVALID_AUDIENCE');
      capacity(actorDeviceIds);
      item.expectedAudience = immutable(actorDeviceIds);
    },
    recordStage: stage,
    recordOutcome(actionId, outcome) {
      const item = action(actionId);
      const record = immutable(outcome);
      requireContract(!item.outcome && contract.outcomes.includes(record.state) && Object.keys(record).every((key) => ['state', 'errorClass'].includes(key)) && (!record.errorClass || identifier(record.errorClass)), 'INVALID_OUTCOME');
      if (record.state === 'success') {
        const accounting = delivery(item);
        requireContract(item.stages.some((event) => event.stage === 'reconciled' && event.context.result === 'PASSED') && (item.expectedAudience === null || (accounting.missingDevices.length === 0 && accounting.unexpectedDevices.length === 0 && accounting.uncorrelatedCopies === 0)), 'SUCCESS_REQUIRES_RECONCILIATION');
      }
      capacity(record);
      item.outcome = record;
    },
    snapshot() {
      return immutable({
        schemaVersion: 1, runId, clockDomainId, stages: sequence, bytes: byteCount,
        actions: [...actions.values()].map((item) => ({ ...item, outcome: item.outcome ?? { state: 'unfinished' }, delivery: delivery(item) })),
        counts: Object.fromEntries(contract.outcomes.map((state) => [state, [...actions.values()].filter((item) => (item.outcome?.state ?? 'unfinished') === state).length])),
      });
    },
  });
  handles.add(ledger);
  return ledger;
}
// Optional stateless named interfaces. Bound ledger methods use the same logic.
// The handle is removed before metadata is checked, retained or serialized.
export function recordStage(actionId, stage, monotonicTime, context) {
  const { ledger, ...metadata } = context;
  requireContract(handles.has(ledger), 'RUN_LEDGER_REQUIRED');
  return ledger.recordStage(actionId, stage, monotonicTime, metadata);
}
export function recordOutcome(actionId, outcome) {
  const { ledger, ...record } = outcome;
  requireContract(handles.has(ledger), 'RUN_LEDGER_REQUIRED');
  return ledger.recordOutcome(actionId, record);
}
