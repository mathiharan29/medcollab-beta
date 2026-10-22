// Read-only evidence export from the authorized repository. Credentials remain in memory.
import { execFileSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
const [runId, directory] = process.argv.slice(2);
if (!/^\d+$/.test(runId || '') || !directory) throw new Error('Usage: fetch-ci-evidence.mjs RUN_ID OUTPUT_DIRECTORY');
const root = resolve(import.meta.dirname, '../..');
const origin = execFileSync('git', ['-C', root, 'remote', 'get-url', 'origin'], { encoding: 'utf8' }).trim();
if (origin !== 'https://github.com/mathiharan29/medcollab-beta.git') throw new Error('Authorized repository origin required');
const output = resolve(directory); await mkdir(output, { recursive: true });
const base = 'https://api.github.com/repos/mathiharan29/medcollab-beta';
let headers = { Accept: 'application/vnd.github+json', 'User-Agent': 'vocle-read-only-evidence' };
async function get(path) { const response = await fetch(base + path, { headers, redirect: 'manual', signal: AbortSignal.timeout(30000) }); if (!response.ok) throw new Error('GitHub read failed: ' + response.status); return response.json(); }
const metadata = await get('/actions/runs/' + runId);
const jobs = await get('/actions/runs/' + runId + '/jobs');
const artifacts = await get('/actions/runs/' + runId + '/artifacts');
await writeFile(join(output, 'ci-metadata.json'), JSON.stringify({ run: metadata, jobs, artifacts }, null, 2));
const credential = execFileSync('git', ['credential', 'fill'], { cwd: root,
  input: 'protocol=https\nhost=github.com\npath=mathiharan29/medcollab-beta.git\n\n', encoding: 'utf8',
  env: { ...process.env, GIT_TERMINAL_PROMPT: '0', GCM_INTERACTIVE: 'Never' }, stdio: ['pipe', 'pipe', 'pipe'] });
const token = credential.split(/\r?\n/).find(line => line.startsWith('password='))?.slice(9);
if (!token) throw new Error('Stored GitHub credentials unavailable for artifact export');
headers = { ...headers, Authorization: 'Bearer ' + token };
let count = 0;
for (const artifact of artifacts.artifacts) {
  if (artifact.expired || !/^(vocle-functional-report-|vocle-flutter-report-|developer-qa-)/.test(artifact.name)) continue;
  const response = await fetch(base + '/actions/artifacts/' + artifact.id + '/zip', { headers, redirect: 'manual', signal: AbortSignal.timeout(30000) });
  if (response.status !== 302) throw new Error('Artifact read failed: ' + response.status);
  const signed = new URL(response.headers.get('location'));
  if (signed.protocol !== 'https:') throw new Error('Unsafe artifact transport');
  // Never forward GitHub credentials to the storage redirect.
  const download = await fetch(signed, { signal: AbortSignal.timeout(30000) });
  if (!download.ok) throw new Error('Artifact download failed: ' + download.status);
  await writeFile(join(output, artifact.name + '.zip'), Buffer.from(await download.arrayBuffer()));
  count++;
}
console.log(JSON.stringify({ runId, sourceSha: metadata.head_sha, conclusion: metadata.conclusion, artifacts: count, output }, null, 2));
