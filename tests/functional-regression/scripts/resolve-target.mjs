import { appendFile } from 'node:fs/promises';
import { upstreamRepository } from './ci-contracts.mjs';
if (process.env.GITHUB_EVENT_NAME !== 'pull_request' || process.env.GITHUB_REPOSITORY !== upstreamRepository || process.env.VOCLE_PR_HEAD_REPOSITORY !== upstreamRepository) throw new Error('Unsupported execution context: a same-repository PR targeting master is required');
const targetSha = process.env.VOCLE_PR_HEAD_SHA;
if (!/^[a-f0-9]{40}$/.test(targetSha || '')) throw new Error('Exact PR head SHA required');
const result = { targetKind: 'pr-head', targetSha, scope: 'backend-all', targetRepository: upstreamRepository };
if (process.env.GITHUB_OUTPUT) await appendFile(process.env.GITHUB_OUTPUT, Object.entries(result).map(([key, value]) => `${key}=${value}\n`).join(''));
console.log(JSON.stringify(result));
