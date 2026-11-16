import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { moduleForGroup, scenarioGroups } from '../../sanity/src/scenarios.js';
import { suiteFiles } from './ci-contracts.mjs';
import { deviceCases } from './device-contracts.mjs';

const backend = 'tests/functional-regression/suites';
const sanity = 'tests/sanity/src';
const flutter = 'medcollab-app/test/functional_regression';
const android = 'medcollab-app/integration_test/functional_regression';

async function registeredCases(root, directory, extension, pattern) {
  const registrations = new Map();
  const files = (await readdir(join(root, directory))).filter(name => name.endsWith(extension));
  for (const name of files) {
    const file = `${directory}/${name}`;
    const content = await readFile(join(root, file), 'utf8');
    for (const [, id] of content.matchAll(pattern)) {
      if (registrations.has(id)) throw new Error(`Duplicate executor declaration for ${id}`);
      registrations.set(id, file);
    }
  }
  return registrations;
}

export async function featureExecutors(root, cases) {
  const [backendIds, sanityIds, flutterIds, androidIds] = await Promise.all([
    registeredCases(root, backend, '.mjs', /\bid:\s*['"](FR-[A-Z]+-\d+)['"]/g),
    registeredCases(root, sanity, '-scenarios.js', /\bscenario\(\s*['"]([a-z-]+-\d+)['"]/g),
    registeredCases(root, flutter, '_test.dart', /\b(?:test|testWidgets)\(\s*r?['"](FR-[A-Z]+-\d+)\b/g),
    registeredCases(root, android, '_test.dart', /\bdeviceCase\(\s*['"](FR-[A-Z]+-\d+)['"]/g),
  ]);
  const startup = `${sanity}/live-runner.js`;
  if (sanityIds.has('startup-01') || !/\bscenario:\s*['"]startup-01['"]/.test(await readFile(join(root, startup), 'utf8'))) {
    throw new Error('Missing or duplicate retained startup executor');
  }
  sanityIds.set('startup-01', startup);
  const sanityFiles = new Map(scenarioGroups.flatMap(group =>
    group.scenarios.map(({ id }) => [id, `${sanity}/${moduleForGroup[group.id]}`]),
  ));
  const executors = new Map();
  for (const row of cases) {
    let registered, expected;
    if (row.coverage === 'EXISTING') {
      registered = sanityIds;
      expected = sanityFiles.get(row.id);
    } else if (row.tier === 'B') {
      registered = backendIds;
      expected = suiteFiles[row.module] && `${backend}/${suiteFiles[row.module]}.mjs`;
    } else if (row.tier === 'F') {
      registered = flutterIds;
      expected = registered.get(row.id);
    } else if (row.tier === 'D') {
      registered = androidIds;
      expected = deviceCases[row.id] && `${android}/${deviceCases[row.id].file}`;
    }
    if (!expected || expected !== registered.get(row.id)) throw new Error(`Missing or mismatched executor for ${row.id}`);
    executors.set(row.id, expected);
    registered.delete(row.id);
  }
  const unregistered = [...backendIds.keys(), ...sanityIds.keys(), ...flutterIds.keys(), ...androidIds.keys()];
  if (unregistered.length) throw new Error(`Executor IDs absent from the catalog: ${unregistered.join(', ')}`);
  return executors;
}
