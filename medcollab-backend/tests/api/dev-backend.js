// Throwaway local backend for API / device tests: in-memory MongoDB + the
// real server, OTP bypass (123456). Never points at production.
// Usage: node tests/api/dev-backend.js   (PORT from VOCLE_PORT, default 5001)
const path = require('path');
const backendDir = path.resolve(__dirname, '..', '..');
const { MongoMemoryServer } = require(path.join(backendDir, 'node_modules', 'mongodb-memory-server'));

(async () => {
  const mongo = await MongoMemoryServer.create({ instance: { ip: '127.0.0.1' } });
  const port = process.env.VOCLE_PORT || '5001';
  Object.assign(process.env, {
    NODE_ENV: 'development',
    PORT: port,
    API_BASE_URL: `http://10.0.2.2:${port}`,
    MONGODB_URI: mongo.getUri('vocle-e2e'),
    JWT_SECRET: 'local-e2e-access-secret-not-for-prod-000000',
    JWT_REFRESH_SECRET: 'local-e2e-refresh-secret-not-for-prod-00000',
    OTP_BYPASS: 'true',
    ALLOWED_ORIGINS: `http://localhost:${port}`,
    RATE_LIMIT_MAX_REQUESTS: '100000',
    OTP_RATE_LIMIT_MAX: '100000',
  });
  console.log('[e2e] mongo', process.env.MONGODB_URI);
  process.chdir(backendDir);
  require(path.join(backendDir, 'src', 'server.js'));
  const stop = async () => { await mongo.stop(); process.exit(0); };
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
})().catch((e) => { console.error('[e2e] failed', e); process.exit(1); });
