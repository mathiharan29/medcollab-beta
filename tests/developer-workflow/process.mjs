import { spawn } from 'node:child_process';
import { execFileSync } from 'node:child_process';
import { readFile, lstat } from 'node:fs/promises';
import { join } from 'node:path';
import { hash } from './evidence.mjs';

export function git(root, args) { return execFileSync('git', ['-C', root, ...args], { encoding: 'utf8', windowsHide: true }).trim(); }
export function tracked(root) { return execFileSync('git', ['-C', root, 'ls-files', '-z'], { encoding: 'utf8' }).split('\0').filter(Boolean); }
export function applicationFile(file) { return /^(medcollab-backend|medcollab-app)\//.test(file) && !/^medcollab-backend\/(scripts|tests)\/|^medcollab-app\/(test|integration_test|test_driver)\//.test(file); }
export async function fingerprint(root, paths) {
  const hashes = {};
  for (const file of [...new Set(paths)].sort()) {
    const full = join(root, file);
    try {
      const stat = await lstat(full);
      if (!stat.isFile() || stat.isSymbolicLink()) throw new Error('Non-regular source file: ' + file);
      hashes[file] = hash(await readFile(full));
    } catch (error) { if (error.code === 'ENOENT') hashes[file] = 'DELETED'; else throw error; }
  }
  return { fingerprint: hash(JSON.stringify(hashes)), hashes };
}
export function cleanEnvironment() {
  return Object.fromEntries(Object.entries(process.env).filter(([key]) => /^(PATH|PATHEXT|SYSTEMROOT|SYSTEMDRIVE|WINDIR|COMSPEC|PROGRAMFILES|PROGRAMFILES\(X86\)|PROGRAMW6432|TEMP|TMP|TMPDIR|USERPROFILE|LOCALAPPDATA|APPDATA|HOME|LANG|LC_ALL|JAVA_HOME|ANDROID_HOME|ANDROID_SDK_ROOT|ANDROID_USER_HOME|ANDROID_AVD_HOME|VOCLE_ANDROID_TRUSTSTORE|PUB_CACHE|NPM_CONFIG_CACHE|PIP_CACHE_DIR|GRADLE_USER_HOME|VIRTUAL_ENV|DOCKER_CONFIG|PSMODULEANALYSISCACHEPATH)$/i.test(key)));
}
export async function run(bin, args, { cwd, env = cleanEnvironment(), timeout = 120000, log, signal } = {}) {
  if (signal?.aborted) return { code: null, error: 'Run cancelled', aborted: true, stdout: '', stderr: '' };
  const batch = process.platform === 'win32' && /\.(bat|cmd)$/i.test(bin);
  if (batch && !/^[A-Za-z]:[\\/]/.test(bin)) {
    try { bin = execFileSync('where.exe', [bin], { encoding: 'utf8', env }).trim().split(/\r?\n/)[0]; }
    catch { return { code: null, error: 'Executable unavailable: ' + bin, stdout: '', stderr: '' }; }
  }
  if (batch && [bin, ...args].some(a => /[&|<>^%\r\n"]/.test(a))) throw new Error('Unsafe batch argument');
  const child = spawn(batch ? 'cmd.exe' : bin, batch ? ['/d', '/s', '/c', `""${bin}" ${args.map(a => `"${a}"`).join(' ')}"`] : args,
    { cwd, env, windowsHide: true, windowsVerbatimArguments: batch, detached: process.platform !== 'win32', shell: false, stdio: ['ignore', 'pipe', 'pipe'] });
  const out = [], err = [];
  child.stdout.on('data', b => out.push(b)); child.stderr.on('data', b => err.push(b));
  let timedOut = false, aborted = false, spawnError;
  function terminate() {
    if (!child.pid) return;
    if (process.platform === 'win32') {
      // Killing cmd.exe alone leaves Flutter, npm and Dart children running.
      const killer = spawn('taskkill.exe', ['/pid', String(child.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' });
      killer.once('error', () => child.kill('SIGKILL'));
      killer.once('close', code => { if (code !== 0) child.kill('SIGKILL'); });
    } else {
      try { process.kill(-child.pid, 'SIGKILL'); } catch { child.kill('SIGKILL'); }
    }
  }
  const cancel = () => { aborted = true; terminate(); };
  const timer = setTimeout(() => { timedOut = true; terminate(); }, timeout);
  signal?.addEventListener('abort', cancel, { once: true });
  const result = await new Promise(resolve => {
    child.once('error', error => { spawnError = error.message; });
    child.once('close', (code, childSignal) => resolve({ code, signal: childSignal, ...(spawnError ? { error: spawnError } : {}) }));
  });
  clearTimeout(timer);
  signal?.removeEventListener('abort', cancel);
  result.stdout = Buffer.concat(out).toString(); result.stderr = Buffer.concat(err).toString(); result.timedOut = timedOut; result.aborted = aborted;
  if (log) { const { writeFile } = await import('node:fs/promises'); await writeFile(log, result.stdout + result.stderr); }
  return result;
}
