import assert from 'node:assert/strict';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

const audio = new URL('../voice-audio/', import.meta.url);
const plan = JSON.parse(await readFile(new URL('digital-plan.json', audio), 'utf8'));
const manifest = JSON.parse(await readFile(new URL('manifest.json', audio), 'utf8'));
const fixtures = new Map(manifest.map(row => [row.id, row]));

export const digitalSuiteCaseIds = [...new Set(plan.map(entry => entry.caseId))];

export function requestedDigitalAttempts(scope, repetitions) {
  assert.ok(['smoke', 'full'].includes(scope));
  assert.ok(Number.isInteger(repetitions) && repetitions >= 1 && repetitions <= 5);
  return plan.filter(entry => scope === 'full' || entry.smoke).flatMap(entry => {
    const fixture = fixtures.get(entry.sample);
    assert.ok(fixture, 'Digital plan references an unknown WAV');
    const count = scope === 'full' && entry.repeat ? repetitions : 1;
    return Array.from({ length: count }, (_, index) => ({
      ...entry, attempt: index + 1, sha256: fixture.sha256, phrase: fixture.phrase,
      intent: fixture.expectedIntent, expectedAction: fixture.expectedResult,
    }));
  });
}

export function configuredDigitalAttempts() {
  return requestedDigitalAttempts(process.env.VOCLE_AUDIO_SUITE_SCOPE ?? 'full',
    Number(process.env.VOCLE_DIGITAL_REPETITIONS ?? '2'));
}

const normalize = text => text.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim()
  .replace(/\bdr\b/g, 'doctor').replace(/\bhand off\b/g, 'handoff')
  .replace(/\bseven\b/g, '7').replace(/\btwelve\b/g, '12');
const keyOf = row => `${row.sample}:${row.attempt}`;

export async function verifyDigitalAttempts(directory, fingerprint) {
  const read = file => readFile(join(directory, file), 'utf8').then(JSON.parse);
  const [prepared, probe] = await Promise.all([read('suite.json'), read('probe.json')]);
  const expected = configuredDigitalAttempts();
  assert.match(prepared.run, /^[a-f0-9-]{36}$/);
  assert.equal(prepared.attempts.length, expected.length, 'Prepared attempts differ from the committed plan');
  const planned = new Map(prepared.attempts.map(row => [keyOf(row), row]));
  assert.equal(planned.size, expected.length);
  const sameRun = probe.filter(row => row.run === prepared.run);
  const availability = sameRun.filter(row => row.event === 'availability');
  assert.equal(availability.length, 1);
  assert.equal(availability[0].fingerprint, fingerprint);
  assert.equal(availability[0].sdk, 35);
  assert.equal(availability[0].defaultAvailable, true);
  const sessions = sameRun.filter(row => row.event === 'session');
  const byAttempt = new Map(sessions.map(row => [keyOf(row), row]));
  assert.equal(byAttempt.size, sessions.length, 'Duplicate native result for the same attempt');
  for (const native of sessions) assert.ok(planned.has(keyOf(native)), 'Unexpected native audio attempt');
  return expected.map(entry => {
    const preparedEntry = planned.get(keyOf(entry));
    assert.equal(preparedEntry?.sha256, entry.sha256);
    assert.equal(preparedEntry.caseId, entry.caseId);
    assert.ok(Number.isSafeInteger(preparedEntry.bytes) && preparedEntry.bytes > 0);
    assert.match(preparedEntry.pcmSha256, /^[0-9a-f]{64}$/);
    const native = byAttempt.get(keyOf(entry));
    if (!native) return { ...entry, native: null };
    assert.equal(native.fingerprint, fingerprint);
    assert.equal(native.sha256, entry.sha256);
    assert.equal(native.engine, 'default');
    assert.equal(native.source, 'regular-file');
    assert.equal(native.profile, 'online-allowed');
    assert.equal(native.bytesOffered, preparedEntry.bytes);
    assert.equal(typeof native.transcript, 'string');
    assert.ok(Number.isSafeInteger(native.durationMs) && native.durationMs >= 0);
    const delivered = native.regularFilePosition === native.bytesOffered;
    const final = native.error === 0 && ['results', 'segment-end'].includes(native.terminal);
    const recognized = delivered && final && native.transcript.trim().length > 0;
    const transcriptMatched = recognized && normalize(native.transcript) === normalize(entry.phrase);
    const silencePassed = delivered && native.transcript === '' && (final || [6, 7].includes(native.error));
    return { ...entry, native, delivered, recognized, transcriptMatched, silencePassed,
      pcmSha256: preparedEntry.pcmSha256 };
  });
}

