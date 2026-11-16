import { readFile } from 'node:fs/promises';

export function validateFeatureRegistry(registry, cases) {
  const catalog = new Map(cases.map(row => [row.id, row]));
  if (registry.schemaVersion !== 1 || !Array.isArray(registry.features) ||
      registry.catalogCount !== cases.length || catalog.size !== cases.length) {
    throw new Error('Feature registry schema or catalog count mismatch');
  }
  const features = new Map();
  const mapped = new Set();
  for (const feature of registry.features) {
    const { id, name, caseIds } = feature;
    if (typeof id !== 'string' || !/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(id) ||
        id === 'all' || features.has(id) || typeof name !== 'string' || !name.trim()) {
      throw new Error(`Invalid or duplicate feature identifier: ${id}`);
    }
    if (!Array.isArray(caseIds) || !caseIds.length || new Set(caseIds).size !== caseIds.length) {
      throw new Error(`Empty or duplicate case mapping for ${id}`);
    }
    for (const caseId of caseIds) {
      if (!catalog.has(caseId)) throw new Error(`Unknown case ${caseId} in ${id}`);
      mapped.add(caseId);
    }
    features.set(id, feature);
  }
  const unmapped = cases.filter(row => !mapped.has(row.id)).map(row => row.id);
  if (unmapped.length) throw new Error(`Unclassified catalog cases: ${unmapped.join(', ')}`);
  return features;
}

export async function readFeatureRegistry() {
  return JSON.parse(await readFile(new URL('../feature-registry.json', import.meta.url), 'utf8'));
}

export function selectFeature(features, cases, feature) {
  const entry = features.get(feature);
  if (feature !== 'all' && !entry) throw new Error(`Unknown regression feature: ${feature}`);
  const ids = new Set(entry?.caseIds ?? cases.map(row => row.id));
  if (!ids.size) throw new Error(`Empty regression feature: ${feature}`);
  return cases.filter(row => ids.has(row.id));
}

export async function loadFeature(feature, cases) {
  return selectFeature(validateFeatureRegistry(await readFeatureRegistry(), cases), cases, feature);
}
