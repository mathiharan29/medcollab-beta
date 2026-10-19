// Publish a sanitized text-only copy; retain raw local evidence for the original gates.
import { readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import { resolve, join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sanitize } from './report.mjs';

export async function stage(source, destination) {
  source = resolve(source); destination = resolve(destination);
  if (source === destination || destination.startsWith(source + sep) || source.startsWith(destination + sep)) throw new Error('Staging must be separate from the evidence directory');
  await mkdir(destination, { recursive: true });
  const files = [];
  async function walk(directory) {
    for (const e of await readdir(directory, { withFileTypes: true }).catch(() => [])) {
      if (['node_modules', 'runtime', 'target', 'mongo-binaries', '.git'].includes(e.name) || e.isSymbolicLink()) continue;
      const from = join(directory, e.name);
      if (e.isDirectory()) { await walk(from); continue; }
      if (!/\.(?:json|xml|md|html|log|txt|ndjson|ndjsonl)$/.test(e.name)) continue;
      const rel = relative(source, from), to = join(destination, rel);
      const raw = await readFile(from, 'utf8');
      let clean;
      if (e.name.endsWith('.html')) {
        if (e.name !== 'vocle-regression-dashboard.html') continue;
        clean = raw; // Shared generator has already sanitized JSON and escaped markup.
      }
      else if (e.name.endsWith('.json')) {
        try { clean = JSON.stringify(sanitize(JSON.parse(raw)), null, 2) + '\n'; }
        catch { clean = sanitize(raw); }
      } else clean = sanitize(raw);
      await mkdir(resolve(to, '..'), { recursive: true });
      await writeFile(to, clean); files.push(rel.replaceAll('\\','/'));
    }
  }
  await walk(source);
  await writeFile(join(destination, 'report-publication.json'), JSON.stringify({ schemaVersion: 1, sanitizedTextCopy: true, excluded: ['runtime', 'target', 'node_modules', 'mongo-binaries', 'symlinks', 'binary files'], files }, null, 2) + '\n');
  return files;
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [source, destination] = process.argv.slice(2);
  if (!source || !destination) throw new Error('Usage: stage.mjs EVIDENCE_DIR PUBLICATION_DIR');
  console.log(JSON.stringify({ sanitizedFiles: (await stage(source, destination)).length }));
}
