import { compareEvidence } from './evidence.mjs';
const [old, current, output] = process.argv.slice(2);
if (!old || !current || !output) throw new Error('Usage: node compare.mjs OLD_REPORT_DIR NEW_REPORT_DIR OUTPUT_DIR');
const result = await compareEvidence(old, current, output);
console.log(JSON.stringify({ old: result.oldSource.sha, current: result.newSource.sha, counts: Object.fromEntries([...new Set(result.rows.map(r => r.classification))].map(c => [c, result.rows.filter(r => r.classification === c).length])) }, null, 2));
