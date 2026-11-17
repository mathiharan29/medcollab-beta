import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

export const digitalSampleId = 'chat-with-alex';
export const androidExecutionMode = () =>
  process.env.GITHUB_RUN_ID && process.env.VOCLE_DIGITAL_SOURCE_EVIDENCE ? 'HOSTED' : 'LOCAL_ONLY';

const normalize = text => text.toLowerCase().replace(/[^a-z]+/g, ' ').trim().replace(/\bdr\b/g, 'doctor');

export async function verifiedDigitalTranscript(directory, sample, runningFingerprint) {
  const read = name => readFile(join(directory, name), 'utf8');
  const [fixture, rows, instrument] = await Promise.all([
    read('fixture.json').then(JSON.parse), read('probe.json').then(JSON.parse), read('instrumentation.txt'),
  ]);
  assert.match(instrument, /^AUDIO_SOURCE_PROVEN=true$/m, 'Native recognition probe did not pass');
  const [availability] = rows.filter(row => row.event === 'availability');
  assert.equal(fixture.sample, digitalSampleId);
  assert.equal(fixture.sample, sample.id);
  assert.equal(fixture.wavSha256, sample.sha256);
  assert.equal(fixture.pcmBytes, fixture.frames * 2);
  assert.equal(fixture.pcmBytes, availability?.pcmBytes);
  assert.equal(fixture.pcmBytes, fixture.silenceControlBytes);
  assert.equal(fixture.rate, 16000);
  assert.equal(fixture.channels, 1);
  assert.equal(fixture.encoding, 'signed little-endian PCM16');
  assert.equal(availability.sample, sample.id);
  assert.equal(availability.fingerprint, runningFingerprint, 'Probe and app must run on the same test image');
  const fromFile = rows.filter(row => row.engine === 'default' &&
    row.profile === 'online-allowed' && row.source === 'regular-file');
  const comparisons = fromFile.filter(row => row.event === 'comparison');
  assert.equal(comparisons.length, 1);
  assert.equal(comparisons[0].sourceProven, true, 'Regular-file audio and silence did not pass');
  const sessions = fromFile.filter(row => row.event === 'session');
  assert.equal(sessions.length, 2);
  const speech = sessions.find(row => row.input === 'speech');
  const silence = sessions.find(row => row.input === 'silence');
  for (const row of [speech, silence]) {
    assert.equal(row?.bytesOffered, fixture.pcmBytes);
    assert.equal(row.regularFilePosition, fixture.pcmBytes);
  }
  assert.equal(speech.error, 0);
  assert.equal(normalize(speech.transcript), normalize(sample.phrase));
  assert.equal(silence.transcript, '');
  assert.ok(silence.error === 7 || silence.error === 6 || (silence.error === 0 &&
    ['results', 'segment-end'].includes(silence.terminal)));
  return {
    sample: sample.id, transcript: speech.transcript, phrase: sample.phrase,
    wavSha256: fixture.wavSha256, pcmSha256: fixture.pcmSha256,
    engine: speech.engine, profile: speech.profile, source: speech.source,
    pcmBytes: fixture.pcmBytes, fingerprint: runningFingerprint,
  };
}
