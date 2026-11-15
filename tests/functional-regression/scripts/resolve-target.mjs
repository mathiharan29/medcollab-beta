import { appendFile } from 'node:fs/promises';
import { upstreamRepository } from './ci-contracts.mjs';
if (process.env.GITHUB_REPOSITORY !== upstreamRepository) throw new Error('Unsupported repository');
const event = process.env.GITHUB_EVENT_NAME;
let targetSha, targetKind;
if (event === 'pull_request') {
  if (process.env.VOCLE_PR_HEAD_REPOSITORY !== upstreamRepository) throw new Error('A same-repository PR is required');
  targetSha = process.env.VOCLE_PR_HEAD_SHA;
  targetKind = 'pr-head';
} else if (event === 'workflow_dispatch') {
  if (!/^refs\/heads\/.+/.test(process.env.GITHUB_REF || '')) throw new Error('Manual execution requires a repository branch');
  targetSha = process.env.GITHUB_SHA;
  targetKind = 'commit';
} else throw new Error('Unsupported execution event');
if (!/^[a-f0-9]{40}$/.test(targetSha || '')) throw new Error('Exact application SHA required');
const result = { targetKind, targetSha, scope: 'backend-all', targetRepository: upstreamRepository };
if (process.env.GITHUB_OUTPUT) await appendFile(process.env.GITHUB_OUTPUT, Object.entries(result).map(([key, value]) => `${key}=${value}\n`).join(''));
console.log(JSON.stringify(result));
