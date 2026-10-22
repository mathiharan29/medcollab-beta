import { resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';

export const harnessRoot = resolve(fileURLToPath(new URL('../', import.meta.url)));
export const repoRoot = resolve(harnessRoot, '../..');
export const runId = (process.env.VOCLE_RUN_ID || randomUUID()).replaceAll(/[^a-zA-Z0-9_-]/g, '').slice(0, 48);
const targetFlag = process.argv.indexOf('--target-dir');
export const targetRoot = resolve(process.env.VOCLE_TARGET_DIR || (targetFlag >= 0 ? process.argv[targetFlag + 1] : null) || repoRoot);
export const backendRoot = join(targetRoot, 'medcollab-backend');
export const outputRoot = resolve(process.env.VOCLE_OUTPUT_DIR || join(harnessRoot, 'output'));

export function validateConfig() {
  if (!runId || !existsSync(join(backendRoot, 'package.json')) || !existsSync(join(backendRoot, 'src/server.js'))) throw new Error('Target backend is missing');
  if (existsSync(join(backendRoot, '.env'))) throw new Error('Refusing a backend target with .env');
  if (!existsSync(join(backendRoot, 'node_modules/mongodb-memory-server'))) throw new Error('Target backend dev dependencies are missing; run npm ci in the selected target');
}
