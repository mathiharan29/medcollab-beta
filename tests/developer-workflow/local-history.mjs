import { readdir, readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { compareEvidence, verifyEvidence, comparisonProblem } from './evidence.mjs';

// Results are discovered only under the caller's repository result root.
export async function localComparison({ currentDirectory, resultRoot, previousDirectory, output }) {
  let result = { available: false, status: 'UNAVAILABLE', reason: 'No completed compatible execution in the same context' };
  try {
    const current = await verifyEvidence(currentDirectory);
    const candidates = [];
    async function visit(directory, depth = 0) {
      if (depth > 5 || resolve(directory) === resolve(currentDirectory)) return;
      const entries = await readdir(directory, { withFileTypes: true }).catch(() => []);
      if (entries.some(e => e.name === 'manifest.json')) {
        try {
          const r = JSON.parse(await readFile(join(directory, 'results.json'), 'utf8'));
          if (r.execution?.completed) candidates.push({ directory, timestamp: r.execution.completedAt });
        } catch { /* corrupt candidates are unavailable, never current evidence */ }
      }
      for (const e of entries) if (e.isDirectory() && !['node_modules', 'detailed', 'comparison', 'diagnostics', 'runtime', '.git'].includes(e.name)) await visit(join(directory, e.name), depth + 1);
    }
    if (previousDirectory) candidates.push({ directory: previousDirectory, timestamp: '' });
    else await visit(resultRoot);
    candidates.sort((a, b) => String(b.timestamp).localeCompare(String(a.timestamp)));
    for (const candidate of candidates) {
      try {
        const previous = await verifyEvidence(candidate.directory);
        const reason = comparisonProblem(previous, current);
        if (reason) { result.reason = reason; continue; }
        result = { ...await compareEvidence(candidate.directory, currentDirectory, output), status: 'AVAILABLE', previousDirectory: candidate.directory };
        break;
      } catch (error) { result.reason = 'Previous evidence unavailable: ' + error.message; }
    }
  } catch (error) { result.reason = 'Comparison unavailable: ' + error.message; }
  await mkdir(output, { recursive: true });
  await writeFile(join(output, 'comparison.json'), JSON.stringify(result, null, 2) + '\n');
  if (!result.available) await writeFile(join(output, 'comparison.md'), `historical comparison: UNAVAILABLE\nreason: ${result.reason}\n`);
  // Optional enrichment never changes the current execution's exit status.
  return result;
}
