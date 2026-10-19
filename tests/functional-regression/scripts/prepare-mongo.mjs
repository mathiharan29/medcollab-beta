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
const path = await MongoBinary.getPath();
console.log(JSON.stringify({ mongoBinary: path, downloadDirectory }));
