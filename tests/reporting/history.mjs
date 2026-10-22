// Optional read-only baseline lookup. It never supplies workflow skip/success evidence.
import { execFileSync } from 'node:child_process';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { contextProblem } from '../developer-workflow/context.mjs';

export async function api(path, token = process.env.GITHUB_TOKEN) {
  const response = await fetch('https://api.github.com/repos/mathiharan29/medcollab-beta' + path, { headers: { Accept: 'application/vnd.github+json', ...(token ? { Authorization: `Bearer ${token}` } : {}), 'X-GitHub-Api-Version': '2022-11-28' }, signal: AbortSignal.timeout(15000), redirect: 'manual' });
  if (!response.ok) throw new Error(`GitHub read-only API returned ${response.status}`);
  return response.json();
}
export async function artifactReports(id, rawResults = false, digest) {
  const response = await fetch(`https://api.github.com/repos/mathiharan29/medcollab-beta/actions/artifacts/${id}/zip`, { headers: { Authorization: `Bearer ${process.env.GITHUB_TOKEN}` }, redirect: 'manual', signal: AbortSignal.timeout(15000) });
  if (response.status !== 302) throw new Error(`Artifact read returned ${response.status}`);
  const url = new URL(response.headers.get('location'));
  if (url.protocol !== 'https:') throw new Error('Unsafe artifact redirect');
  const archive = await fetch(url, { signal: AbortSignal.timeout(30000) });
  if (!archive.ok) throw new Error(`Artifact storage returned ${archive.status}`);
  const dir = await mkdtemp(join(tmpdir(), 'vocle-report-'));
  try {
    const zip = join(dir, 'report.zip');
    const bytes = Buffer.from(await archive.arrayBuffer());
    if (bytes.length > 64 * 1024 * 1024) throw new Error('Oversized history artifact');
    if (digest && digest !== 'sha256:' + createHash('sha256').update(bytes).digest('hex')) throw new Error('Artifact integrity mismatch');
    await writeFile(zip, bytes);
    // Read exact JSON members, never extract arbitrary ZIP paths or execute content.
    const suffix = rawResults ? '/results.json' : 'vocle-regression-results.json';
    const code = "import zipfile,json,sys\nwith zipfile.ZipFile(sys.argv[1]) as z:\n members=[n for n in z.namelist() if (n=='results.json' or n.endswith(sys.argv[2]))] if sys.argv[3]=='raw' else [n for n in z.namelist() if n.endswith(sys.argv[2])]\n if len(members)>4 or sum(z.getinfo(n).file_size for n in members)>30000000: raise ValueError('Oversized report inventory')\n print(json.dumps([json.loads(z.read(n)) for n in members]))";
    return JSON.parse(execFileSync(process.platform === 'win32' ? 'python' : 'python3', ['-c', code, zip, suffix, rawResults ? 'raw' : 'normalized'], { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024, windowsHide: true }));
  } finally { await rm(dir, { recursive: true, force: true }); }
}
// Paginate completed runs (including failures), then independently inspect attempts.
// All network calls have deadlines; a whole lookup also has a bounded request budget.
export async function priorCompatible(current, compare, { request = api, download = artifactReports, maxPages = 10, maxRequests = 60 } = {}) {
  if (contextProblem(current.context, current.context)) throw new Error('Missing trustworthy PR/branch context');
  if (!process.env.GITHUB_TOKEN || !process.env.GITHUB_RUN_ID) return null;
  let remaining = maxRequests;
  const deadline = Date.now() + 60000;
  const get = path => {
    if (--remaining < 0 || Date.now() >= deadline) throw new Error('History lookup request/time budget exhausted');
    return request(path);
  };
  const securityWorkflows = { discovery: 'vocle-api-realtime-security.yml', media: 'vocle-media-security.yml', data: 'vocle-data-security.yml', cloudinary: 'vocle-cloudinary-security.yml' };
  const workflow = securityWorkflows[current.scope] || (current.suite === 'sanity' ? 'vocle-sanity.yml' : 'vocle-functional-regression.yml');
  const prefix = current.suite === 'security' ? `vocle-qa-dashboard-${workflow}-` : current.suite === 'sanity' ? 'vocle-sanity-diagnostics-' : current.suite === 'flutter' ? 'vocle-flutter-report-' : 'vocle-functional-report-';
  const workflows = current.suite === 'security' && current.scope === 'discovery' ? [workflow, 'vocle-backend-environment-test.yml'] : [workflow];
  const prefixes = workflows.map(name => current.suite === 'security' ? `vocle-qa-dashboard-${name}-` : prefix);
  let lastReason = 'No compatible completed previous execution';
  const runs = [];
  for (const workflowName of workflows) for (let page = 1; page <= maxPages; page++) {
    const listing = await get(`/actions/workflows/${workflowName}/runs?status=completed&per_page=100&page=${page}`);
    runs.push(...listing.workflow_runs || []);
    if ((listing.workflow_runs || []).length < 100) break;
  }
  // A running rerun is absent from status=completed, but earlier attempts may qualify.
  if (Number(current.execution.attempt) > 1 && !runs.some(r => String(r.id) === String(current.execution.runId))) runs.push(await get(`/actions/runs/${current.execution.runId}`));
  const executions = [];
  for (const run of runs) {
    const same = current.context.kind === 'pull_request'
      ? run.event === 'pull_request' && run.pull_requests?.some(p => p.number === current.context.prNumber)
      : 'refs/heads/' + run.head_branch === current.context.branchRef && run.event !== 'pull_request';
    if (!same || run.head_repository?.full_name !== current.context.repository) continue;
    for (let attempt = run.run_attempt; attempt >= 1; attempt--) {
      if (`${run.id}:${attempt}` === current.execution.id) continue;
      const execution = await get(`/actions/runs/${run.id}/attempts/${attempt}`);
      if (execution.status === 'completed') executions.push({ ...execution, id: run.id, attempt });
    }
  }
  executions.sort((a, b) => String(b.updated_at || b.completed_at).localeCompare(String(a.updated_at || a.completed_at)) || b.id - a.id || b.attempt - a.attempt);
  for (const execution of executions) {
    const { id: runId, attempt } = execution;
    for (let page = 1; page <= maxPages; page++) {
      const listing = await get(`/actions/runs/${runId}/artifacts?per_page=100&page=${page}`);
      const artifacts = listing.artifacts || [];
      for (const a of artifacts.filter(a => prefixes.some(p => a.name === `${p}${runId}-${attempt}`))) {
        if (a.expired) { lastReason = 'Previous artifact expired'; continue; }
        if (!/^sha256:[a-f0-9]{64}$/.test(a.digest || '')) { lastReason = 'Previous artifact lacks integrity digest'; continue; }
        try {
          if (--remaining < 0 || Date.now() >= deadline) throw new Error('History lookup budget exhausted');
          for (const previous of await download(a.id, false, a.digest)) {
            if (previous.execution?.id !== `${runId}:${attempt}` || previous.source?.sha !== execution.head_sha) { lastReason = 'Previous execution/source identity mismatch'; continue; }
            const comparison = compare(current, previous);
            if (comparison.available) return { report: previous, artifactId: a.id, runId, attempt };
            lastReason = comparison.reason;
          }
        } catch (error) { lastReason = 'Previous artifact unavailable: ' + error.message; }
      }
      if (artifacts.length < 100) break;
    }
  }
  throw new Error(lastReason);
}
