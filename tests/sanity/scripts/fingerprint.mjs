import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { join, relative, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..', '..', '..');
const included = [join(root, 'tests', 'sanity'), join(root, 'tests', 'reporting'), join(root, '.github', 'workflows', 'vocle-sanity.yml')];

async function filesAt(path) {
  const entries = await readdir(path, { withFileTypes: true });
  const files = await Promise.all(entries.map(async (entry) => {
    const child = join(path, entry.name);
    if (entry.isDirectory()) return entry.name === 'output' || entry.name === 'node_modules' ? [] : filesAt(child);
    return [child];
  }));
  return files.flat();
}

const files = (await Promise.all(included.map(async (path) => {
  try { return (await filesAt(path)).sort(); } catch { return [path]; }
}))).flat().sort();
const hash = createHash('sha256');
for (const file of files) {
  hash.update(`${relative(root, file).replaceAll('\\', '/')}\0`);
  hash.update(await readFile(file));
  hash.update('\0');
}
process.stdout.write(`${hash.digest('hex')}\n`);
