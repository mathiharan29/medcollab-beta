import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { createFixtureUsers } from './fixtures.js';
import { closeDatabase, connectDatabase, supportTicketById } from './database.js';
import { expectSuccess, request } from './http.js';

const results = [];
const assert = (value, message) => { if (!value) throw new Error(message); };
async function scenario(id, action) {
  const startedAt = Date.now();
  try { await action(); results.push({ id, status: 'passed', durationMs: Date.now() - startedAt }); }
  catch (error) { results.push({ id, status: 'failed', durationMs: Date.now() - startedAt, error: error.message }); throw error; }
}
async function run() {
  await connectDatabase();
  const people = await createFixtureUsers();
  try {
    await scenario('support-01', async () => {
      const title = 'Sanity synthetic bug report'; const description = 'Synthetic test data only; no clinical information.';
      const created = expectSuccess(await request('/api/support/bug', { method: 'POST', token: people.A.token, expectedStatus: 201, body: { title, description, steps: 'Open synthetic fixture.' } }), 'submit bug report');
      const ticket = await supportTicketById(created.ticketId);
      await request('/api/support/bug', { method: 'POST', token: people.A.token, expectedStatus: 400, body: { description } });
      assert(ticket?.userId.toString() === people.A.userId && ticket.type === 'bug' && ticket.title === title && ticket.description === description, 'Stored support ticket did not preserve expected fields.');
    });
  } finally {
    await closeDatabase();
    const output = resolve(process.env.SANITY_OUTPUT_DIR || 'output'); await mkdir(output, { recursive: true });
    await writeFile(resolve(output, 'support-results.json'), `${JSON.stringify({ expected: 1, results }, null, 2)}\n`);
  }
  console.log('Support scenario passed: 1/1.');
}
run().catch(async (error) => { console.error(error.stack || error.message); await closeDatabase(); process.exitCode = 1; });
