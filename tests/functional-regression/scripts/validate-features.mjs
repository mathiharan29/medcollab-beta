import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { featureExecutors } from './feature-executors.mjs';
import { matrixPath, renderFeatureMatrix } from './feature-matrix.mjs';
import { readFeatureRegistry, validateFeatureRegistry } from './feature-registry.mjs';

export const workflowPath = '.github/workflows/vocle-feature-regression.yml';

export function validateFeatureDropdown(workflow, features) {
  const source = workflow.replaceAll('\r\n', '\n');
  if (!source.startsWith('name: Vocle — Feature Regression\n')) throw new Error('Invalid feature workflow name');
  const triggers = source.match(/^on:\n((?:[ \t].*\n)*)/m)?.[1];
  if (!triggers || !triggers.startsWith('  workflow_dispatch:\n    inputs:\n      feature:\n') ||
      [...triggers.matchAll(/^  [a-z_]+:/gm)].length !== 1 || !/^        type: choice$/m.test(triggers) ||
      !/^        default: all$/m.test(triggers)) {
    throw new Error('Feature workflow must use the manual feature choice');
  }
  const optionBlock = triggers.match(/^        options:\n((?: {10}.*\n)+)/m)?.[1];
  const expected = ['all', ...features.keys()].map(id => `          - ${id}\n`).join('');
  if (optionBlock !== expected) throw new Error('Feature workflow dropdown is out of sync with the registry');
}

export async function validateFeatures(root, cases) {
  const features = validateFeatureRegistry(await readFeatureRegistry(), cases);
  const [workflow, matrix, executors] = await Promise.all([
    readFile(resolve(root, workflowPath), 'utf8'),
    readFile(resolve(root, matrixPath), 'utf8'),
    featureExecutors(root, cases),
  ]);
  validateFeatureDropdown(workflow, features);
  if (matrix.replaceAll('\r\n', '\n') !== renderFeatureMatrix(cases, features, executors)) {
    throw new Error('Feature matrix is out of date. Run scripts/feature-matrix.mjs');
  }
}
