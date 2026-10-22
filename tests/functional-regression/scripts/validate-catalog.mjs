import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseCatalog, moduleNames } from './catalog-source.mjs';
import { scenarios } from '../../../tests/sanity/src/scenarios.js';

const root = resolve(fileURLToPath(new URL('../../../', import.meta.url)));
const path = resolve(root, 'tests/functional-regression/catalog.json');
const stored = JSON.parse(await readFile(path, 'utf8'));
const parsed = await parseCatalog();
const issues = [];
const expect = (condition, message) => { if (!condition) issues.push(message); };
const ids = stored.cases.map((row) => row.id);
const byId = new Map(stored.cases.map((row) => [row.id, row]));
const count = (predicate) => stored.cases.filter(predicate).length;
const moduleTotals = { AUTH: 13, PRO: 6, DISC: 4, SPC: 11, CH: 8, REQ: 9, DM: 14, MSG: 13, THR: 6, SOC: 7, HOF: 18, MED: 11, NOT: 9, PUSH: 6, RT: 10, SRCH: 6, SUP: 5, NAV: 5, OFF: 6, SAVE: 3, HOME: 3, LINK: 4, RUN: 4, JRN: 6 };

expect(stored.schemaVersion === 1, 'Unsupported schemaVersion');
expect(stored.cases.length === 187, `Expected 187 cases; found ${stored.cases.length}`);
expect(new Set(ids).size === ids.length, 'Duplicate catalog IDs');
expect(count((row) => row.coverage === 'EXISTING') === 48, 'Expected 48 retained sanity cases');
expect(count((row) => row.coverage === 'NEW') === 139, 'Expected 139 new cases');
for (const [tier, expected] of Object.entries({ B: 147, F: 32, D: 8 })) expect(count((row) => row.tier === tier) === expected, `${tier} tier count mismatch`);
for (const [priority, expected] of Object.entries({ P0: 96, P1: 81, P2: 10 })) expect(count((row) => row.priority === priority) === expected, `${priority} priority count mismatch`);
for (const [module, expected] of Object.entries(moduleTotals)) expect(count((row) => row.module === module) === expected, `${module} module count mismatch`);
expect(Object.keys(moduleNames).length === Object.keys(moduleTotals).length, 'Module mapping count mismatch');

const sanityIds = new Set(scenarios.map((scenario) => scenario.id));
expect(sanityIds.size === 48, 'Source sanity registry no longer contains 48 unique IDs');
for (const id of sanityIds) expect(byId.get(id)?.coverage === 'EXISTING', `Retained sanity ID missing: ${id}`);
for (const row of stored.cases) {
  expect(['B', 'F', 'D'].includes(row.tier), `${row.id}: invalid tier`);
  expect(['P0', 'P1', 'P2'].includes(row.priority), `${row.id}: invalid priority`);
  expect(row.moduleName === moduleNames[row.module], `${row.id}: incorrect module assignment`);
  expect(typeof row.actions === 'string' && row.actions.length > 0 && typeof row.expected === 'string' && row.expected.length > 0, `${row.id}: missing behavior text`);
  expect(typeof row.sourceReference === 'string' && row.sourceReference.length > 0, `${row.id}: missing source anchor`);
  expect(['U', 'C', 'H', 'N', 'M', 'F0', 'D0'].includes(row.fixtureProfile), `${row.id}: invalid fixture profile`);
  expect(Array.isArray(row.dependencies) && Array.isArray(row.relatedSanityIds) && Array.isArray(row.questionIds), `${row.id}: invalid references`);
  for (const dep of row.dependencies || []) expect(dep !== row.id && byId.has(dep), `${row.id}: invalid dependency ${dep}`);
  for (const related of row.relatedSanityIds || []) expect(sanityIds.has(related), `${row.id}: invalid related sanity ID ${related}`);
  for (const question of row.questionIds || []) expect(/^Q(?:1[0-4]|[1-9])$/.test(question), `${row.id}: invalid question ${question}`);
  if (row.coverage === 'EXISTING') expect(row.tier === 'B' && row.priority === 'P0' && sanityIds.has(row.id), `${row.id}: retained sanity classification changed`);
  if (row.coverage === 'NEW') expect(/^FR-[A-Z]+-\d{2}$/.test(row.id), `${row.id}: invalid new ID`);
}
expect(JSON.stringify(stored.cases) === JSON.stringify(parsed), 'Registry differs from source catalog; regenerate and review changes');

const ledger = await readFile(resolve(root, 'tests/functional-regression/contracts/decisions.md'), 'utf8');
for (let number = 1; number <= 14; number++) expect(ledger.includes(`| Q${number} |`), `Missing Q${number} ledger row`);
const result = {
  status: issues.length ? 'FAIL' : 'PASS',
  counts: { total: stored.cases.length, retained: count((row) => row.coverage === 'EXISTING'), new: count((row) => row.coverage === 'NEW'), backend: count((row) => row.tier === 'B'), flutter: count((row) => row.tier === 'F'), device: count((row) => row.tier === 'D') },
  issues,
};
if (process.argv[2] === '--report' && process.argv[3]) await writeFile(resolve(process.argv[3]), `${JSON.stringify(result, null, 2)}\n`);
console.log(JSON.stringify(result, null, 2));
if (issues.length) process.exitCode = 1;
