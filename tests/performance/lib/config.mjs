import { isIP } from 'node:net';
import schema from '../schemas/run-config.schema.json' with { type: 'json' };
import catalog from '../catalog.json' with { type: 'json' };
import contract from '../config/contract.json' with { type: 'json' };
import { assertSchema, digest, finiteInteger, immutable, requireContract } from './core.mjs';

const validated = new WeakSet();
export function validateRunConfig(raw) {
  const config = immutable(raw);
  assertSchema(config, schema);
  requireContract(config.executionAuthorized, 'EXECUTION_AUTHORIZATION_REQUIRED');
  let url;
  try { url = new URL(config.target.url); } catch { requireContract(false, 'INVALID_TARGET_URL'); }
  requireContract(['https:', 'http:'].includes(url.protocol) && !url.username && !url.password && !url.search && !url.hash && url.pathname === '/', 'UNSAFE_TARGET_URL');
  requireContract(config.target.url === url.origin && config.target.addresses.every((address) => isIP(address) > 0), 'NONCANONICAL_TARGET');
  const selected = catalog.cases.filter((entry) => config.caseIds.includes(entry.id));
  requireContract(selected.length === config.caseIds.length, 'UNKNOWN_CASE');
  const pairs = new Set();
  for (const variant of config.variants) {
    const entry = selected.find((item) => item.id === variant.caseId);
    const known = entry?.variants.find((item) => item.id === variant.id);
    requireContract(known && Array.isArray(known.requiredMetrics) && known.requiredMetrics.length > 0 && known.requiredMetrics.every((name) => contract.requiredMetricNames.includes(name)), 'UNKNOWN_VARIANT');
    requireContract(!pairs.has(`${variant.caseId}/${variant.id}`), 'DUPLICATE_VARIANT');
    pairs.add(`${variant.caseId}/${variant.id}`);
  }
  requireContract(selected.every((entry) => config.variants.some((variant) => variant.caseId === entry.id)), 'MISSING_CASE_VARIANT');
  // Dependency closure is explicit; no silent selection or execution of prerequisites.
  for (const entry of selected) for (const dependency of entry.dependencies) requireContract(config.caseIds.includes(dependency), 'MISSING_CASE_PREREQUISITE');
  const b = config.budgets;
  requireContract(b.elapsedMs <= config.deadlines.totalMs && Object.values(config.deadlines).every((limit) => limit <= config.deadlines.totalMs), 'INCONSISTENT_DEADLINES');
  requireContract(b.totalMessages <= b.totalRequests && b.concurrentUploads <= b.totalRequests, 'INCONSISTENT_WORK_BUDGETS');
  requireContract(b.maxUploadBytes <= b.bytesTransferred && b.providerCalls === Object.values(config.providers).reduce((sum, provider) => sum + provider.budget, 0), 'INCONSISTENT_BYTE_PROVIDER_BUDGETS');
  requireContract(config.limiter.measurementMode !== 'deployment-policy' || config.limiter.nodeEnv === 'production', 'LIMITER_POLICY_BYPASS');
  for (const provider of Object.values(config.providers)) {
    requireContract(!provider.egress || (config.environment.class === 'E5' && provider.mode === 'sandbox' && provider.budget > 0), 'PROVIDER_EGRESS_FORBIDDEN');
    requireContract(provider.mode !== 'sandbox' || (provider.egress && config.environment.class === 'E5'), 'SANDBOX_AUTHORIZATION_REQUIRED');
  }
  if (config.environment.class === 'E1') {
    requireContract(['B', 'C'].includes(config.workload.profile) && b.httpStartsPerSecond <= 10 && b.persistentConnections <= 20 && config.workload.syntheticAccounts <= 20 && b.maxUploadBytes <= 1048576 && Object.values(config.providers).every((provider) => !provider.egress), 'E1_CAP_EXCEEDED');
    if (config.workload.profile === 'C') requireContract(config.workload.syntheticAccounts <= 10 && b.elapsedMs <= 600000, 'RACE_CAP_EXCEEDED');
  }
  validated.add(config);
  return config;
}
export function assertValidatedConfig(config) { requireContract(validated.has(config), 'VALIDATED_CONFIG_REQUIRED'); }
export function getRequiredMetrics(config) {
  const common = contract.requiredMetricNames.filter((name) => /^(generator|sut|db)\./.test(name));
  const selected = config.variants.flatMap((variant) => catalog.cases.find((entry) => entry.id === variant.caseId)?.variants.find((item) => item.id === variant.id)?.requiredMetrics ?? []);
  return immutable([...new Set([...common, ...selected])]);
}

