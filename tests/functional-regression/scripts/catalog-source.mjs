import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';

const root = resolve(fileURLToPath(new URL('../../../', import.meta.url)));
const catalogPath = resolve(root, 'docs/VOCLE_FUNCTIONAL_REGRESSION_TEST_CATALOG.md');

const modules = [
  ['AUTH', 'Authentication/session', 'U'], ['PRO', 'Profiles/preferences', 'U'],
  ['DISC', 'Discovery/lookup', 'U'], ['SPC', 'Spaces/invitations/membership', 'U'],
  ['CH', 'Channels', 'C'], ['REQ', 'Message requests/consent', 'U'],
  ['DM', 'Direct/group conversations', 'C'], ['MSG', 'Root messaging', 'C'],
  ['THR', 'Threads/Needl', 'C'], ['SOC', 'Reactions/pins/read receipts', 'C'],
  ['HOF', 'Handoffs/patients', 'H'], ['MED', 'Media', 'M'],
  ['NOT', 'Notification inbox', 'N'], ['PUSH', 'Push/device-token lifecycle', 'N'],
  ['RT', 'Realtime/presence', 'N'], ['SRCH', 'Global search', 'C'],
  ['SUP', 'Support/developer tools', 'U'], ['NAV', 'Startup/navigation/lifecycle', 'F0'],
  ['OFF', 'Composer/offline state', 'F0'], ['SAVE', 'Saved/recent items', 'F0'],
  ['HOME', 'Home/dashboard', 'F0'], ['LINK', 'Forwarding/invites/deep links', 'F0'],
  ['RUN', 'Runtime/error recovery', 'U'], ['JRN', 'Cross-feature journeys', 'U'],
];

export const moduleNames = Object.fromEntries(modules.map(([code, name]) => [code, name]));
const moduleFixtures = Object.fromEntries(modules.map(([code, , fixture]) => [code, fixture]));

function oldModule(id) {
  if (id.startsWith('authentication-and-profiles-')) return id.endsWith('-05') ? 'PRO' : 'AUTH';
  if (id.startsWith('spaces-and-invitations-')) return 'SPC';
  if (id.startsWith('channels-')) return 'CH';
  if (id === 'messaging-and-needl-04') return 'THR';
  if (id === 'messaging-and-needl-06') return 'SOC';
  if (id.startsWith('messaging-and-needl-')) return 'MSG';
  if (id.startsWith('message-requests-')) return 'REQ';
  if (id.startsWith('direct-and-group-conversations-')) return 'DM';
  for (const [prefix, code] of Object.entries({ handoffs: 'HOF', media: 'MED', notifications: 'NOT', 'realtime-and-availability': 'RT', search: 'SRCH', support: 'SUP', startup: 'RUN' })) {
    if (id.startsWith(`${prefix}-`)) return code;
  }
  throw new Error(`Unmapped retained ID ${id}`);
}

const oldDependencies = {
  'message-requests-02': ['message-requests-01'],
  'direct-and-group-conversations-01': ['message-requests-02'],
  'direct-and-group-conversations-02': ['message-requests-02'],
  'direct-and-group-conversations-03': ['message-requests-02'],
  'direct-and-group-conversations-05': ['message-requests-02'],
  'handoffs-04': ['handoffs-03'],
  'handoffs-05': ['handoffs-04'],
};

function parseRelatedSanity(value) {
  const partial = value.match(/partial:\s*([^|]+)/i)?.[1] || '';
  const results = [];
  let prefix;
  for (const raw of partial.split(',').map((s) => s.trim())) {
    if (!raw) continue;
    const full = raw.match(/^([a-z][a-z-]+)-(\d{2})$/);
    if (full) { prefix = full[1]; results.push(raw); }
    else if (/^-\d{2}$/.test(raw) && prefix) results.push(`${prefix}${raw}`);
    else if (/^(widget_test\.dart|draft_message_service_test\.dart|dashboard_preferences_service_test\.dart|phone_utils_test\.dart|request\/DM sanity chain)/.test(raw)) continue;
    else throw new Error(`Unrecognized partial reference: ${raw}`);
  }
  return results;
}

export async function parseCatalog() {
  const lines = (await readFile(catalogPath, 'utf8')).split(/\r?\n/);
  const cases = [];
  let section = '';
  let source = '';
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith('### ')) { section = line.slice(4); source = ''; }
    else if (line.startsWith('Preconditions ') || line.startsWith('U; ') || line.startsWith('C; ') || line.startsWith('H; ') || line.startsWith('N; ') || line.startsWith('M; ') || line.startsWith('F0; ') || line.startsWith('D0; ') || line.startsWith('Sources: ')) source = line;
    if (!/^\| (FR-[A-Z]+-\d{2}|[a-z][a-z-]+-\d{2}) \|/.test(line)) continue;
    const parts = line.split('|').slice(1, -1).map((s) => s.trim());
    const id = parts[0];
    const retained = !id.startsWith('FR-');
    const module = retained ? oldModule(id) : id.match(/^FR-([A-Z]+)-/)[1];
    if (!moduleNames[module]) throw new Error(`Unknown module ${module} at line ${i + 1}`);
    const tierPriority = retained ? ['B', 'P0'] : parts[3]?.split('/');
    if (!tierPriority || tierPriority.length !== 2) throw new Error(`Invalid tier/priority at line ${i + 1}`);
    const questionIds = [...new Set((retained ? '' : `${parts[2]} ${parts[4]}`).match(/\bQ(?:1[0-4]|[1-9])\b/g) || [])];
    cases.push({
      id, module, moduleName: moduleNames[module], tier: tierPriority[0], priority: tierPriority[1],
      coverage: retained ? 'EXISTING' : 'NEW', fixtureProfile: tierPriority[0] === 'F' ? 'F0' : tierPriority[0] === 'D' ? 'D0' : moduleFixtures[module],
      title: parts[1].split(';')[0], actions: parts[1], expected: retained ? parts[1] : parts[2],
      sourceReference: retained ? section : `${section}: ${source}`,
      catalogLine: i + 1, questionIds,
      relatedSanityIds: retained ? [] : parseRelatedSanity(parts[4] || ''),
      dependencies: retained ? (oldDependencies[id] || []) : [],
    });
  }
  return cases;
}
