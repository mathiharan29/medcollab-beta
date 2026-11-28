import catalog from '../catalog.json' with { type: 'json' };
import sourceMap from '../../../docs/performance/source-map.json' with { type: 'json' };
import snapshot from '../../../docs/performance/source-snapshot.json' with { type: 'json' };
import { digest, identifier, immutable, requireContract, withDeadline } from './core.mjs';
import { assertValidatedConfig } from './config.mjs';
import { assertTargetAuthorization } from './target.mjs';

const hooks = ['prepare', 'run', 'observe', 'reconcile', 'cleanup'];
const scenarios = new WeakMap();
export function defineScenario(definition) {
  const owner = catalog.cases.find((entry) => entry.id === definition.id);
  requireContract(owner && identifier(definition.variant) && owner.variants.some((variant) => (typeof variant === 'string' ? variant : variant.id) === definition.variant), 'UNREGISTERED_SCENARIO');
  requireContract(Array.isArray(definition.operationIds) && definition.operationIds.length > 0 && new Set(definition.operationIds).size === definition.operationIds.length && definition.operationIds.every((id) => sourceMap.operations.some((op) => op.id === id && op.caseIds.includes(definition.id) && !op.exclusion)), 'INVALID_SCENARIO_OPERATIONS');
  requireContract(Array.isArray(definition.sourceRefs) && definition.sourceRefs.length > 0 && definition.sourceRefs.every((ref) => snapshot.files.some((file) => file.path === ref.path) && Number.isSafeInteger(ref.line) && ref.line > 0), 'SCENARIO_SOURCES_REQUIRED');
  requireContract(Array.isArray(definition.requiredCapabilities) && definition.requiredCapabilities.every(identifier) && new Set(definition.requiredCapabilities).size === definition.requiredCapabilities.length && hooks.every((name) => typeof definition[name] === 'function'), 'SCENARIO_HOOKS_REQUIRED');
  const metadata = immutable({ id: definition.id, variant: definition.variant, operationIds: definition.operationIds, sourceRefs: definition.sourceRefs, requiredCapabilities: definition.requiredCapabilities });
  const callbacks = Object.fromEntries(hooks.map((name) => [name, definition[name]]));
  const scenario = Object.freeze({ ...metadata, ...Object.fromEntries(hooks.map((name) => [name, (ctx, prepared) => invokeScenarioHook(scenario, name, ctx, prepared)])) });
  scenarios.set(scenario, callbacks);
  return scenario;
}
export async function invokeScenarioHook(scenario, hook, ctx, prepared) {
  requireContract(scenarios.has(scenario) && hooks.includes(hook), 'UNKNOWN_SCENARIO_HOOK');
  assertValidatedConfig(ctx.config);
  requireContract(ctx.config.variants.some((item) => item.caseId === scenario.id && item.id === scenario.variant), 'SCENARIO_NOT_SELECTED');
  assertTargetAuthorization(ctx.authorization, hook === 'cleanup' ? 'cleanup' : hook === 'prepare' || hook === 'run' ? 'create' : 'observe', ctx.config.runId, digest(ctx.config));
  requireContract(Array.isArray(ctx.capabilities) && scenario.requiredCapabilities.every((name) => ctx.capabilities.includes(name)), 'BLOCKED_PREREQUISITE');
  requireContract(ctx.actors && ctx.actors.runId === ctx.config.runId && Object.isFrozen(ctx.actors) && Object.isFrozen(ctx.config) && ctx.clock && typeof ctx.clock.monotonicTime === 'function' && typeof ctx.clock.wallTime === 'function' && ctx.clock.clockDomainId === ctx.ledger?.clockDomainId && ctx.journal?.runId === ctx.config.runId && ctx.metrics && ctx.ledger?.runId === ctx.config.runId && ctx.signal, 'SCENARIO_CONTEXT_REQUIRED');
  const deadline = { prepare: 'setupMs', run: 'totalMs', observe: 'observationMs', reconcile: 'observationMs', cleanup: 'cleanupMs' }[hook];
  return withDeadline((signal) => scenarios.get(scenario)[hook](Object.freeze({ ...ctx, signal }), prepared), ctx.config.deadlines[deadline], ctx.signal);
}
// This module defines contracts, not a scheduler/supervisor. Later callers own
// bounded drain-before-reconcile, finally cleanup and independent crash recovery.