// Account admissions using monotonic milliseconds, independently of any scheduler.
export function createBudgetGuard(config) {
  assertValidatedConfig(config);
  const totals = Object.create(null);
  const providers = { msg91: 0, fcm: 0, cloudinary: 0 };
  const windows = new Map();
  const reservations = new Map();
  const gauges = { connections: 0, uploads: 0 };
  let reservationId = 0;
  let firstTime;
  let lastTime;
  const rates = { newConnections: 'newConnectionsPerSecond', requests: 'httpStartsPerSecond', messages: 'messageStartsPerSecond', events: 'eventStartsPerSecond' };
  const limits = { requests: 'totalRequests', messages: 'totalMessages', events: 'totalEvents', outboundDeliveries: 'outboundDeliveries', bytes: 'bytesTransferred', databaseGrowthBytes: 'databaseGrowthBytes', providerCalls: 'providerCalls' };
  function admit(kind, amount, monotonicTime) {
      requireContract((kind in limits || kind in rates) && finiteInteger(amount, 1) && Number.isFinite(monotonicTime) && monotonicTime >= 0 && (lastTime === undefined || monotonicTime >= lastTime), 'INVALID_BUDGET_ADMISSION');
      firstTime ??= monotonicTime;
      lastTime = monotonicTime;
      requireContract(monotonicTime - firstTime <= config.budgets.elapsedMs, 'ABORTED_LIMIT');
      const total = (totals[kind] ?? 0) + amount;
      requireContract(finiteInteger(total), 'BUDGET_COUNTER_OVERFLOW');
      if (limits[kind]) requireContract(total <= config.budgets[limits[kind]], 'ABORTED_LIMIT');
      if (rates[kind]) {
        const previous = (windows.get(kind) ?? []).filter((entry) => entry.at > monotonicTime - 1000);
        const count = previous.reduce((sum, entry) => sum + entry.amount, amount);
        requireContract(count <= config.budgets[rates[kind]], 'ABORTED_LIMIT');
        requireContract(previous.length < config.ledgerLimits.maxStages, 'BUDGET_WINDOW_LIMIT');
        windows.set(kind, [...previous, { at: monotonicTime, amount }]);
      }
      totals[kind] = total;
  }
  const guard = Object.freeze({
    admit(kind, amount, monotonicTime) {
      requireContract(kind !== 'providerCalls', 'USE_PROVIDER_ADMISSION');
      return admit(kind, amount, monotonicTime);
    },
    admitProvider(provider, amount, monotonicTime) {
      requireContract(Object.hasOwn(providers, provider) && finiteInteger(amount, 1) && providers[provider] + amount <= config.providers[provider].budget, 'PROVIDER_BUDGET_EXCEEDED');
      admit('providerCalls', amount, monotonicTime);
      providers[provider] += amount;
    },
    reserve(kind, amount) {
      requireContract(['connections', 'uploads'].includes(kind) && finiteInteger(amount, 1), 'INVALID_RESERVATION');
      const ceiling = config.budgets[kind === 'connections' ? 'persistentConnections' : 'concurrentUploads'];
      requireContract(gauges[kind] + amount <= ceiling && reservations.size < config.ledgerLimits.maxActions, 'ABORTED_LIMIT');
      const token = Object.freeze({ id: reservationId++ });
      reservations.set(token, { kind, amount });
      gauges[kind] += amount;
      return token;
    },
    release(token) {
      const reservation = reservations.get(token);
      requireContract(reservation, 'UNKNOWN_RESERVATION');
      gauges[reservation.kind] -= reservation.amount;
      reservations.delete(token);
    },
    observeResources(observation) {
      requireContract(['generatorMemoryBytes', 'sutMemoryBytes', 'freeDiskBytes', 'cpuPercent', 'cost'].every((key) => Number.isFinite(observation[key]) && observation[key] >= 0), 'RESOURCE_MEASUREMENT_UNAVAILABLE');
      requireContract(observation.generatorMemoryBytes <= config.budgets.generatorMemoryBytes && observation.sutMemoryBytes <= config.budgets.sutMemoryBytes && observation.freeDiskBytes >= config.budgets.diskReserveBytes && observation.cpuPercent <= config.budgets.cpuPercent && observation.cost <= config.budgets.costCeiling, 'ABORTED_LIMIT');
    },
    snapshot: () => immutable({ configHash: digest(config), totals, gauges, providers }),
  });
  return guard;
}
