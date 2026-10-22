import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = resolve(fileURLToPath(new URL('../../../', import.meta.url)));
const roots = [
  'tests/functional-regression', 'tests/sanity', 'tests/reporting', 'tests/developer-workflow',
  'medcollab-app/test/functional_regression', 'medcollab-app/integration_test/functional_regression',
  'medcollab-app/test_driver/functional_regression_driver.dart',
  'medcollab-backend/scripts/security', 'medcollab-backend/scripts/security-media',
  'medcollab-backend/scripts/security-data', 'medcollab-backend/scripts/security-cloudinary',
  'medcollab-backend/scripts/security-api-discovery.js', 'medcollab-backend/scripts/security-api-coverage-report.js',
  'medcollab-backend/scripts/security-manifest-check.js', 'medcollab-backend/scripts/security-test-fixtures.js',
  'medcollab-backend/scripts/security-test-auth-smoke.js', 'medcollab-backend/package-lock.json',
  'scripts/test_vocle.py', 'scripts/vocle_bootstrap.py', 'scripts/vocle_android.py', 'scripts/vocle-runtime-lock.json',
  '.github/workflows',
];
async function files(path) {
  const entries = await readdir(path, { withFileTypes: true });
  const found = [];
  for (const entry of entries) {
    if (['node_modules', 'output', '.gitignore', 'catalog-validation.json'].includes(entry.name)) continue;
    const full = join(path, entry.name);
    if (entry.isDirectory()) found.push(...await files(full));
    else if (entry.isFile()) found.push(full);
  }
  return found;
}
const paths = (await Promise.all(roots.map(async (root) => /\.(?:yml|js|mjs|py|json|dart)$/.test(root) ? [join(repo, root)] : files(join(repo, root))))).flat().sort();
const hash = createHash('sha256');
for (const path of paths) {
  hash.update(`${relative(repo, path).replaceAll('\\', '/')}\0`);
  hash.update(await readFile(path));
  hash.update('\0');
}
console.log(hash.digest('hex'));
