import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { randomUUID, createHash } from 'node:crypto';

const sha256 = value => createHash('sha256').update(value).digest('hex');
const git = (root, args) => {
  try { return execFileSync('git', ['-C', root, ...args], { encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'ignore'] }).trim(); }
  catch { return ''; }
};
export function captureContext(root, { repository, prNumber, branchRef } = {}, env = process.env) {
  let event = {};
  try { event = JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8')); } catch { /* local or absent event */ }
  const remote = git(root, ['remote', 'get-url', 'origin']);
  const match = /github\.com[/:]([^/]+\/[^/]+?)(?:\.git)?$/.exec(remote);
  repository ||= env.GITHUB_REPOSITORY || match?.[1];
  prNumber ||= env.VOCLE_PR_NUMBER || event.pull_request?.number || (env.GITHUB_EVENT_NAME === 'pull_request' ? event.number : null);
  branchRef ||= env.VOCLE_BRANCH_REF || (event.pull_request?.head?.ref ? 'refs/heads/' + event.pull_request.head.ref : null);
  if (!branchRef) branchRef = env.GITHUB_REF?.startsWith('refs/heads/') ? env.GITHUB_REF : git(root, ['symbolic-ref', '-q', 'HEAD']);
  return { repository: repository || null, kind: prNumber ? 'pull_request' : 'branch',
    prNumber: prNumber ? Number(prNumber) : null, branchRef: branchRef || null };
}
export function executionIdentity(env = process.env) {
  const runId = env.GITHUB_RUN_ID || null, attempt = env.GITHUB_RUN_ATTEMPT || null;
  return { id: runId ? `${runId}:${attempt}` : randomUUID(), runId, attempt,
    mode: runId ? 'HOSTED' : 'LOCAL', completed: true, completedAt: new Date().toISOString() };
}
export function contextProblem(current, previous) {
  if (!current?.repository || !previous?.repository || current.repository !== previous.repository) return 'Missing or different repository identity';
  if (current.kind !== previous.kind) return 'Different PR/branch context';
  if (current.kind === 'pull_request') {
    if (!Number.isSafeInteger(current.prNumber) || current.prNumber < 1 || current.prNumber !== previous.prNumber) return 'Missing or different PR identity';
  } else if (!current.branchRef?.startsWith('refs/heads/') || current.branchRef !== previous.branchRef) return 'Missing or different development branch; detached sources cannot guess history';
  return null;
}
export function sealReport(report) {
  delete report.evidenceIntegrity;
  report.evidenceIntegrity = { algorithm: 'sha256', checksum: sha256(JSON.stringify(report)) };
  return report;
}
export function verifiedReport(report) {
  if (report?.evidenceIntegrity?.algorithm !== 'sha256') return false;
  const { evidenceIntegrity, ...content } = report;
  return evidenceIntegrity.checksum === sha256(JSON.stringify(content));
}
export function historyProblem(current, previous) {
  const problem = contextProblem(current.context, previous?.context);
  if (problem) return problem;
  if (!previous.execution?.completed || !Number.isFinite(Date.parse(previous.execution.completedAt)) || !previous.execution.id) return 'Previous execution is incomplete or lacks execution identity';
  if (current.execution?.id === previous.execution.id) return 'Current execution cannot compare with itself';
  if (current.execution?.mode !== previous.execution.mode) return 'Hosted and local executions have separate evidence contracts';
  return null;
}
