import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const xml = (value) => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');

export async function writePlannedReports({ outputDirectory, scenarios, checks }) {
  await mkdir(outputDirectory, { recursive: true });
  const createdAt = new Date().toISOString();
  const report = {
    schemaVersion: 1,
    phase: 1,
    result: 'planned',
    execution: 'not-executed',
    createdAt,
    expectedScenarioCount: scenarios.length,
    passedScenarioCount: 0,
    scenarios,
    checks,
    note: 'This report is a harness self-check and is not success-history evidence.',
  };
  await writeFile(join(outputDirectory, 'sanity-report.json'), `${JSON.stringify(report, null, 2)}\n`);
  const testCases = scenarios.map(({ id, name }) => `  <testcase classname="planned.${xml(id)}" name="${xml(name)}"><skipped message="planned; not executed in Phase 1" /></testcase>`).join('\n');
  await writeFile(join(outputDirectory, 'sanity-report.junit.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<testsuite name="vocle-sanity-planned" tests="${scenarios.length}" skipped="${scenarios.length}" failures="0" errors="0">\n${testCases}\n</testsuite>\n`);
  await writeFile(join(outputDirectory, 'sanity-report.md'), `# Vocle sanity Phase 1 self-check\n\nResult: **PLANNED / NOT EXECUTED**\n\n- Expected scenarios: ${scenarios.length}\n- Passed scenarios: 0\n- Registry/configuration checks: ${checks.length}\n\nThis output cannot be used as successful sanity evidence.\n`);
  return report;
}

const coverage = {
  'authentication-and-profiles': 'Exercises real MSG91 OTP interception, hashed OTP storage, token refresh, onboarding persistence, and device-token lifecycle.',
  'spaces-and-invitations': 'Covers default channel creation, invitation membership lifecycle, invitation rotation, and owner/member controls.',
  channels: 'Checks public/private channel access, duplicate prevention, updates, archive retention, and default-channel protection.',
  'messaging-and-needl': 'Checks REST persistence plus socket fan-out, pagination, quotes, threads, Needl, edits, deletion, reactions, pins, and emergency priority.',
  'message-requests': 'Checks the request state machine, inbox/list/count visibility, duplicate stability, notification persistence, and DM creation after acceptance.',
  'direct-and-group-conversations': 'Checks stable DM identity, message/read-receipt behavior, self notes, group membership, rename, and upstream history expansion.',
  handoffs: 'Checks drafts, submission/acknowledgement/reassignment lifecycle, write-backs, history, events, notification state, and immutable submitted records.',
  media: 'Checks local storage bytes and deletion, PDF attachment persistence, and accepted inert Cloudinary metadata without fetching external URLs.',
  notifications: 'Checks message/mention/emergency notification generation, personal socket delivery, deep-link metadata, counts, and all read-state operations.',
  'realtime-and-availability': 'Checks authenticated sockets, reconnect/rejoin, typing signals, availability persistence, space-room synchronization, and final offline presence.',
  search: 'Checks known-user discovery and fully scoped global results for messages, doctors, channels, attachments, handoffs, and no-match behavior.',
  support: 'Checks authenticated bug-report creation, stored author/content fields, and required-field validation.',
  startup: 'Checks the isolated backend health contract: connected MongoDB, test environment, and disabled Firebase/Cloudinary.',
};

export async function writeExecutionReports({ outputDirectory, scenarioGroups, results, metadata = {} }) {
  await mkdir(outputDirectory, { recursive: true });
  const byId = new Map(results.map((result) => [result.id, result]));
  const moduleForGroup = {
    'authentication-and-profiles': 'authentication-scenarios.js',
    'spaces-and-invitations': 'spaces-and-channels-scenarios.js',
    channels: 'spaces-and-channels-scenarios.js',
    'messaging-and-needl': 'messaging-scenarios.js',
    'message-requests': 'message-requests-and-conversations-scenarios.js',
    'direct-and-group-conversations': 'message-requests-and-conversations-scenarios.js',
    handoffs: 'handoff-scenarios.js', media: 'media-scenarios.js', notifications: 'notification-scenarios.js',
    'realtime-and-availability': 'realtime-availability-scenarios.js', search: 'search-scenarios.js',
    support: 'support-scenarios.js', startup: 'live-runner.js',
  };
  const all = scenarioGroups.flatMap((group) => group.scenarios.map((scenario) => {
    const recorded = byId.get(scenario.id);
    if (recorded) return { ...scenario, ...recorded };
    const moduleName = moduleForGroup[group.id];
    const relatedGroups = scenarioGroups.filter((item) => moduleForGroup[item.id] === moduleName);
    const failed = relatedGroups.flatMap((item) => item.scenarios).map((item) => byId.get(item.id)).find((item) => item?.status === 'failed');
    const outcome = metadata.modules?.find((item) => item.file === moduleName);
    const reason = failed ? `Not executed: ${moduleName} stopped after ${failed.id} failed.` : outcome ? `Not executed: ${moduleName} exited with code ${outcome.code}${outcome.timedOut ? ' after its deadline' : ''}.` : `Not executed: ${moduleName} produced no result.`;
    return { ...scenario, status: 'blocked', error: reason };
  }));
  const passed = all.filter((scenario) => scenario.status === 'passed').length;
  const failed = all.filter((scenario) => scenario.status === 'failed').length;
  const blocked = all.filter((scenario) => scenario.status === 'blocked').length;
  const result = failed || blocked ? 'failed' : 'passed';
  const report = { schemaVersion: 1, result, createdAt: new Date().toISOString(), expectedScenarioCount: all.length, passedScenarioCount: passed, failedScenarioCount: failed, blockedScenarioCount: blocked, metadata, scenarios: all };
  await writeFile(join(outputDirectory, 'sanity-report.json'), `${JSON.stringify(report, null, 2)}\n`);
  const cases = all.map((scenario) => `  <testcase classname="vocle.${xml(scenario.id)}" name="${xml(scenario.name)}" time="${((scenario.durationMs || 0) / 1000).toFixed(3)}">${scenario.status === 'passed' ? '' : `<failure message="${xml(scenario.error || scenario.status)}" />`}</testcase>`).join('\n');
  await writeFile(join(outputDirectory, 'sanity-report.junit.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<testsuite name="vocle-functional-sanity" tests="${all.length}" failures="${failed + blocked}" errors="0">\n${cases}\n</testsuite>\n`);
  const sections = scenarioGroups.map((group) => {
    const casesForGroup = all.filter((scenario) => scenario.id.startsWith(`${group.id}-`));
    return `## ${group.id}\n\n${coverage[group.id] || 'Functional coverage for this journey.'}\n\n${casesForGroup.map((scenario) => `- **${scenario.id} — ${scenario.name}:** ${scenario.status.toUpperCase()}${scenario.durationMs !== undefined ? ` (${scenario.durationMs} ms)` : ''}${scenario.error ? ` — ${scenario.error}` : ''}`).join('\n')}`;
  }).join('\n\n');
  await writeFile(join(outputDirectory, 'sanity-report.md'), `# Vocle functional sanity report\n\nResult: **${result.toUpperCase()}**\n\n- Expected cases: ${all.length}\n- Passed: ${passed}\n- Failed: ${failed}\n- Blocked/missing: ${blocked}\n- Upstream SHA: ${metadata.upstreamSha || 'not recorded'}\n- Harness SHA: ${metadata.harnessSha || 'not recorded'}\n\nThis report records the coverage and result of every named sanity case; failures and blocked cases are gating.\n\n${sections}\n`);
  return report;
}
