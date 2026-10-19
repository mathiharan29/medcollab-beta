import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { access, readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';

const target = resolve(process.argv[2] || '');
const expected = process.argv[3];
if (!/^[a-f0-9]{40}$/.test(expected || '')) throw new Error('Expected exact target SHA');
const git = (...args) => execFileSync('git', ['-C', target, ...args], { encoding: 'utf8' }).trim();
const head = git('rev-parse', 'HEAD');
const tree = git('rev-parse', 'HEAD^{tree}');
const trackedChanges = git('status', '--porcelain', '--untracked-files=no');
if (head !== expected || trackedChanges) throw new Error('Target HEAD differs or tracked source was modified');
await access(join(target, 'medcollab-backend', 'package-lock.json'));
try { await access(join(target, 'medcollab-backend', '.env')); throw new Error('Target contains .env'); } catch (error) { if (error.code !== 'ENOENT') throw error; }
const backendLockSha256 = createHash('sha256').update(await readFile(join(target, 'medcollab-backend', 'package-lock.json'))).digest('hex');
console.log(JSON.stringify({ status: 'PASS', head, tree, backendLockSha256, trackedChanges }));
