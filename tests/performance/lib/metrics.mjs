import contract from '../config/contract.json' with { type: 'json' };
import catalog from '../catalog.json' with { type: 'json' };
import sourceMap from '../../../docs/performance/source-map.json' with { type: 'json' };
import { canonical, finiteInteger, identifier, immutable, requireContract, sameSet } from './core.mjs';

const labelNames = ['caseId', 'variant', 'method', 'routeTemplate', 'event', 'stage', 'statusClass', 'worker'];
function knownLabel(name, value) {
  const choices = {
    caseId: catalog.cases.map((item) => item.id),
    variant: catalog.cases.flatMap((item) => item.variants.map((variant) => variant.id)),
    method: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'STATIC'],
    routeTemplate: sourceMap.operations.filter((item) => item.path && !item.exclusion).map((item) => item.path),
    event: sourceMap.operations.filter((item) => item.event).flatMap((item) => item.event.split('/')),
    stage: contract.stageNames,
    statusClass: ['1xx', '2xx', '3xx', '4xx', '5xx', 'timeout', 'network-error'],
  };
  return name === 'worker' ? /^worker-\d{1,6}$/.test(value) : choices[name]?.includes(value);
}
export function createMetrics({ definitions, maxSeries, maxObservations }) {
  requireContract(finiteInteger(maxSeries, 1, 100000) && finiteInteger(maxObservations, 1), 'INVALID_METRIC_LIMITS');
  const schema = immutable(definitions);
  requireContract(schema.length <= maxSeries && new Set(schema.map((item) => item.name)).size === schema.length, 'DUPLICATE_METRIC_DEFINITION');
  for (const definition of schema) {
    requireContract(identifier(definition.name) && ['milliseconds', 'bytes', 'per-second', 'count', 'percent'].includes(definition.unit) && definition.boundaries.length <= 256 && definition.boundaries.every((value, index) => Number.isFinite(value) && value >= 0 && (!index || value > definition.boundaries[index - 1])), 'INVALID_HISTOGRAM_LAYOUT');
    requireContract(definition.labels && Object.keys(definition.labels).every((name) => labelNames.includes(name)) && Object.values(definition.labels).every((values) => Array.isArray(values) && values.length <= maxSeries && values.every((value) => typeof value === 'string' && value.length <= 256)), 'UNBOUNDED_METRIC_LABELS');
    requireContract(Object.entries(definition.labels).every(([name, values]) => values.every((value) => knownLabel(name, value))), 'NONCATALOG_METRIC_LABEL');
  }
  const series = new Map();
  const definitionsByName = new Map(schema.map((item) => [item.name, item]));
  const unavailable = new Map(contract.requiredMetricNames.map((name) => [name, 'NOT_OBSERVED']));
  let observations = 0;
  return Object.freeze({
    observe(name, value, labels, outcome = 'completed') {
      const definition = definitionsByName.get(name);
      requireContract(definition && Number.isFinite(value) && value >= 0 && ['completed', 'censored', 'failed'].includes(outcome), 'INVALID_METRIC_OBSERVATION');
      requireContract(sameSet(Object.keys(labels), Object.keys(definition.labels)) && Object.entries(labels).every(([key, label]) => definition.labels[key].includes(label)), 'UNKNOWN_METRIC_LABEL');
      requireContract(observations < maxObservations, 'METRIC_OBSERVATION_LIMIT');
      const key = canonical({ name, labels });
      let item = series.get(key);
      if (!item) {
        requireContract(series.size < maxSeries, 'METRIC_SERIES_LIMIT');
        item = { name, unit: definition.unit, labels: immutable(labels), boundaries: definition.boundaries, buckets: Array(definition.boundaries.length + 1).fill(0), count: 0, sum: 0, censored: 0, failed: 0 };
        series.set(key, item);
      }
      const index = definition.boundaries.findIndex((boundary) => value <= boundary);
      item.buckets[index < 0 ? definition.boundaries.length : index] += 1;
      item.count += 1;
      item.sum += value;
      requireContract(Number.isFinite(item.sum), 'METRIC_SUM_OVERFLOW');
      if (outcome === 'censored') item.censored += 1;
      if (outcome === 'failed') item.failed += 1;
      observations += 1;
      unavailable.delete(name);
    },
    markUnavailable(name, reasonCode) {
      requireContract(contract.requiredMetricNames.includes(name) && identifier(reasonCode) && ![...series.values()].some((item) => item.name === name), 'INVALID_UNAVAILABLE_METRIC');
      unavailable.set(name, reasonCode);
    },
    snapshot: () => immutable({ schemaVersion: 1, series: [...series.values()], unavailable: [...unavailable].map(([name, reasonCode]) => ({ name, availability: 'UNAVAILABLE', value: null, reasonCode })), observations }),
  });
}
export function mergeHistograms(histograms) {
  requireContract(Array.isArray(histograms) && histograms.length > 0 && histograms.length <= 10000, 'INVALID_HISTOGRAM_MERGE');
  const first = histograms[0];
  const merged = { name: first.name, unit: first.unit, labels: first.labels, boundaries: first.boundaries, buckets: Array(first.boundaries.length + 1).fill(0), count: 0, sum: 0, censored: 0, failed: 0 };
  for (const item of histograms) {
    requireContract(canonical([item.name, item.unit, item.labels, item.boundaries]) === canonical([first.name, first.unit, first.labels, first.boundaries]) && item.buckets.length === merged.buckets.length && item.buckets.every((count) => finiteInteger(count)) && item.count === item.buckets.reduce((sum, count) => sum + count, 0) && finiteInteger(item.censored) && finiteInteger(item.failed) && item.censored + item.failed <= item.count && Number.isFinite(item.sum), 'INCOMPATIBLE_HISTOGRAM');
    merged.buckets = merged.buckets.map((count, index) => count + item.buckets[index]);
    for (const field of ['count', 'sum', 'censored', 'failed']) merged[field] += item[field];
  }
  requireContract(merged.buckets.every((value) => finiteInteger(value)) && finiteInteger(merged.count) && Number.isFinite(merged.sum), 'HISTOGRAM_OVERFLOW');
  return immutable(merged);
}
