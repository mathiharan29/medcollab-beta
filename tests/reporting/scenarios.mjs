// Catalog-derived scenario metadata. Definitions describe the intended procedure,
// never an observation. No AI or remote service runs during report generation.
import { readFile, readdir } from 'node:fs/promises';
import { join, relative } from 'node:path';
import { createHash } from 'node:crypto';

export const hash = value => createHash('sha256').update(value).digest('hex');
export const fixtureProfiles = {
  U: 'Disposable loopback MongoDB; fictional doctors A–E. A owns space S, B/C are members, D is unrelated and opts into requests only when specified, E defaults to opt-out. Create fresh phones for authentication boundaries. Use captured test-owned OTP/provider responses, never a real SMS service.',
  C: 'Use U, default general/emergency/academics channels, public X and private Y (A only), accepted A/B DM, A/B/C group, distinct roots r1/r2 and reply t1. Component prerequisites may be seeded; journey steps must use application APIs.',
  H: 'Use U+C. Create a synthetic A→B handoff in S/general for 2030-01-02 night shift. Patient T1/Synthetic/Case Alpha, stable, review marker, pending check marker; preserve returned patient and handoff IDs. No real patient data.',
  N: 'Use C with A/B sockets and captured fake push transport. B is outside the channel unless specified. Clear notifications only during fixture setup. Use dated synthetic entries for pagination.',
  M: 'Use U and valid tiny PNG/PDF/MP4 bytes with unique filenames and SHA-256. Use local storage and test-owned provider transport with no egress. Inert external URLs are metadata; do not retrieve them.',
  F0: 'Isolated Flutter dependencies, authenticated synthetic A where required, fake API/repositories/socket streams, controlled clocks and fresh preferences/secure-storage doubles. Recreate components for persistence assertions.',
  D0: 'Android emulator with the dedicated test build, disposable real Express/MongoDB backend, fictional identities and injected OS/provider inputs. Restart without deleting storage for persistence checks. Follow the device runner prerequisites; production-configured release builds are excluded.',
};
const context = {
  AUTH: 'A doctor signs in or restores a session.', PRO: 'A doctor edits their profile and preferences.', DISC: 'A doctor looks for a colleague.',
  SPC: 'Doctors create and manage membership in a department space.', CH: 'Doctors access and manage the channels they are permitted to use.',
  REQ: 'Doctors request permission to start a private conversation.', DM: 'Doctors exchange private or group conversations.', MSG: 'A doctor sends or changes a channel message.',
  THR: 'Doctors follow replies to a message and find them in Needl.', SOC: 'Doctors react, pin or acknowledge reading messages.',
  NOT: 'A doctor receives and manages personal notifications.', PUSH: 'A doctor receives an alert or manages notification registration.',
  RT: 'Doctors communicate while connections and presence change.', SRCH: 'A doctor searches for accessible colleagues and clinical collaboration resources.',
  HOF: 'One doctor hands a synthetic patient case to another doctor.', MED: 'A doctor attaches, views or removes a synthetic file.',
  SUP: 'A doctor submits support information or a synthetic developer tool is exercised.', RUN: 'The application recovers from a controlled runtime failure.',
  JRN: 'Doctors complete a collaboration journey across several features.', NAV: 'A doctor navigates between screens and restores an interrupted session.',
  HOME: 'A doctor opens their workspace and dashboard.', OFF: 'A doctor restores locally retained collaboration state.', SAVE: 'A doctor returns to a saved message.', LINK: 'A doctor opens an invitation or notification link.',
};
const overrides = {
  'message-requests-02': 'Doctor A sends a request to fictional Doctor D, who has opted in. Doctor D accepts it. Both doctors should see the same private conversation, and Doctor A should receive an acceptance notification naming that conversation.',
  'FR-REQ-05': 'A doctor accepts a private-message request while the test deliberately interrupts database work after the request-state write. Reload the request and conversation, then retry. The product must decide how an accepted request without a conversation should recover; a successful HTTP response alone does not prove recovery.',
  'FR-PUSH-05': 'A doctor receives several synthetic notifications in one channel. The Android notification shade should group them, a tap should open that exact conversation, and a reply submitted with the injected native token should persist exactly once.',
};

