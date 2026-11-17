import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const audio = new URL('../voice-audio/', import.meta.url);
const manifest = JSON.parse(await readFile(new URL('manifest.json', audio), 'utf8'));
export const voiceAudioPaths = ['manifest.json', 'replay.py', ...manifest.map(sample => sample.file)]
  .map(file => `tests/functional-regression/voice-audio/${file}`);
const run = promisify(execFile);

export async function voiceAudioControls(caseId, serial) {
  const deviceCase = manifest.some(sample => sample.caseId === caseId);
  const prerecorded = caseId === 'FR-AST-34';
  if (!deviceCase && !prerecorded) return null;
  const samples = manifest.filter(sample => prerecorded ? sample.id === 'chat-bala' : sample.caseId === caseId);
  const repetitions = Number(process.env.VOCLE_VOICE_REPETITIONS ?? '3');
  assert.ok(Number.isInteger(repetitions) && repetitions >= 1 && repetitions <= 10,
    'VOCLE_VOICE_REPETITIONS must be an integer in 1–10');
  for (const sample of samples) {
    assert.match(sample.file, /^[a-z-]+\.wav$/);
    const data = await readFile(new URL(sample.file, audio));
    assert.equal(createHash('sha256').update(data).digest('hex'), sample.sha256);
  }
  async function replay(id, { probe = false } = {}) {
    const sample = samples.find(row => row.id === id) ||
      (probe && manifest.find(row => row.id === id));
    assert.ok(sample, 'Audio sample is outside the selected case');
    try {
      const discovery = process.env.VOCLE_EMULATOR_DISCOVERY;
      if (!discovery) return { delivered: false, error: 'Missing VOCLE_EMULATOR_DISCOVERY' };
      const { stdout } = await run(process.env.VOCLE_PYTHON || 'python', [
        fileURLToPath(new URL('replay.py', audio)), discovery, serial,
        fileURLToPath(new URL(sample.file, audio)),
      ], { timeout: 15000, windowsHide: true });
      return { ...JSON.parse(stdout), delivered: true };
    } catch (error) {
      const safe = String(error.stderr).match(/injectAudio RPC [A-Z_]+/)?.[0];
      return { delivered: false, error: safe || 'Audio replay helper failed' };
    }
  }
  return {
    samples, repetitions,
    replay,
    async file() {
      assert.ok(prerecorded);
      return { wav: (await readFile(new URL(samples[0].file, audio))).toString('base64') };
    },
  };
}

export function parseVoiceAttempts(log) {
  const rows = new Map();
  for (const [, start, json] of log.matchAll(/VOCLE_VOICE_ATTEMPT(_START)? (\{[^\r\n]+\})/g)) {
    try {
      const row = JSON.parse(json);
      const key = JSON.stringify([row.layer, row.sample, row.attempt]);
      rows.set(key, start ? { ...row, result: 'ERROR', failureCategory: 'attempt_interrupted',
        error: 'Android phase ended before this attempt reported an outcome' } : row);
    } catch { /* the native case record still preserves completed attempts */ }
  }
  return [...rows.values()];
}

export async function writeVoiceResults(directory, cases, phases) {
  const attempts = cases.flatMap(({ id, evidence = [] }) => {
    const fromCase = evidence.flatMap(value => {
      try {
        const row = JSON.parse(value);
        return row.layer && row.sample ? [row] : [];
      } catch { return []; }
    });
    const fallback = phases.filter(phase => phase.id === id).flatMap(phase => phase.audioAttempts ?? []);
    return (fromCase.length ? fromCase : fallback).map(row => ({ ...row, id }));
  });
  const rates = Object.fromEntries(['LIVE_AUDIO', 'PRERECORDED_FILE'].map(layer => {
    const attempted = attempts.filter(row => row.layer === layer && row.result !== 'NOT_EXECUTED');
    const passed = attempted.filter(row => row.result === 'PASS').length;
    return [layer, { attempted: attempted.length, passed, successRate: attempted.length ? passed / attempted.length : null }];
  }));
  const samples = manifest.filter(sample => cases.some(row => row.id === sample.caseId) ||
    (sample.id === 'chat-bala' && cases.some(row => row.id === 'FR-AST-34')));
  const cell = value => String(value == null ? '—' : typeof value === 'object' ? JSON.stringify(value) : value)
    .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('|', '&#124;').replace(/\s+/g, ' ');
  const observed = attempts.map(row => [row.id, row.layer, `${row.sample} #${row.attempt ?? 1}`,
    row.intendedCommand, row.recognizedTranscript, row.resolvedTarget, row.expectedAction,
    row.actualAction ?? (row.actualRoute ? `Route at failure: ${row.actualRoute}` : null),
    [row.result, row.failureCategory].filter(Boolean).join(' / ')]);
  for (const row of cases.filter(item => !attempts.some(attempt => attempt.id === item.id))) {
    for (const sample of samples.filter(sample => sample.caseId === row.id ||
      (row.id === 'FR-AST-34' && sample.id === 'chat-bala'))) {
      observed.push([row.id, row.id === 'FR-AST-34' ? 'PRERECORDED_FILE' : 'LIVE_AUDIO',
        sample.id, sample.phrase, null, null, sample.expectedResult, null,
        `${row.status}, no attempt evidence`]);
    }
  }
  const text = [
    '# Voice Assistant Android attempts', '',
    ...Object.entries(rates).map(([layer, rate]) => rate.attempted
      ? `- ${layer}: ${rate.passed}/${rate.attempted} passed (${(rate.successRate * 100).toFixed(1)}%).`
      : `- ${layer}: No recorded attempt. Success rate unavailable.`),
    '', '| Test ID | Layer | Audio sample | Intended command | Recognized transcript | Resolved target | Expected action | Actual action | Result |',
    '|---|---|---|---|---|---|---|---|---|',
    ...observed.map(row => `| ${row.map(cell).join(' | ')} |`),
    '', ...cases.filter(row => row.error).map(row => `- ${row.id} ${row.status} — ${cell(row.error)}`), '',
  ].join('\n');
  await Promise.all([
    writeFile(join(directory, 'voice-assistant-attempts.json'), JSON.stringify({ rates, attempts, samples }, null, 2) + '\n'),
    writeFile(join(directory, 'voice-assistant-attempts.md'), text),
  ]);
}
