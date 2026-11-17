import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { liveVoiceIds, selectedDeviceCases } from './device-contracts.mjs';
import { parseVoiceAttempts, voiceAudioControls, writeVoiceResults } from './voice-audio.mjs';

test('checksummed audio fixtures have their own opt-in Android cases', async () => {
  const seen = new Set();
  for (const id of liveVoiceIds) {
    assert(!selectedDeviceCases().includes(id));
    const voice = await voiceAudioControls(id, 'emulator-5554');
    assert(voice.samples.length >= 2);
    for (const sample of voice.samples) {
      assert(!seen.has(sample.sha256), 'Every live fixture must have distinct audio');
      assert.equal(sample.caseId, id);
      assert.equal(sample.format, 'WAV PCM16 mono 16000 Hz');
      seen.add(sample.sha256);
    }
  }
  assert.equal((await voiceAudioControls('FR-AST-34', 'emulator-5554')).samples[0].id, 'chat-bala');
});

test('the report preserves failures and separates unexecuted, live and file attempts', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'vocle-audio-report-'));
  const rows = [
    { layer: 'LIVE_AUDIO', sample: 'chat-bala', result: 'FAIL', attempt: 1 },
    { layer: 'LIVE_AUDIO', sample: 'chat-bala', result: 'PASS', attempt: 2 },
    { layer: 'LIVE_AUDIO', sample: 'chat-bela', result: 'NOT_EXECUTED', attempt: 1 },
  ];
  const log = rows.map(row => `I/flutter: VOCLE_VOICE_ATTEMPT ${JSON.stringify(row)}`).join('\n');
  assert.deepEqual(parseVoiceAttempts(log), rows);
  const started = { layer: 'LIVE_AUDIO', sample: 'chat-bela', attempt: 2 };
  const incomplete = parseVoiceAttempts(`${log}\nVOCLE_VOICE_ATTEMPT_START ${JSON.stringify(started)}`);
  assert.equal(incomplete.at(-1).failureCategory, 'attempt_interrupted');
  try {
    const file = { layer: 'PRERECORDED_FILE', sample: 'chat-bala', result: 'PASS' };
    await writeVoiceResults(dir, [
      { id: 'FR-AST-31', status: 'FAIL' },
      { id: 'FR-AST-32', status: 'ERROR', error: 'emulator offline' },
      { id: 'FR-AST-34', status: 'PASS', evidence: [JSON.stringify(file)] },
    ], [{ id: 'FR-AST-31', audioAttempts: parseVoiceAttempts(log) }]);
    const report = JSON.parse(await readFile(join(dir, 'voice-assistant-attempts.json'), 'utf8'));
    assert.equal(report.attempts.length, 4);
    assert.deepEqual(report.rates, {
      LIVE_AUDIO: { attempted: 2, passed: 1, successRate: 0.5 },
      PRERECORDED_FILE: { attempted: 1, passed: 1, successRate: 1 },
    });
    assert.match(await readFile(join(dir, 'voice-assistant-attempts.md'), 'utf8'),
      /FR-AST-32 .* no attempt evidence/);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});
