import { openSync, closeSync, writeSync, fsyncSync, linkSync, unlinkSync, realpathSync, lstatSync } from 'node:fs';
import path from 'node:path';
import configSchema from '../schemas/run-config.schema.json' with { type: 'json' };
import reportSchema from '../reporting/schema.json' with { type: 'json' };
import ledgerSchema from '../schemas/ledger-snapshot.schema.json' with { type: 'json' };
import metricsSchema from '../schemas/metrics-snapshot.schema.json' with { type: 'json' };
import catalog from '../catalog.json' with { type: 'json' };
import { assertSchema, canonical, digest, identifier, immutable, requireContract } from './core.mjs';
import { assertValidatedConfig, getRequiredMetrics } from './config.mjs';
import { assertProvenance } from './provenance.mjs';
import { assertHistoricalAuthorization } from './target.mjs';

export const exitCodes = Object.freeze({ PASSED: 0, FAILED_FUNCTIONAL: 1, FAILED_PERFORMANCE: 2, INVALID_GENERATOR: 3, FAILED_INFRASTRUCTURE: 4, ABORTED_LIMIT: 5, BLOCKED_PREREQUISITE: 6, NOT_EXECUTED: 7, INCONCLUSIVE: 8 });
export function finalizeRun(run, oracleResults, cleanup) {
  const config = run.config;
  assertSchema(config, configSchema); // Failed semantic setup can still be reported as unexecuted.
  const started = run.startedAt !== null;
  if (started) {
    assertValidatedConfig(config);
    assertHistoricalAuthorization(run.authorization, config);
    assertProvenance(run.provenance, config);
    requireContract(Number.isSafeInteger(run.startedAt) && Number.isSafeInteger(run.endedAt) && run.endedAt >= run.startedAt, 'RUN_TIMELINE_REQUIRED');
  }
  const ledger = immutable(run.ledger);
  const metrics = immutable(run.metrics);
  const artifacts = immutable(run.artifacts);
  const oracles = immutable(oracleResults);
  const cleanupResult = immutable(cleanup);
  assertSchema(ledger, ledgerSchema);
  assertSchema(metrics, metricsSchema);
  requireContract(ledger.stages === ledger.actions.reduce((sum, action) => sum + action.stages.length, 0) && Object.entries(ledger.counts).every(([state, count]) => count === ledger.actions.filter((action) => action.outcome.state === state).length), 'LEDGER_ACCOUNTING_MISMATCH');
  requireContract(metrics.observations === metrics.series.reduce((sum, series) => sum + series.count, 0) && metrics.series.every((series) => series.buckets.length === series.boundaries.length + 1 && series.count === series.buckets.reduce((sum, count) => sum + count, 0) && series.censored + series.failed <= series.count), 'METRIC_ACCOUNTING_MISMATCH');
  const artifactIds = new Set(artifacts.map((item) => item.artifactId));
  requireContract(artifactIds.size === artifacts.length && ledger.runId === config.runId && config.caseIds.every((id) => catalog.cases.some((entry) => entry.id === id)), 'RUN_EVIDENCE_MISMATCH');
  requireContract(oracles.every((oracle) => Object.keys(oracle).every((key) => ['caseId', 'variant', 'status', 'evidenceRefs'].includes(key)) && config.variants.some((variant) => variant.caseId === oracle.caseId && variant.id === oracle.variant) && ['PASSED', 'FAILED', 'UNAVAILABLE'].includes(oracle.status) && Array.isArray(oracle.evidenceRefs) && oracle.evidenceRefs.every((id) => artifactIds.has(id))), 'INVALID_ORACLE_EVIDENCE');
  requireContract(new Set(oracles.map((item) => `${item.caseId}/${item.variant}`)).size === oracles.length, 'DUPLICATE_ORACLE');
  const requiredMetrics = getRequiredMetrics(config);
  const unavailable = requiredMetrics.some((name) => metrics.unavailable.some((item) => item.name === name) || !metrics.series.some((item) => item.name === name && item.count > 0));
  const missingOracle = config.variants.some((variant) => !oracles.some((oracle) => oracle.caseId === variant.caseId && oracle.variant === variant.id && oracle.status !== 'UNAVAILABLE' && oracle.evidenceRefs.length > 0));
  const unfinished = ledger.actions.length === 0 || ledger.actions.some((action) => action.outcome.state !== 'success' || !action.stages.some((event) => event.stage === 'started') || !action.stages.some((event) => event.stage === 'reconciled' && event.context.result === 'PASSED') || (action.delivery.missingDevices !== null && action.delivery.missingDevices.length > 0) || (action.delivery.unexpectedDevices !== null && action.delivery.unexpectedDevices.length > 0) || action.delivery.uncorrelatedCopies > 0);
  const missingVariant = config.variants.some((variant) => !ledger.actions.some((action) => action.caseId === variant.caseId && action.variant === variant.id));
  const threshold = run.thresholdEvaluation;
  const evaluated = started && config.thresholds !== null && config.baseline !== null
    && threshold?.policyRef === config.thresholds.policyRef && threshold.policyHash === config.thresholds.sha256
    && threshold.baselineArtifactId === config.baseline.artifactId && threshold.baselineSha256 === config.baseline.sha256
    && artifacts.some((item) => item.artifactId === config.baseline.artifactId && item.sha256 === config.baseline.sha256)
    && artifacts.some((item) => item.artifactId === config.thresholds.policyRef && item.sha256 === config.thresholds.sha256)
    && typeof threshold.passed === 'boolean' && Array.isArray(threshold.evidenceRefs) && threshold.evidenceRefs.length > 0 && threshold.evidenceRefs.every((id) => artifactIds.has(id));
  const primaryFailures = immutable(run.primaryFailures);
  requireContract(Array.isArray(primaryFailures) && primaryFailures.every(identifier), 'REDACTED_ERROR_CLASSES_REQUIRED');
  requireContract(!started || (run.budgetAccounting && run.budgetAccounting.configHash === digest(config)), 'BUDGET_ACCOUNTING_REQUIRED');
  if (run.budgetAccounting) assertSchema(run.budgetAccounting, reportSchema.properties.budgetAccounting);
  const accounting = run.budgetAccounting;
  const totalLimits = { requests: 'totalRequests', messages: 'totalMessages', events: 'totalEvents', outboundDeliveries: 'outboundDeliveries', bytes: 'bytesTransferred', databaseGrowthBytes: 'databaseGrowthBytes', providerCalls: 'providerCalls' };
  const budgetOverrun = accounting && (Object.entries(totalLimits).some(([name, ceiling]) => (accounting.totals[name] ?? 0) > config.budgets[ceiling]) || Object.entries(accounting.providers).some(([name, count]) => count > config.providers[name].budget));
  const outstandingReservations = accounting && (accounting.gauges.connections > 0 || accounting.gauges.uploads > 0);
  let status = 'INCONCLUSIVE';
  const reasonCodes = [];
  if (!started) { status = 'NOT_EXECUTED'; reasonCodes.push('RUNTIME_NOT_EXECUTED'); }
  else if (run.abortReason === 'limit' || budgetOverrun) { status = 'ABORTED_LIMIT'; reasonCodes.push('BUDGET_LIMIT'); }
  else if (run.abortReason === 'cancelled') { status = 'ABORTED_LIMIT'; reasonCodes.push('CANCELLED'); }
  else if (run.endedAt > run.authorization.expiresAt) { status = 'ABORTED_LIMIT'; reasonCodes.push('LEASE_EXPIRED'); }
  else if (run.prerequisitesComplete !== true || config.caseIds.some((id) => catalog.cases.find((entry) => entry.id === id).implementation !== 'IMPLEMENTED')) { status = 'BLOCKED_PREREQUISITE'; reasonCodes.push('MISSING_PREREQUISITE'); }
  else if (primaryFailures.length > 0 || outstandingReservations || cleanupResult.status !== 'COMPLETE' || cleanupResult.remaining !== 0 || run.infrastructureValid !== true || run.provenance.runtime.artillery === null || run.provenance.runtime.socketIOClient === null) { status = 'FAILED_INFRASTRUCTURE'; reasonCodes.push('INFRASTRUCTURE_OR_CLEANUP_FAILURE'); }
  else if (run.generatorValid !== true) { status = 'INVALID_GENERATOR'; reasonCodes.push('GENERATOR_NOT_VALIDATED'); }
  else if (oracles.some((oracle) => oracle.status === 'FAILED')) { status = 'FAILED_FUNCTIONAL'; reasonCodes.push('ORACLE_FAILURE'); }
  else if (missingOracle || missingVariant || unavailable || unfinished) reasonCodes.push('INCOMPLETE_REQUIRED_EVIDENCE');
  else if (!evaluated) reasonCodes.push(config.thresholds ? 'BASELINE_REQUIRED' : 'PRODUCT_DECISION_REQUIRED');
  else status = threshold.passed ? 'PASSED' : 'FAILED_PERFORMANCE';
  const cases = config.variants.map((variant) => {
    const oracle = oracles.find((item) => item.caseId === variant.caseId && item.variant === variant.id);
    const original = catalog.cases.find((entry) => entry.id === variant.caseId);
    return { caseId: variant.caseId, variant: variant.id, implementation: original.implementation, review: original.review, execution: status, threshold: evaluated ? 'EVALUATED' : config.thresholds ? 'BASELINE_REQUIRED' : 'PRODUCT_DECISION_REQUIRED', functional: started && oracle?.evidenceRefs.length ? oracle.status === 'FAILED' ? 'FAILED' : oracle.status === 'PASSED' ? 'PASSED' : 'NOT_EVALUATED' : 'NOT_EVALUATED', reasonCodes };
  });
  const envelope = { schemaVersion: 1, runId: config.runId, sourceSha: config.sourceSha, harnessSha: config.harnessSha, environmentId: config.environment.id, provenance: run.provenance ?? null, configHash: digest(config), configuration: config, budgetAccounting: run.budgetAccounting ?? null, requiredMetricNames: requiredMetrics, startedAt: run.startedAt, endedAt: run.endedAt, status, exitCode: exitCodes[status], cases, ledger, metrics, oracles, primaryFailures, cleanup: cleanupResult, artifacts, reasonCodes };
  const result = immutable({ ...envelope, digest: digest(envelope) });
  assertSchema(result, reportSchema);
  return result;
}
export function writeRunReport(directory, result) {
  assertSchema(result, reportSchema);
  const { digest: hash, ...fields } = result;
  requireContract(hash === digest(fields) && identifier(result.runId), 'REPORT_INTEGRITY_FAILURE');
  const root = realpathSync(directory);
  requireContract(path.isAbsolute(directory) && !lstatSync(directory).isSymbolicLink(), 'UNSAFE_REPORT_DIRECTORY');
  const filename = path.join(root, `${digest({ runId: result.runId })}-${hash}.json`);
  const temporary = `${filename}.tmp`;
  const fd = openSync(temporary, 'wx', 0o600);
  try {
    const bytes = Buffer.from(canonical(result) + '\n');
    let offset = 0;
    while (offset < bytes.length) { const count = writeSync(fd, bytes, offset, bytes.length - offset); requireContract(count > 0, 'REPORT_SHORT_WRITE'); offset += count; }
    fsyncSync(fd);
  } finally { closeSync(fd); }
  linkSync(temporary, filename); // Atomic publication, refuses to replace an existing report.
  unlinkSync(temporary);
  return filename;
}
