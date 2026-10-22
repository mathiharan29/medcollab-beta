import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { verifyEvidence, gate } from './evidence.mjs';

export function validateSubmission(report, candidateSha, catalog) {
  if (!/^[a-f0-9]{40}$/.test(candidateSha || '') || report.source.sha !== candidateSha || report.source.kind !== 'commit') throw new Error('Submission must identify the exact clean candidate SHA');
  if (report.scope !== 'full' || report.integrity !== 'PASS' || gate(report.results) !== 'PASS') throw new Error('Full required local coverage and integrity must pass');
  for (const c of catalog) {
    const row = report.results.find(r => r.id === c.id);
    if (!row) throw new Error('Catalog testcase omitted: ' + c.id);
    if (['B', 'F'].includes(c.tier) && (!row.required || !row.executed || row.status !== 'PASS')) throw new Error('Required testcase lacks PASS evidence: ' + c.id);
  }
  return { status: 'PASS', candidateSha, scope: report.scope, note: 'Local evidence validated; independently execute hosted required gates before approval.' };
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [directory, sha] = process.argv.slice(2);
  const catalog = JSON.parse(await readFile(new URL('../functional-regression/catalog.json', import.meta.url))).cases;
  console.log(JSON.stringify(validateSubmission(await verifyEvidence(directory), sha, catalog), null, 2));
}
