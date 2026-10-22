import { writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { parseCatalog } from './catalog-source.mjs';

const path = fileURLToPath(new URL('../catalog.json', import.meta.url));
const cases = await parseCatalog();
await writeFile(path, `${JSON.stringify({ schemaVersion: 1, source: 'docs/VOCLE_FUNCTIONAL_REGRESSION_TEST_CATALOG.md', cases }, null, 2)}\n`);
console.log(`Wrote ${cases.length} catalog rows`);
