# Vocle performance testing

Phase 00 freezes the implementation specification, source surface and ownership. It implements no performance scenarios and authorizes no execution. Work belongs only to `mathiharan29/medcollab-beta`, on `testing/vocle-performance-scale`, based on upstream `master`.

Start each session with [implementation progress](IMPLEMENTATION-PROGRESS.md), [architecture](architecture.md), [decisions](decisions.md), and the [assigned phase](plan/README.md). The complete Astra package is preserved unchanged in [plan/](plan/README.md); its original progress and approval wording describe the historical documentation handoff. The live progress document here records subsequent implementation. The current assignment authorizes Phase 01 shared-harness development, static validation, commits and push, with no runtime execution.

| Artifact | Contract |
|---|---|
| [Catalog](../../tests/performance/catalog.json) | All 45 original IDs, exact priorities, owners, execution dependencies, original specifications, planned sequences and inherited requirements. Every scenario remains NOT_IMPLEMENTED / NOT_EXECUTED. |
| [Source map](source-map.json) | 87 feature registrations, six platform entries, 23 realtime entries and eight background entries; stable `OP-` IDs, source lines and case associations. |
| [Source snapshot](source-snapshot.json) | Source SHA and normalized SHA-256 hashes of inspected evidence; paths/line references are read without application imports. |
| [Stale-reference ledger](stale-references.json) | Investigation-to-base comparison and future drift policy. No upstream drift at Phase 00. |
| [Plan manifest](plan-manifest.json) | Byte hashes for all 32 supplied files, including 23 unchanged phase documents. |
| [Static validation](STATIC-VALIDATION.md) | Actual checks, acceptance review and limitations. |

Run the static checker from the repository root using an existing Node runtime:

```powershell
node --check tests/performance/validate-foundation.mjs
node tests/performance/validate-foundation.mjs
node tests/performance/validate-harness.mjs
git diff --check -- . ':!docs/performance/plan'
git diff --cached --check -- . ':!docs/performance/plan'
```

This checker uses only Node built-ins to read local files and invoke read-only Git commands. It installs nothing, imports no application code and makes no network calls. A static consistency result is not a test PASS. Source/hash drift fails closed and requires a reviewed ledger entry; do not regenerate the frozen plan to hide a mismatch.

Do not start the backend, MongoDB, Docker, Flutter or emulators; run regression/security/load suites; dispatch workflows; seed data; or contact a test target during development. Future execution requires separate authorization, isolated identity, closed provider egress, finite budgets and owned cleanup. Git repository access is solely for the authorized development workflow.

Phase 01 implements the shared harness, schemas, configuration validation, resource journal, accounting/metrics and reporting envelope, with exact dependency locks. See [Phase 01 contracts](PHASE-01-CONTRACTS.md), [dependency review](DEPENDENCY-REVIEW.md) and [static evidence](PHASE-01-VALIDATION.md). No runtime utilities are exported by Phase 00. Later phases own adapters and scenarios as specified in the preserved plan. No production thresholds or measured baselines exist.
