'use strict';
const fs = require('node:fs'); const path = require('node:path'); const { createHash } = require('node:crypto');
const { preflight, requireSafe } = require('./guard'); const { manifest, context, execute } = require('./cases');
const { Broker } = require('./broker');
function fingerprint() {
  const root = path.resolve(__dirname, '../../src'); const files = [];
  const walk = d => fs.readdirSync(d, { withFileTypes: true }).forEach(e => e.isDirectory() ? walk(path.join(d, e.name)) : files.push(path.join(d, e.name))); walk(root);
  const h = createHash('sha256'); files.sort().forEach(file => h.update(path.relative(root, file)).update(fs.readFileSync(file))); return h.digest('hex');
}
async function main() {
  const c = preflight(); const b = new Broker(c); const before = fingerprint(); const results = []; const cleanupOnly = process.argv.includes('--cleanup-only');
  let stopRequested = false, failure = null;
  const stop = () => { stopRequested = true; }; process.on('SIGTERM', stop); process.on('SIGINT', stop);
  try {
    if (!cleanupOnly) {
      const ctx = context(b), start = Date.now();
      for (let index = 0; index < manifest.count - 1; index++) {
        requireSafe(!stopRequested && Date.now() - start < 7 * 60 * 1000, 'RUN_STOP_REQUESTED');
        const result = await execute(index, ctx);
        requireSafe(!b.infrastructureError && b.network.telemetry.blocked === 0, b.infrastructureError || 'NETWORK_BOUNDARY_VIOLATION');
        const entry = { ...manifest.cases[index], status: result.pass ? 'PASS' : 'OBSERVATION', actual: result.actual, classification: result.pass ? 'bounded provider characterization' : result.classification, relatedCases: result.relatedCases };
        b.hygiene(JSON.stringify(entry)); results.push(entry);
        console.log(`${entry.caseId} ${entry.status}`);
      }
    }
  } catch (e) { failure = e.infrastructure ? e.code : 'HARNESS_EXECUTION_FAILED'; }
  finally {
    let cleanup;
    try { cleanup = await b.cleanup(); } catch { cleanup = { attempted: true, proven: false, failure: 'CLEANUP_FAILED' }; }
    const sameSource = before === fingerprint();
    if (!cleanup.proven || !sameSource || b.network.telemetry.blocked) failure ||= 'INFRASTRUCTURE_OR_CLEANUP_FAILED';
    const write = (name, value) => { const text = typeof value === 'string' ? value : JSON.stringify(value, null, 2) + '\n'; b.hygiene(text); fs.writeFileSync(path.join(c.out, name), text); };
    write(cleanupOnly ? 'post-job-cleanup.json' : 'cleanup.json', cleanup);
    if (!cleanupOnly) {
      results.push({ ...manifest.cases.at(-1), status: cleanup.proven ? 'PASS' : 'INFRASTRUCTURE_FAILURE', actual: cleanup });
      const counts = { registered: manifest.count, executed: results.length, pass: results.filter(r => r.status === 'PASS').length, observations: results.filter(r => r.status === 'OBSERVATION').length, infrastructureFailures: failure ? 1 : 0 };
      write('results.json', { runId: c.runId, attempt: c.attempt, source: c.source, executionMode: c.executionMode, namespace: c.root, counts, safety: { positiveAllowlistMatched: true, approvedTestCloudOnly: b.network.telemetry.approvedCloudOnly, network: b.network.telemetry, syntheticFixturesOnly: true, appSourceUnchanged: sameSource, appSourceSHA256: before }, failure, cases: results });
      write('manifest.json', manifest);
      write('summary.md', `# Real Cloudinary security integration\n\nRun ${c.runId}, attempt ${c.attempt}, source ${c.source}.\n\n${counts.executed}/${counts.registered} executed; ${counts.pass} passes; ${counts.observations} observations. Infrastructure: ${failure ? failure : 'healthy'}. Cleanup proven: ${cleanup.proven}.\n\nPositive test-cloud allowlist matched before SDK initialization. Only synthetic image/video/raw assets; exact recorded-resource cleanup; no broad deletion. Controller-level lane with namespace adaptation, no route/auth/database execution credited.\n`);
      write('security-test-report.md', results.map(r => `## ${r.caseId}: ${r.name}\n\n${r.status}\n\nExpected: ${r.expected}\n\nActual: \`${JSON.stringify(r.actual)}\`\n\nRelated cases: ${(r.relatedCases || []).join(', ') || 'none'}\n`).join('\n'));
      console.log(`Executed ${counts.executed}/${counts.registered}; pass ${counts.pass}; observations ${counts.observations}; cleanup ${cleanup.proven ? 'proven' : 'unproven'}.`);
    }
    process.removeListener('SIGTERM', stop); process.removeListener('SIGINT', stop);
    if (failure) process.exitCode = 1;
  }
}
main().catch(e => { console.error(e.infrastructure ? e.code : 'HARNESS_STARTUP_FAILED'); process.exitCode = 1; });