export async function writeDigitalReport(directory, cases, phases, voiceAttempts) {
  const expected = configuredDigitalAttempts();
  const completed = new Map(voiceAttempts.map(row => [`${row.id}:${keyOf(row)}`, row]));
  const appAttempts = expected.map(entry => {
    const found = completed.get(`${entry.caseId}:${keyOf(entry)}`);
    if (found) return found;
    const device = cases.find(row => row.id === entry.caseId);
    const recordedPhase = phases.some(row => row.id === entry.caseId);
    return {
      id: entry.caseId, sample: entry.sample, attempt: entry.attempt, sha256: entry.sha256,
      layer: 'AUDIO_TO_ACTION', intendedCommand: entry.phrase, expectedIntent: entry.intent,
      expectedTarget: null, expectedFixtureTarget: entry.target ?? null, expectedAction: entry.expectedAction,
      recognizedTranscript: null, parsedIntent: null, resolvedTarget: null, actualAction: null,
      recognitionError: null, recognitionSuccess: null, transcriptMatched: null,
      intentCorrect: null, entityCorrect: null, durationMs: null,
      result: recordedPhase ? 'NOT_EXECUTED' : 'BLOCKED', failureCategory: 'app_setup',
      error: device?.error ?? 'No app attempt was recorded',
    };
  });
  const existingSmoke = voiceAttempts.filter(row => row.id === 'FR-AST-34');
  const attempts = [...existingSmoke, ...appAttempts].map(row => ({
    ...row, result: row.result === 'ERROR' ? 'BLOCKED' : row.result,
  }));
  const count = field => ({ correct: attempts.filter(row => row[field] === true).length,
    measured: attempts.filter(row => typeof row[field] === 'boolean').length });
  const metrics = {
    nonemptyFinalSpeech: count('recognitionSuccess'),
    intendedWording: count('transcriptMatched'),
    correctIntent: count('intentCorrect'),
    correctEntity: count('entityCorrect'),
    endToEnd: { correct: attempts.filter(row => row.result === 'PASS').length, measured: attempts.length },
  };
  const counts = Object.fromEntries(['PASS', 'FAIL', 'BLOCKED', 'NOT_EXECUTED'].map(result =>
    [result, attempts.filter(row => row.result === result).length]));
  const cell = value => String(value == null ? '—' : typeof value === 'object' ? JSON.stringify(value) : value)
    .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('|', '&#124;').replace(/\s+/g, ' ');
  const lines = [
    '# Android digital audio to Vocle', '',
    ...Object.entries(metrics).map(([name, metric]) => `- ${name}: ${metric.correct}/${metric.measured}`),
    '', '| Case | Sample/attempt | Expected speech | Android final | Native error | Expected intent | Actual intent | Expected target | Actual target | Expected action | Observed action | Result | ms |',
    '|---|---|---|---|---|---|---|---|---|---|---|---|---|',
    ...attempts.map(row => `| ${[
      row.id, `${row.sample} #${row.attempt ?? 1}`, row.intendedCommand, row.recognizedTranscript,
      row.recognitionError, row.expectedIntent, row.parsedIntent, row.expectedTarget, row.resolvedTarget,
      row.expectedAction, row.actualAction, [row.result, row.failureCategory].filter(Boolean).join(' / '),
      row.durationMs,
    ].map(cell).join(' | ')} |`), '',
    ...attempts.filter(row => row.error).map(row =>
      `- ${row.id} ${row.sample} #${row.attempt ?? 1}: ${cell(row.error)}`), '',
  ];
  await Promise.all([
    writeFile(join(directory, 'digital-audio-attempts.json'), JSON.stringify({ counts, metrics, attempts }, null, 2) + '\n'),
    writeFile(join(directory, 'digital-audio-attempts.md'), lines.join('\n')),
  ]);
}
