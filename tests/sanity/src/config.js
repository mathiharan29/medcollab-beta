export const target = Object.freeze({
  repository: 'https://github.com/mathiharan29/medcollab-beta.git',
  ref: 'refs/heads/master',
  inspectedSha: '4638682c0c930fcde3378d7e809612b6c0eab370',
});

export const runtime = Object.freeze({
  databaseUri: 'mongodb://127.0.0.1:27017/vocle_sanity',
  origin: 'http://127.0.0.1:5000',
  nodeEnvironment: 'test',
});

export const fixtures = Object.freeze({
  users: ['A', 'B', 'C', 'D', 'E'],
  phones: ['+12025550101', '+12025550102', '+12025550103', '+12025550104', '+12025550105'],
  institution: 'Vocle Sanity Institute',
  handoffDateUtc: '2026-01-15T10:30:00.000Z',
});

export function validateStaticConfig() {
  const failures = [];
  if (target.ref !== 'refs/heads/master') failures.push('Target ref must explicitly be refs/heads/master.');
  if (!/^https:\/\/github\.com\/mathiharan29\/medcollab-beta\.git$/.test(target.repository)) failures.push('Target repository is not the selected upstream.');
  if (!/^[a-f0-9]{40}$/.test(target.inspectedSha)) failures.push('Inspected SHA is invalid.');
  if (runtime.databaseUri !== 'mongodb://127.0.0.1:27017/vocle_sanity') failures.push('Database URI is outside the isolated sanity database.');
  if (runtime.origin !== 'http://127.0.0.1:5000') failures.push('Origin is not the required local backend origin.');
  if (fixtures.users.length !== 5 || fixtures.phones.length !== 5) failures.push('Exactly five synthetic identities are required.');
  if (new Set(fixtures.phones).size !== fixtures.phones.length) failures.push('Synthetic phone numbers must be unique.');
  return failures;
}
