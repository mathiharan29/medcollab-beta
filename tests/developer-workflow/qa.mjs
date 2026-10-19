import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { hash, json } from './evidence.mjs';

export function defects(report, ownership = {}) {
  const sourceRevision = { sha: report.source.sha, kind: report.source.kind, fingerprint: report.source.fingerprint };
  // Only explicit evidence-backed rootCause keys group failures; matching messages alone do not.
  const groups = new Map();
  for (const row of report.results.filter(r => r.status !== 'PASS' && r.status !== 'SKIP')) {
    const key = row.rootCause || row.id;
    const group = groups.get(key) || [];
    group.push(row); groups.set(key, group);
  }
  return [...groups].map(([key, rows]) => ({
    defectId: 'QA-' + hash(key).slice(0, 12), feature: [...new Set(rows.map(r => r.module || 'TOOLING'))], testcaseIds: rows.map(r => r.id),
    severity: rows.some(r => r.priority === 'P0') ? 'HIGH (suggested; QA review required)' : 'UNASSESSED',
    reproducibility: 'One recorded execution; rerun required', expected: rows.map(r => r.expected || 'Required check completes with valid evidence'),
    actual: rows.map(r => ({ status: r.status, error: r.error || r.exclusion })), source: sourceRevision,
    reproduction: report.reproduction || 'Use original run command and exact source/harness revisions recorded in provenance',
    artifacts: rows.flatMap(r => r.artifacts || []),
    suggestedOwner: ownership.approved ? [...new Set(rows.map(r => ownership.modules?.[r.module] || 'UNASSIGNED'))] : ['UNASSIGNED'],
    verificationStatus: 'RECORDED; independent QA verification pending', ownerRequest: 'Authorized maintainer must confirm owner and routing before assignment/notification',
  }));
}
export async function writeQA(directory, report, ownership) {
  await mkdir(directory, { recursive: true });
  const findings = defects(report, ownership);
  await writeFile(join(directory, 'qa-defects.json'), json({ source: report.source, harness: report.harness, findings }));
  await writeFile(join(directory, 'qa-defects.md'), `# QA findings\n\nSource: ${report.source.sha}; harness: ${report.harness.sha}.\nNo issues, assignments or notifications are created.\n\n${findings.map(f => `## ${f.defectId}\n\nFeature: ${f.feature.join(', ')}; cases: ${f.testcaseIds.join(', ')}.\nOwner: **${f.suggestedOwner.join(', ')}**. ${f.ownerRequest}.\nSeverity: ${f.severity}. Reproducibility: ${f.reproducibility}.\nExpected: ${f.expected.join('; ')}.\nActual: ${JSON.stringify(f.actual)}.\nReproduce: ${f.reproduction}.\nArtifacts: ${f.artifacts.join(', ') || 'run diagnostics and original reports'}.\nVerification: ${f.verificationStatus}.\n`).join('\n')}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [input, output] = process.argv.slice(2);
  const original = JSON.parse(await readFile(input, 'utf8'));
  let provenance = {}; try { provenance = JSON.parse(await readFile(join(output, 'provenance.json'))); } catch { /* original report may carry provenance */ }
  const catalog = JSON.parse(await readFile(new URL('../functional-regression/catalog.json', import.meta.url)));
  const rows = original.results || original.cases || [];
  if (!rows.length) throw new Error('No result rows to route');
  const report = { source: original.source || { sha: original.targetSha || original.sourceSha || provenance.targetSha }, harness: original.harness || { sha: original.harnessSha || provenance.harnessSha, fingerprint: original.fingerprint || provenance.fingerprint }, results: rows.map(r => ({ ...catalog.cases.find(c => c.id === r.id), ...r })) };
  await writeQA(output, report, JSON.parse(await readFile(new URL('ownership.json', import.meta.url))));
}
