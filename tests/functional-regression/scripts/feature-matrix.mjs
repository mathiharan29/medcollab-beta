import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { catalogCases } from './ci-contracts.mjs';
import { featureExecutors } from './feature-executors.mjs';
import { readFeatureRegistry, validateFeatureRegistry } from './feature-registry.mjs';
import { deviceCases } from './device-contracts.mjs';

export const matrixPath = 'docs/regression/FEATURE-REGRESSION-MATRIX.md';

export function renderFeatureMatrix(cases, features, executors) {
  const lines = [
    '# Vocle feature regression matrix', '',
    'Generated from the functional catalog, the feature registry and the existing executor declarations.',
    'To regenerate this file after updating the registry, run `node tests/functional-regression/scripts/feature-matrix.mjs` from the repository root.', '',
    '## Feature summary', '',
    '| Feature | Backend cases | Flutter cases | Security cases | Android cases | Total unique cases |',
    '|---|---:|---:|---:|---:|---:|',
  ];
  const byId = new Map(cases.map(row => [row.id, row]));
  const tags = new Map(cases.map(row => [row.id, []]));
  let assignments = 0;
  for (const { id, name, caseIds } of features.values()) {
    const selected = caseIds.map(caseId => byId.get(caseId));
    assignments += selected.length;
    for (const row of selected) tags.get(row.id).push(id);
    lines.push(`| ${name} (\`${id}\`) | ${selected.filter(row => row.tier === 'B').length} | ${selected.filter(row => row.tier === 'F').length} | 0 | ${selected.filter(row => row.tier === 'D').length} | ${selected.length} |`);
  }
  const layers = { B: 'Backend', F: 'Flutter', D: 'Android (local)' };
  lines.push(
    '', `The catalog has **${cases.length} unique cases** and **${assignments} feature assignments**. A test with several tags counts once in each feature and once in \`all\`.`,
    '', 'The Security column counts dedicated security-suite IDs. The separate API and realtime, MongoDB, offline media and Cloudinary inventories use their existing workflows. Access and privacy checks inside this functional catalog keep their backend, Flutter or Android layer.',
    '', 'See the [voice coverage audit](VOICE-COVERAGE-AUDIT.md) for the baseline evidence, new voice cases and native test steps.',
    '', '## Case assignments', '',
    '| Feature tags | Regression ID | Test description | Test layer | Executor |',
    '|---|---|---|---|---|',
  );
  for (const row of cases) {
    const path = executors.get(row.id);
    const features = tags.get(row.id);
    const audio = deviceCases[row.id]?.audio;
    const layer = audio === 'digital' ? 'Android (hosted)' : audio === 'file' ? 'Android (hosted and local)' : layers[row.tier];
    lines.push(`| ${features.join(', ')} | \`${row.id}\` | ${row.actions.replaceAll('|', '\\|')} | ${layer} | [${path.split('/').at(-1)}](../../${path}) |`);
  }
  return lines.join('\n') + '\n';
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = resolve(import.meta.dirname, '../../..');
  const cases = await catalogCases();
  const features = validateFeatureRegistry(await readFeatureRegistry(), cases);
  await mkdir(resolve(root, 'docs/regression'), { recursive: true });
  await writeFile(resolve(root, matrixPath), renderFeatureMatrix(cases, features, await featureExecutors(root, cases)));
}
