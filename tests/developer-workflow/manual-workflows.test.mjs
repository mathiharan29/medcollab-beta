import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { test } from 'node:test';
import { root } from '../reporting/report.mjs';

const bash = process.platform === 'win32'
  ? [join(process.env.ProgramFiles || 'C:/Program Files', 'Git/bin/bash.exe'), join(process.env.LOCALAPPDATA || '', 'Programs/Git/bin/bash.exe')].find(existsSync)
  : 'bash';
assert(bash, 'Git Bash is required to execute the real hosted context guards on Windows');
const directory = join(root, '.github/workflows');
let guards = 0;
for (const file of await readdir(directory)) {
  const text = (await readFile(join(directory, file), 'utf8')).replaceAll('\r\n', '\n');
  for (const match of text.matchAll(/- name: Validate supported PR or manual context\n([\s\S]*?)(?=\n      - |$)/g)) {
    const script = match[1].split('        run: |\n')[1]?.split('\n').map(line => line.replace(/^ {10}/, '')).join('\n');
    assert(script?.includes('set -euo pipefail'), `Missing fail-closed guard: ${file}`);
    const index = ++guards;
    test(`${file} guard ${index} accepts exact manual branches and same-repository PRs only`, () => {
      const base = { PATH: process.env.PATH, SystemRoot: process.env.SystemRoot, QA_REPOSITORY: 'mathiharan29/medcollab-beta', QA_EVENT: 'workflow_dispatch', QA_REF: 'refs/heads/master', QA_SHA: 'a'.repeat(40), QA_HEAD_REPOSITORY: '', QA_BASE_REF: '' };
      const run = overrides => spawnSync(bash, ['--noprofile', '--norc', '-c', script], { env: { ...base, ...overrides }, encoding: 'utf8', windowsHide: true, timeout: 10000 });
      for (const overrides of [{}, { QA_REF: 'refs/heads/testing/manual' }, { QA_EVENT: 'pull_request', QA_HEAD_REPOSITORY: base.QA_REPOSITORY, QA_BASE_REF: 'master' }]) {
        const result = run(overrides); assert.equal(result.status, 0, `${file}: ${result.stderr || result.error?.message}`);
      }
      for (const overrides of [{ QA_REPOSITORY: 'other/repo' }, { QA_EVENT: 'push' }, { QA_EVENT: 'schedule' }, { QA_REF: 'refs/tags/release' }, { QA_REF: 'refs/heads/' }, { QA_SHA: 'invalid' }, { QA_EVENT: 'pull_request', QA_HEAD_REPOSITORY: 'other/repo', QA_BASE_REF: 'master' }, { QA_EVENT: 'pull_request', QA_HEAD_REPOSITORY: base.QA_REPOSITORY, QA_BASE_REF: 'other' }]) {
        const result = run(overrides); assert.equal(result.error, undefined, result.error?.message); assert.notEqual(result.status, 0, `${file} accepted ${JSON.stringify(overrides)}`);
      }
    });
  }
}
test('every routine job and reusable context guard is exercised', () => assert.equal(guards, 14));
