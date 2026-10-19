import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const origin = process.env.SANITY_ORIGIN || 'http://127.0.0.1:5000';
const outputDirectory = resolve(process.env.SANITY_OUTPUT_DIR || 'output');
const deadline = Date.now() + 60_000;
let lastFailure = 'backend did not answer';

while (Date.now() < deadline) {
  try {
    const response = await fetch(`${origin}/health`, { redirect: 'error', signal: AbortSignal.timeout(3_000) });
    const health = await response.json();
    if (response.ok && health.status === 'ok' && health.database === 'connected' && health.environment === 'test' && health.firebase === false && health.cloudinary === false) {
      await mkdir(outputDirectory, { recursive: true });
      await writeFile(resolve(outputDirectory, 'startup-result.json'), `${JSON.stringify({
        scenario: 'startup-01', result: 'passed', health, checkedAt: new Date().toISOString(),
      }, null, 2)}\n`);
      console.log('Startup scenario passed: isolated backend reports connected MongoDB and disabled Firebase/Cloudinary.');
      process.exit(0);
    }
    lastFailure = `unexpected health response: ${JSON.stringify(health)}`;
  } catch (error) {
    lastFailure = error.message;
  }
  await new Promise((resolveDelay) => setTimeout(resolveDelay, 1_000));
}

throw new Error(`Startup scenario failed before its deadline: ${lastFailure}`);
