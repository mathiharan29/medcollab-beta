"""Read downloaded ZIP members without extracting arbitrary archive paths."""
import hashlib
import json
import pathlib
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

directory = pathlib.Path(sys.argv[1])
metadata = json.loads((directory / 'hosted-metadata.json').read_text())
statuses = ['PASS', 'FAIL', 'ERROR', 'BLOCKED', 'NEEDS_DECISION', 'SKIP']
outputs = []
original_security = {}
for archive in directory.glob('*.zip'):
    with zipfile.ZipFile(archive) as z:
        if 'results.json' in z.namelist():
            raw = json.loads(z.read('results.json'))
            if any(r.get('caseId') for r in raw.get('results', raw.get('cases', []))):
                original_security[archive.stem] = raw
for archive in sorted(directory.glob('*.zip')):
    artifact = next(a for a in metadata['artifacts'] if archive.name == a['name'] + '.zip')
    digest = 'sha256:' + hashlib.sha256(archive.read_bytes()).hexdigest()
    assert not artifact.get('digest') or digest == artifact['digest'], 'Artifact digest mismatch'
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        report_names = [n for n in names if n.endswith('vocle-regression-results.json')]
        if not report_names:
            assert archive.stem in original_security, 'No normalized report in ' + archive.name
            continue
        for name in report_names:
            prefix = name[:-len('vocle-regression-results.json')]
            required = ['dashboard.html', 'detailed-report.md', 'results.json', 'junit.xml', 'summary.md']
            assert all(prefix + 'vocle-regression-' + n in names for n in required), 'Missing deliverable'
            report = json.loads(z.read(name))
            rows = report['results']
            assert len({r['id'] for r in rows}) == len(rows), 'Duplicate IDs'
            outcomes = report.get('statuses', statuses)
            counts = {s: sum(r['status'] == s for r in rows) for s in outcomes}
            assert counts == report['counts'], 'Normalized count mismatch'
            assert not any(r['status'] == 'PASS' and not r['executed'] for r in rows), 'Unexecuted PASS'
            assert all(r.get('scenario') and r.get('prerequisites') and r.get('steps') for r in rows), 'Missing reproduction metadata'
            # Compare to original machine evidence when present. No partial result is promoted.
            original_path = next((p for p in ['results.json', 'report.json', 'sanity-report.json'] if p in names), None)
            linked_original = next((original_security[l['artifact']['name']] for l in report.get('lanes', []) if l.get('artifact', {}).get('name') in original_security), None)
            if original_path or linked_original is not None:
                original = json.loads(z.read(original_path)) if original_path else linked_original
                raw = original.get('results', original.get('cases', original.get('scenarios', [])))
                aliases = {'passed': 'PASS', 'failed': 'FAIL', 'blocked': 'BLOCKED', 'planned': 'SKIP'}
                def raw_status(r):
                    value = r.get('status') or ('PASS' if r.get('passed') is True else 'OBSERVATION' if r.get('passed') is False else 'ERROR')
                    return 'ERROR' if value == 'INFRASTRUCTURE_FAILURE' else aliases.get(value, value)
                expected = {r.get('id', r.get('caseId')): raw_status(r) for r in raw}
                actual = {r['id']: r['status'] for r in rows}
                assert all(actual.get(k) == v for k, v in expected.items()), 'Original classification changed'
                if len(raw) == len(rows):
                    assert {s: sum(raw_status(r) == s for r in raw) for s in outcomes} == counts
            ET.fromstring(z.read(prefix + 'vocle-regression-junit.xml'))
            html = z.read(prefix + 'vocle-regression-dashboard.html').decode('utf-8')
            match = re.search(r'<script id="report-data" type="application/json">(.*?)</script>', html, re.S)
            assert match and json.loads(match.group(1))['counts'] == counts, 'HTML/JSON mismatch'
            assert '<script src=' not in html and '<link ' not in html, 'External dependency'
            outputs.append({'artifact': artifact['name'], 'digest': digest, 'suite': report['suite'], 'caseCount': len(rows), 'attempted': report['attempted'], 'counts': counts, 'originalGate': report['originalGate'], 'comparisonAvailable': report['comparison']['available'], 'fiveFiles': True, 'junitValid': True, 'htmlCountsMatch': True})
        for name in names:
            if not name.endswith(('.json', '.md', '.html', '.xml', '.log', '.txt', '.ndjson')):
                continue
            text = z.read(name).decode('utf-8', errors='replace')
            assert not re.search(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', text), 'JWT leak in ' + name
            assert not re.search(r'Bearer\s+(?!\[REDACTED\]|\\\[REDACTED\\\]|\*{3})[^\s"<>]+', text, re.I), 'Bearer leak in ' + name
            assert not re.search(r'https?://[^\s"<>]+[?&](?:sig|access_token)=', text, re.I), 'Signed URL leak in ' + name
result = {'run': metadata['run'], 'artifactsVerified': outputs, 'secretScan': 'PASS', 'note': 'This checks reporting fidelity and publication, not application correctness or full-suite success.'}
(directory / 'artifact-verification.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
