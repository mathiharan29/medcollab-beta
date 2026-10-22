# Vocle detailed QA reports

Download and extract the owning Actions artifact; open
`vocle-regression-dashboard.html` locally. JSON, Markdown, summary and JUnit are
included. Logs are sanitized; definition excerpts describe procedures, not full
execution traces or proven root causes. Owners remain UNASSIGNED until approved.

```powershell
node --test tests/reporting/*.test.mjs
node tests/reporting/report.mjs --suite backend --input PATH/results.json --evidence-dir PATH --output tests/reporting/output/backend
node tests/reporting/report.mjs --suite flutter --input PATH/report.json --evidence-dir PATH --output tests/reporting/output/flutter
node tests/reporting/report.mjs --suite device --input LOCAL_RUN/results.json --output tests/reporting/output/device
```

`fixtures/synthetic-inputs.mjs` supplies complete backend, Flutter, Android,
sanity, discovery, media and data format inventories for offline tests and browser
checks. They are synthetic fixtures and are never substituted for current evidence.

Current reports are written before optional historical enrichment. `--history true`
uses paginated, bounded, read-only hosted lookup. `--baseline PATH` requires a
verified normalized report from the same repository/PR or development branch,
suite, scope, source kind, definitions, harness and environment. Source SHAs may
differ. Individual run attempts remain distinct. Legacy, corrupt, expired or
incompatible history yields historical comparison UNAVAILABLE with a reason and
does not change the current execution status. Local launcher `--previous` follows
the same rules. No history controls execution or supplies current PASS evidence.

Only executed PASS/FAIL pairs produce FIXED, NEW_REGRESSION, STILL_FAILING and
STILL_PASSING. Security OBSERVATION and other uncertain statuses remain distinct;
each security suite uses its own manifest/evidence contract. Scanner step records
are workflow checks, not application tests or published raw secret matches.

Combined PR coverage is 187 total / 179 hosted / 8 LOCAL_ONLY. All eight Android
IDs display LOCAL_ONLY, underlying SKIP and executed false. Missing required hosted
lanes remain ERROR. Verified local Android outcomes are reported separately and
cannot be relabeled as hosted results. Counts from overlapping suites or developer
matrix profiles are not summed as unique cases.

`hosted-check.mjs` supports read-only inspect, download and job-log operations.
`browser-check.mjs BROWSER [REPORT_JSON] [OUTPUT]` checks offline interaction,
escaping, inventory and links with a dedicated headless profile. Live Cloudinary
is never invoked by reporting tests. See [suite ownership](../../docs/VOCLE_LOCAL_WORKFLOW_PARITY.md).
