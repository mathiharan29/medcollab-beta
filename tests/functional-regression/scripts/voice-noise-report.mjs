import { writeFile } from 'node:fs/promises';
import { join } from 'node:path';

export function wordErrors(reference, hypothesis) {
  let previous = Array.from({ length: hypothesis.length + 1 }, (_, index) => index);
  for (const [i, expected] of reference.entries()) {
    const current = [i + 1];
    for (const [j, actual] of hypothesis.entries()) {
      current.push(Math.min(previous[j + 1] + 1, current[j] + 1,
        previous[j] + Number(expected !== actual)));
    }
    previous = current;
  }
  return previous.at(-1);
}

const count = (yes, total) => ({ yes, total, rate: total ? yes / total : null });
const tokens = text => text ? text.split(' ') : [];

function measure(rows) {
  const speech = rows.filter(row => row.referenceWords > 0 &&
    typeof row.recognitionSuccess === 'boolean');
  const measured = rows.filter(row => typeof row.safetyPassed === 'boolean');
  const indicator = (field, items = rows) => count(items.filter(row => row[field] === true).length,
    items.filter(row => typeof row[field] === 'boolean').length);
  const latency = rows.map(row => row.recognitionLatencyMs).filter(Number.isFinite).sort((a, b) => a - b);
  const percentile = p => latency.length ? latency[Math.ceil(latency.length * p) - 1] : null;
  return {
    attempts: rows.length,
    recognition: indicator('recognitionSuccess', speech),
    exact: indicator('transcriptMatched', speech),
    wer: count(speech.reduce((sum, row) => sum + row.wordErrors, 0),
      speech.reduce((sum, row) => sum + row.referenceWords, 0)),
    intent: indicator('intentCorrect'),
    entity: indicator('entityCorrect'),
    endToEnd: indicator('actionSuccess', rows.filter(row => row.referenceWords > 0)),
    incorrectTarget: indicator('incorrectTarget', rows.filter(row => row.expectedTarget != null)),
    hazardousProposal: indicator('hazardousProposal'),
    safetyVerified: indicator('safetyPassed'),
    incorrectAction: indicator('incorrectAction'),
    latencyMs: { n: latency.length, median: percentile(0.5), p90: percentile(0.9) },
    gates: { verified: measured.filter(row => row.safetyPassed).length,
      failed: rows.filter(row => !row.safetyPassed || (row.classification === 'functional' && row.result !== 'PASS')).length },
  };
}

export async function writeNoiseReport(directory, expected, attempts, normalize) {
  const observations = new Map(attempts.map(row => [`${row.sample}:${row.attempt}`, row]));
  const rows = expected.map(spec => {
    const observed = observations.get(`${spec.sample}:${spec.attempt}`);
    const reference = tokens(normalize(spec.phrase));
    const hypothesis = tokens(observed?.recognitionSuccess ? normalize(observed.recognizedTranscript) : '');
    return { ...spec, id: spec.caseId, ...observed, referenceWords: reference.length,
      wordErrors: reference.length ? wordErrors(reference, hypothesis) : null };
  });
  const group = key => [...Map.groupBy(rows, key)].map(([group, attempts]) => ({ group, ...measure(attempts) }));
  const perCondition = group(row => `${row.condition} ${row.snrDb ?? ''}`.trim());
  const perSample = group(row => row.sample);
  const perCommand = group(row => `${row.action} / ${row.condition} ${row.snrDb ?? ''}`.trim());
  const paired = perSample.flatMap(row => {
    const entry = expected.find(item => item.sample === row.group);
    const clean = perSample.find(item => item.group === `${entry.baseSample}-matched-clean`);
    if (entry.snrDb == null || !clean || entry.masker) return [];
    const delta = (a, b) => a == null || b == null ? null : a - b;
    return [{ base: entry.baseSample, variant: row.group, clean: clean.group,
      werDelta: delta(row.wer.rate, clean.wer.rate),
      actionRateDelta: delta(row.endToEnd.rate, clean.endToEnd.rate) }];
  });
  const counts = Object.fromEntries(['PASS', 'FAIL', 'BLOCKED', 'NOT_EXECUTED'].map(result =>
    [result, rows.filter(row => row.result === result).length]));
  const formatRate = field => field.total ? `${field.yes}/${field.total} (${Math.round(100 * field.rate)}%)` : '—';
  const cleanCell = value => String(value ?? '—').replace(/[\r\n]+/g, ' ').replaceAll('|', '&#124;');
  const lines = ['# Vocle speech reliability', '',
    'Fixture outcomes and functional/safety gates are separate. For WER, the denominator is intended words. Latency is start to terminal callback.', '',
    ...Object.entries(counts).map(([result, n]) => `- ${result} ${n}`),
    '', '| Condition | Attempts | Final speech | Exact | WER | Intent | Entity | Expected outcome | Incorrect target | Hazardous proposal | Incorrect action | Median ms |',
    '|---|---:|---|---|---|---|---|---|---|---|---|---:|',
    ...perCondition.map(row => '| ' + [row.group, row.attempts,
      ...['recognition', 'exact', 'wer', 'intent', 'entity', 'endToEnd', 'incorrectTarget', 'hazardousProposal', 'incorrectAction'].map(key => formatRate(row[key])),
      row.latencyMs.median ?? '—'].join(' | ') + ' |'),
    '', '| Fixture / attempt | Actual transcript | Intent | Target ID | Postcondition | Hazard | Result |',
    '|---|---|---|---|---|---|---|',
    ...rows.map(row => '| ' + [`${row.sample} #${row.attempt}`, row.recognizedTranscript,
      row.parsedIntent, row.resolvedTarget, row.actualAction && JSON.stringify(row.actualAction),
      row.hazardousProposal, row.result].map(cleanCell).join(' | ') + ' |'), ''];
  await Promise.all([
    writeFile(join(directory, 'voice-noise-report.json'),
      JSON.stringify({ counts, overall: measure(rows), perCondition, perCommand, perSample, paired, attempts: rows }, null, 2) + '\n'),
    writeFile(join(directory, 'voice-noise-report.md'), lines.join('\n')),
  ]);
}
