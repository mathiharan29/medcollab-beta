import { createRequire } from 'node:module';
import { join } from 'node:path';
import { mkdir } from 'node:fs/promises';

export function backendRequire(backendRoot) { return createRequire(join(backendRoot, 'package.json')); }

export async function startMongo(backendRoot, downloadDirectory, { enableTestCommands = false, dbPath } = {}) {
  const require = backendRequire(backendRoot);
  const { MongoMemoryServer } = require('mongodb-memory-server');
  const previous = process.env.MONGOMS_DOWNLOAD_DIR;
  process.env.MONGOMS_DOWNLOAD_DIR = downloadDirectory;
  try {
    if (dbPath) await mkdir(dbPath, { recursive: true });
    const server = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1', ...(dbPath ? { dbPath, storageEngine: 'wiredTiger' } : {}), ...(enableTestCommands ? { args: ['--setParameter', 'enableTestCommands=1'] } : {}) } });
    const uri = server.getUri();
    if (!/^mongodb:\/\/127\.0\.0\.1:/.test(uri)) { await server.stop(); throw new Error('Mongo server was not loopback'); }
    return { server, uri };
  } finally {
    if (previous === undefined) delete process.env.MONGOMS_DOWNLOAD_DIR;
    else process.env.MONGOMS_DOWNLOAD_DIR = previous;
  }
}

export function databaseUri(baseUri, moduleName, runId) {
  if (!/^[a-z][a-z0-9_-]*$/.test(moduleName)) throw new Error('Invalid module name');
  const uri = new URL(baseUri);
  const name = `vocle_regression_${runId.replaceAll('-', '').slice(0, 16)}_${moduleName.replaceAll('-', '_')}`;
  if (name.length > 63) throw new Error('Module database name exceeds MongoDB limit');
  uri.pathname = `/${name}`;
  return uri.toString();
}

export async function inspectDatabase(backendRoot, uri, action) {
  const require = backendRequire(backendRoot);
  const mongoose = require('mongoose');
  const connection = await mongoose.createConnection(uri, { serverSelectionTimeoutMS: 10000 }).asPromise();
  try { return await action(connection); } finally { await connection.close(); }
}
