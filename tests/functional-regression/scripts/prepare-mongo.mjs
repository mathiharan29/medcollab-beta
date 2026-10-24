import { createRequire } from 'node:module';
import { join, resolve } from 'node:path';
import { mkdir } from 'node:fs/promises';

const target = resolve(process.argv[2] || '');
const output = resolve(process.argv[3] || '');
const downloadDirectory = join(output, 'mongo-binaries');
await mkdir(downloadDirectory, { recursive: true });
const require = createRequire(join(target, 'medcollab-backend', 'package.json'));
const { MongoBinary } = require('mongodb-memory-server-core');
process.env.MONGOMS_DOWNLOAD_DIR = downloadDirectory;

const attempts = 5;
let lastError;
for (let attempt = 1; attempt <= attempts; attempt++) {
  try {
    const path = await MongoBinary.getPath();
    console.log(JSON.stringify({ mongoBinary: path, downloadDirectory, attempt }));
    process.exit(0);
  } catch (error) {
    lastError = error;
    console.error(`Mongo binary download attempt ${attempt}/${attempts} failed: ${error.message || error}`);
    if (attempt < attempts) {
      await new Promise((resolveWait) => setTimeout(resolveWait, attempt * 5000));
    }
  }
}
throw lastError;
