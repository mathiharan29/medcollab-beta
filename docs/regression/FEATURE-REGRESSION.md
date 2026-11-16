# Run Vocle regression cases by feature

1. Open **Actions** and choose **Vocle — Feature Regression**.
2. Select **Run workflow** on `master`. Choose a feature from the dropdown or choose `all` for the complete functional catalog.
3. Open the run summary to see the selected IDs and their results. Download the `vocle-feature-<feature>-<attempt>` artifact for Markdown, JSON, JUnit, the HTML dashboard and sanitized runner logs.

The [feature matrix](FEATURE-REGRESSION-MATRIX.md) lists the dropdown choices, the IDs in each choice and the executor for each ID. Tests with several tags execute once per run. The workflow filters exact IDs before launching backend scenarios or Flutter tests. Backend assertions use disposable loopback MongoDB and test-owned provider fixtures inside the existing Docker isolation. Flutter uses the pinned SDK and locked dependencies.

Choosing `all` selects all 296 IDs, runs the 188 backend and 98 Flutter cases, and reports the ten Android cases as **LOCAL_ONLY / SKIP** with `executed: false`. The hosted verdict requires all selected hosted cases to pass. Missing results, unexpected results, assertion failures and unresolved decisions keep the run red.

## Local use

Run from the repository root with Node.js 22 or later. Inspect a selection with `node tests/functional-regression/scripts/select-feature.mjs direct-messaging`. An invalid feature or stale registration fails validation.

- For backend cases, install the locked backend and sanity dependencies and use an isolated test checkout with a disposable loopback MongoDB runtime. Set `VOCLE_FEATURE`, `VOCLE_SCOPE=backend-feature`, `VOCLE_TARGET_DIR` and a fresh `VOCLE_OUTPUT_DIR`, then run `node tests/functional-regression/scripts/run-backend.mjs`. The workflow shows the isolation and provenance settings for the backend manifest.
- For Flutter cases, resolve the locked dependencies on Flutter 3.29.3. Set `VOCLE_FEATURE` and a fresh `VOCLE_FEATURE_OUTPUT`, then run `node tests/functional-regression/scripts/run-feature-flutter.mjs`. On Windows, set `VOCLE_FLUTTER_BIN` to the absolute path to the pinned SDK's `flutter.bat`.
- For Android cases, pass the selected native IDs via `--cases` to the [local Android runner](../VOCLE_FUNCTIONAL_REGRESSION_DEVICE_RUNNER.md).

To generate a verified local feature report, use a clean checkout and place backend output in `$VOCLE_FEATURE_OUTPUT/backend`. Set `VOCLE_TARGET_KIND=commit` and set both `VOCLE_TARGET_SHA` and `VOCLE_HARNESS_SHA` to `git rev-parse HEAD`. Set `VOCLE_FINGERPRINT` to the output of `node tests/functional-regression/scripts/fingerprint.mjs`. After backend execution, run `node tests/functional-regression/scripts/manifest.mjs`. The Flutter runner writes its own report under `$VOCLE_FEATURE_OUTPUT/flutter`. Run `node tests/functional-regression/scripts/report-feature.mjs` after the applicable lanes finish.

## Independent security inventories

The separate manifests contain 691 API and realtime cases, 31 MongoDB data cases, 97 offline media cases and 34 real-provider Cloudinary cases. Media and provider manifests share catalog history with the API inventory, so these counts describe workflow selections. Each inventory retains its existing runner and isolation requirements.

## Maintain the mapping

Add each catalog case ID to one or more lists in [feature-registry.json](../../tests/functional-regression/feature-registry.json) and update the registry count when the catalog grows. When adding a feature, add its ID to the workflow dropdown in registry order. Regenerate the matrix with `node tests/functional-regression/scripts/feature-matrix.mjs` and run `npm test --prefix tests/functional-regression` and `npm run validate --prefix tests/functional-regression`.

The catalog validation used by the existing full workflow checks the mapping, executor declarations, generated matrix and dropdown. The separate security workflows, full regression triggers and standalone sanity workflow retain their original entry points.

## Voice selections

Select `voice-messaging` for capture, transcription, history and playback, `handoff-voice` for shift and patient audio, or `voice-assistant` for spoken and typed commands, proposals and execution. Cross-feature tests are also selectable under their related DM, Needl, Handoff, search, lifecycle and access features. The [voice audit](VOICE-COVERAGE-AUDIT.md) lists the original assertions, gaps, execution results and manual device protocols.

## Baseline feature-workflow validation (245-case catalog)

The backend and Flutter observed ID sets matched the selected IDs exactly in the following isolated test runs. Android counts are listed as local only in the hosted feature plan.

| Selection | Backend | Flutter | Selected Android cases |
|---|---|---|---:|
| `direct-messaging` | 25 passed | 4 passed | 0 |
| `voice-messaging` | 2 passed | No mapped Flutter cases | 0 |
| `handoff` | 20 passed, 1 failed | 4 passed | 1 |
| `needl` | 43 passed, 2 failed, 1 needs decision | 22 passed, 2 failed | 0 |
| `all` | 177 passed, 3 failed, 1 needs decision | 54 passed, 2 failed | 8 |

The failing assertions were FR-HOF-02, FR-NDL-28, FR-NDL-29, FR-NDL-39 and FR-NDL-53. FR-NDL-10 remained NEEDS_DECISION. A separate profile selection exercised ten backend cases, all passing, including retained cases whose setup had previously come from another scenario.
