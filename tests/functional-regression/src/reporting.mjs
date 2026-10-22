import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const outcomes = ['PASS', 'FAIL', 'ERROR', 'BLOCKED', 'NEEDS_DECISION', 'SKIP'];
const xml = (value) => String(value ?? '').replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const sanitize = (value) => String(value ?? '').replace(/Bearer\s+\S+/gi, 'Bearer [REDACTED]').replace(/\b\d{6}\b/g, '[CODE]').replace(/eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[TOKEN]');

export async function writeReports(directory, { scope, targetSha, harnessSha, results, cleanup, provenance, selectedIds }) {
  await mkdir(directory, { recursive: true });
  const tally = Object.fromEntries(outcomes.map((status) => [status, results.filter((item) => item.status === status).length]));
  const ids = results.map((item) => item.id);
  const validIds = ids.every(Boolean) && new Set(ids).size === ids.length;
  const complete = validIds && selectedIds.length === results.length && selectedIds.every((id) => ids.includes(id));
  const success = complete && tally.PASS === selectedIds.length && cleanup?.status === 'PASS' && provenance?.status === 'PASS';
  const report = { schemaVersion: 1, scope, targetSha, harnessSha, selectedIds, complete, success, tally, results: results.map((item) => ({ ...item, error: sanitize(item.error) })), cleanup, provenance };
  await writeFile(join(directory, 'results.json'), `${JSON.stringify(report, null, 2)}\n`);
  const cases = results.map((item) => {
    const tag = item.status === 'PASS' ? '' : item.status === 'SKIP' ? `<skipped message="${xml(item.error || 'unselected')}"/>` : item.status === 'ERROR' ? `<error message="${xml(sanitize(item.error))}"/>` : `<failure message="${xml(`${item.status}: ${sanitize(item.error)}`)}"/>`;
    return `<testcase classname="vocle.${xml(item.module || scope)}" name="${xml(item.id || '__missing_id__')}" time="${((item.durationMs || 0) / 1000).toFixed(3)}">${tag}</testcase>`;
  }).join('\n');
  await writeFile(join(directory, 'junit.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<testsuite name="vocle-functional-${xml(scope)}" tests="${results.length}" failures="${tally.FAIL + tally.BLOCKED + tally.NEEDS_DECISION}" errors="${tally.ERROR}" skipped="${tally.SKIP}">\n${cases}\n</testsuite>\n`);
  await writeFile(join(directory, 'report.md'), `# Vocle functional regression: ${scope}\n\nResult: **${success ? 'PASS' : 'NON-SUCCESS'}**. Complete selected ID set: **${complete}**.\n\n${outcomes.map((status) => `- ${status}: ${tally[status]}`).join('\n')}\n\n${results.map((item) => `- ${item.id || '__missing_id__'}: ${item.status}${item.error ? ` — ${sanitize(item.error)}` : ''}`).join('\n')}\n`);
  await writeFile(join(directory, 'coverage.json'), `${JSON.stringify({ scope, selectedIds, observedIds: ids, complete, tally }, null, 2)}\n`);
  await writeFile(join(directory, 'provenance.json'), `${JSON.stringify(provenance, null, 2)}\n`);
  await writeFile(join(directory, 'cleanup.json'), `${JSON.stringify(cleanup, null, 2)}\n`);
  return report;
}
