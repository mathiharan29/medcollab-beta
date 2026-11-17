import { appendFile } from 'node:fs/promises';
import { catalogCases } from './ci-contracts.mjs';
import { loadFeature } from './feature-registry.mjs';

const feature = process.argv[2] ?? process.env.VOCLE_FEATURE;
const selected = await loadFeature(feature, await catalogCases());
const counts = { backend: 0, flutter: 0, android: 0 };
const tier = { B: 'backend', F: 'flutter', D: 'android' };
for (const row of selected) counts[tier[row.tier]]++;
console.log(JSON.stringify({ feature, total: selected.length, counts, ids: selected.map(row => row.id) }, null, 2));
if (process.env.GITHUB_OUTPUT) {
  await appendFile(process.env.GITHUB_OUTPUT, Object.entries(counts).map(([key, count]) => `${key}=${count}\n`).join(''));
}
if (process.env.GITHUB_STEP_SUMMARY) {
  await appendFile(process.env.GITHUB_STEP_SUMMARY, `## Selection\n\n${feature} selects ${selected.length} cases across ${counts.backend} backend, ${counts.flutter} Flutter and ${counts.android} separately executed Android cases.\n`);
}