async function files(directory) {
  const entries = await readdir(directory, { withFileTypes: true }).catch(() => []);
  const all = [];
  for (const e of entries) {
    if (['support', 'fakes', 'node_modules', 'output'].includes(e.name)) continue;
    const p = join(directory, e.name);
    if (e.isDirectory()) all.push(...await files(p));
    else if (/\.(mjs|js|dart)$/.test(e.name)) all.push(p);
  }
  return all.sort();
}

export async function scenarioMetadata(root) {
  const catalog = JSON.parse(await readFile(join(root, 'tests/functional-regression/catalog.json'), 'utf8'));
  const definitions = [];
  for (const directory of ['tests/sanity/src', 'tests/functional-regression/suites', 'medcollab-app/test/functional_regression', 'medcollab-app/integration_test/functional_regression']) {
    for (const path of await files(join(root, directory))) {
      const text = (await readFile(path, 'utf8')).replaceAll('\r\n', '\n');
      definitions.push({ path: relative(root, path).replaceAll('\\', '/'), text });
    }
  }
  return catalog.cases.map(c => {
    const eligible = definitions.filter(d => c.coverage === 'EXISTING' ? d.path.startsWith('tests/sanity/') : c.tier === 'B' ? d.path.includes('/suites/') : c.tier === 'F' ? d.path.includes('/test/') : d.path.includes('/integration_test/'));
    const hits = eligible.flatMap(d => {
      // Locate declaration/string literals, excluding unquoted dependency mentions.
      const escaped = c.id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const found = new RegExp("['\"`]" + escaped + "(?=['\"`:\\s])").exec(d.text);
      if (!found) return [];
      const start = d.text.lastIndexOf('\n', found.index) + 1;
      const remaining = d.text.slice(found.index + c.id.length + 1);
      const next = /\n\s*(?:id:\s*['"]FR-|await scenario\(['"]|test(?:Widgets)?\(\s*['"]FR-)/.exec(remaining);
      const end = next ? found.index + c.id.length + 1 + next.index : d.text.length;
      return [{ path: d.path, line: d.text.slice(0, start).split('\n').length, excerpt: d.text.slice(start, end).slice(0, 18000), fileHash: hash(d.text) }];
    });
    const actions = c.actions.split(/;\s*/).map(s => s.trim()).filter(Boolean);
    return {
      ...c, scenario: overrides[c.id] || `${context[c.module] || 'A doctor uses ' + c.moduleName + '.'} Scenario: ${c.actions}.`,
      prerequisites: fixtureProfiles[c.fixtureProfile] || `Use catalog fixture ${c.fixtureProfile}; see ${catalog.source}:${c.catalogLine}.`,
      steps: actions.map((action, index) => ({ number: index + 1, action, expected: actions.length === 1 || index === actions.length - 1 ? c.expected : 'Check the relevant constraint in the expected-result specification and executable definition below; the legacy runner does not emit per-step observations.' })),
      boundaries: c.expected,
      definitions: hits,
      definitionFingerprint: hash(JSON.stringify({ ...c, definitions: hits.map(d => ({ path: d.path, fileHash: d.fileHash })) })),
      reproduction: c.tier === 'B' ? 'API/environment reproduction, not an observed UI journey. Run the owning module or retained sanity runner against a disposable target; literal routes, payloads, roles, boundary variants and DB/socket assertions appear in the definition below. Subscribe before triggering socket events. Do not replay mutations until green.' : c.tier === 'F' ? 'Component reproduction: run the owning Flutter test with Flutter 3.29.3 and the locked dependencies. Repository and platform inputs are controlled fakes, not real backend/provider delivery. Follow the exact widget/service calls in the definition.' : 'Native Android reproduction: follow docs/VOCLE_FUNCTIONAL_REGRESSION_DEVICE_RUNNER.md; select this ID with --ids. Some provider inputs require the injected test channels and cannot be reproduced manually on an ordinary release build.',
      limitations: c.tier === 'B' ? 'HTTP/MongoDB/Socket.IO scope only; no rendered Flutter UI, physical device or real provider delivery is proved. A failed assertion may stop later steps.' : c.tier === 'F' ? 'Flutter component scope with fake repositories/platform inputs; no backend, device or real provider correctness is proved. A failed assertion may stop later steps.' : 'Android debug emulator scope with synthetic backend/provider inputs; no iOS, physical hardware, carrier delivery or production release-build claim. Unreached journey phases are not credited.',
    };
  });
}
