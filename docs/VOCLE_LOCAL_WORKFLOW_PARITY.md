# Vocle local and PR suite ownership

Routine Actions entry points run on pull requests targeting `master`, for opened,
reopened, ready_for_review and synchronize events. They test the exact PR head.
Only same-repository PRs are supported; unsupported contexts fail explicitly.
There are no automatic push, schedule, path-selection or routine manual triggers.
Concurrency is scoped to workflow and PR and does not cancel cleanup.

| Suite | Execution owner | Coverage |
| --- | --- | --- |
| Backend functional, including retained sanity | Functional Regression PR | All 147 cases every run; 48 sanity cases are included |
| Flutter catalog and retained tests | Functional Regression PR | All 32 catalog cases plus existing top-level Flutter tests |
| Discovery, fixtures and auth smoke | Backend Environment PR | Frozen discovery inventory and synthetic authentication checks |
| Offline media security | Media Security PR | Dedicated frozen manifest and isolation guards |
| MongoDB data security | Data Security PR | Dedicated frozen manifest and disposable database |
| Launcher, reporting contracts and platform smoke | Developer QA PR | Windows/Ubuntu contracts, tooling and Linux backend smoke |
| Python/Docker prerequisite smoke | Security Environment reusable workflow | Called once by Developer QA |
| Secret scanning | Secret Scan PR | Proposed content and relevant Git history |
| Standalone sanity | Sanity reusable workflow | Explicit reuse only; no extra routine run |
| Android emulator | Developer-local launcher | Eight cases, `LOCAL_ONLY` in PR coverage |
| Live Cloudinary | Exceptional manual workflow | Separate authorization, trusted master and approved test cloud |
| Shared dashboards | Reporting reusable workflow | Called by the owning workflows |

Functional catalog: **187 total / 179 hosted / 8 local-only**. Planned coverage
and actual execution are separate. PR dashboards list every Android ID as
`executionMode: LOCAL_ONLY`, `executed: false`, underlying `status: SKIP`.
They display LOCAL_ONLY and exclude these rows from hosted executed/PASS totals.
Missing required backend/Flutter evidence is ERROR and fails its gate.
Security inventories overlap in IDs and are never summed as unique functional tests.

## Developer commands

From the repository root, with Python 3.10+ and Git:

```powershell
python scripts/test_vocle.py --source . --commit (git rev-parse HEAD) --profile tooling
python scripts/test_vocle.py --source . --commit (git rev-parse HEAD) --profile backend-smoke
python scripts/test_vocle.py --source . --commit (git rev-parse HEAD)
python scripts/test_vocle.py --source . --commit (git rev-parse HEAD) --android --security --ci-checks
```

The default full profile selects 179 functional cases. `--android` adds eight
emulator cases; `--all` adds Android, offline security and CI checks. Local runs
use disposable targets/caches and owned resources. Existing user emulators,
databases and unrelated containers must be preserved. `--runtime existing`
requires an installed local Docker engine; `--runtime managed` prepares an owned
engine and may require operating-system prerequisites. Setup failures are
unvalidated execution, never previous PASS evidence.

Results live under `test-results/`, partitioned by scope. Each invocation has a
fresh folder, original JSON/manifest/JUnit, QA details, cleanup diagnostics and an
offline HTML dashboard. See [the user guide](../user-guides/LOCAL_TESTING_GUIDE.md)
and [Android instructions](VOCLE_FUNCTIONAL_REGRESSION_DEVICE_RUNNER.md).

## Optional history

Current execution and reports complete independently of history. Hosted lookup
paginates completed executions, including failures and individual rerun attempts,
with request/time budgets. Local lookup searches completed evidence under this
repository's `test-results/`. The latest compatible execution in the same context
is selected; newer incompatible evidence may be skipped during lookup.

PR context requires the same repository and PR number. Branch context requires
the same repository and full development branch ref. Detached local sources need
explicit trustworthy context or comparison is UNAVAILABLE. `--previous PATH`
obeys these same checks. `--repository OWNER/REPO`, `--branch-ref refs/heads/NAME`
and `--pr-number NUMBER` supply explicit local context when known.

Compatibility requires verified checksums, completion/attempt identity, suite,
scope, source kind, definitions, harness fingerprint and environment contract.
Both source SHAs are retained and may differ. Hosted and local Android evidence
cannot be interchanged. Missing, expired, corrupt, inaccessible or incompatible
history produces `historical comparison: UNAVAILABLE` with a specific reason.
It never changes the current exit status or supplies current execution evidence.
Only actually executed PASS/FAIL pairs produce FIXED, NEW_REGRESSION,
STILL_FAILING or STILL_PASSING. Other statuses retain their uncertainty.
