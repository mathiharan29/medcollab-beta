# Needl functional regression expansion

**Latest status:** the whole-catalog follow-up below executed all241 locally: 235 PASS / 5 FAIL / 1 NEEDS_DECISION. Earlier sections retain the original Needl-only checkpoint.

## Baseline and authorization — 3 November 2026

- Upstream master fetched read-only: `4c01dc24247aa95a73e286a2b42c7f2f81257c7a`. User checkout already matched it, with origin pointing upstream; that checkout/untracked work was preserved.
- Isolated checkout: `vocle-needl-regression`; branch `temp/needl-functional-regression-20261103`; origin is the authorized testing fork. No upstream writes, master pushes or PR creation.
- New AGENTS.md records current source baseline, remote topology, branch authorization and synthetic-only safety rules.

## Audit and implemented scope

Needl group conversations and the older `/users/me/needl` thread inbox were traced separately. Audited backend routes/controllers, `memberPairKey`, `knownUsers`, channel access, message/pin/receipt routes, realtime handlers and the existing conversation/thread suites. Audited Flutter ChannelRepository/ChannelModel, StartDmPage, MessagesHubPage, Needl management sheets, ChannelChatPage, route navigation, presence, drafts and notification badges. Existing FR-DM-01..09, FR-THR-01..05 and retained sanity assertions remain intact.

Added FR-NDL-01..30 backend and FR-NDL-31..54 Flutter cases, with explicit design in the main catalog and `contracts/needl-cases.json`. Coverage includes creation identity, exact/independent membership, aliases, validation, outsider/anonymous access, rename projection, expansion normalization and caps, all/today/none history, copy metadata/deletion state, recipients/persistence, pin/read behavior, restart, concurrency/recovery, real repository serialization, tab isolation, suggestions/search races, selection across creations, add-people lookup/chips/history/retry, rename, members/presence and actual chat/menu rendering.

Catalog: **241 total = original 187 + 54 Needl cases**; B177/F56/D8; hosted233/local-only8; retained sanity48. Original187 rows and IDs frozen by SHA-256/order guard in `contracts/catalog-baseline.json`. Source catalog/registry validator passes. Backend scheduler, full-success checks, Flutter gates, reporting/coverage and tooling fixtures include the expansion. Full-suite success requires all new required cases too.

## Local infrastructure and preliminary execution

- Real Express backend with disposable loopback MongoDB 7.0.14 and existing provider interception; no .env, Atlas, SMS, Firebase or Cloudinary access.
- Global Flutter 3.47.2 cannot satisfy the original lockfile. Installed isolated Flutter3.29.3 (runtime-lock commit ea121f8) and resolved the unchanged lockfile successfully; no application dependency upgrades.
- Initial backend run: 26 PASS/4 FAIL. One history fixture bypassed schema defaults and used tied timestamps; corrected to supported fields with distinct timestamps. Archived detail assumption corrected after explicit source review. Actual concurrency and history-retry failures retained.
- Flutter harness finder/asynchronous-observation issues corrected; actual stale-search result overwrite, modal navigation-context exception and members-sheet rendering overflow remain failures. Do not modify application code to green these tests.
- Infrastructure contracts: 41/41 PASS. Includes catalog completeness, report normalization/provenance, migration/coverage and developer policies; Windows CRLF handling and sandbox-only Git fixture permissions repaired.
- NDL-D1 remains NEEDS_DECISION; Q1–Q14 founder decisions unchanged.

## Final executed evidence

Tested implementation revision: **4765df8b89912dcb48f377fc184f83041f0decc0**. Application source trees and dependency lockfile Git objects are identical to upstream baseline **4c01dc24247aa95a73e286a2b42c7f2f81257c7a**. Upstream master rechecked unchanged before delivery. Evidence/documentation commits are later than the tested harness and do not relabel the execution revision.

| Scope | Executed | PASS | FAIL | NEEDS_DECISION | ERROR/BLOCKED/SKIP |
| --- | ---: | ---: | ---: | ---: | --- |
| New Needl backend FR-NDL-01..30 | 30 | 27 | 2 | 1 | 0/0/0 |
| New Needl Flutter FR-NDL-31..54 | 24 | 21 | 3 | 0 | 0/0/0 |
| Combined new Needl | 54 | 48 | 5 | 1 | 0/0/0 |
| Full Flutter catalog, including new Needl | 56 | 53 | 3 | 0 | 0/0/0 |
| Existing unchanged backend conversations/threads | 13 | 13 | 0 | 0 | 0/0/0 |
| Infrastructure/reporting contracts | 41 | 41 | 0 | 0 | 0/0/0 |

The scopes overlap: do not add the new Flutter row to the full Flutter row. The 13 related existing backend cases ran at cb8c5fc before the final badge/search strengthening; their source and harness revisions remain in their records. The full 177-backend/241-case catalog was not executed; the 48 retained sanity cases were preserved, not rerun as a complete suite. Android/iOS and real-provider execution are not claimed.

Observed application failures preserved:

- **FR-NDL-28**: concurrent expansion does not return a usable successful response for both intents. The controller's separate find/create path is a likely race location, not an independently proven root cause.
- **FR-NDL-29**: a deliberately interrupted MongoDB history copy leaves a destination that is reused on retry with zero copied messages, although one source message was requested. The fixture removes its temporary unique index before retry; no application source is patched.
- **FR-NDL-39**: an old name-search response replaces the newer result. The test explicitly proves Doctor Z was visible before completing the older response, then verifies it must remain.
- **FR-NDL-50**: successful add-people submission uses the modal context with `GoRouterState.of`, raising “There is no GoRouterState above the current context” instead of opening the returned Needl.
- **FR-NDL-53**: the actual members sheet produces a RenderFlex bottom overflow (91 px at the recorded 1200×1800 logical test surface). Member count, self-first ordering and presence checks execute; rendering failure remains FAIL.

**NDL-D1**: archived conversation detail intentionally permits authorized historical reading. Whether archived Needls may be expanded is unresolved. FR-NDL-10 verifies safe behavior, records HTTP 200 for expansion on this source, and remains NEEDS_DECISION. No founder/developer approval was invented.

All 30 final backend modules confirmed stopped backend/MongoDB and removed runtime directories. No production services or provider delivery were used. The unchanged lockfile was successfully used with Flutter3.29.3; no application source or dependency fixes were made. Windows PowerShell UTF-16 reporter stdout was losslessly converted to UTF-8 before hashing/aggregation. The Node migration contract's CRLF parser and local temporary-Git fixture sandbox permissions were repaired as harness/environment issues.

## Reports and reproducible commands

Committed evidence: `docs/needl-regression-evidence/2026-11-03-4765df8/`. Includes the five existing visual/detailed/JSON/JUnit/summary formats, full Flutter results/provenance, backend module and related-case records, exact input hashes, source-tree/cleanup verification, 41-contract output and offline Chrome dashboard receipt. The dashboard's filters/charts/drill-down and safe offline rendering PASS. Raw Flutter NDJSON and backend logs remain in ignored `test-results/`; their original local paths/checksums are recorded. The checked-in bundle contains sanitized structured evidence rather than provider inboxes or credentials.

Example commands from this checkout (use a compatible Flutter3.29.3 path):

```powershell
node tests/functional-regression/scripts/validate-catalog.mjs
npm.cmd ci --ignore-scripts --prefix medcollab-backend
npm.cmd ci --ignore-scripts --prefix tests/sanity
$env:VOCLE_OUTPUT_DIR = "$PWD/test-results/needl-backend"
node tests/functional-regression/suites/needl.mjs
# From medcollab-app; capture JSON using UTF-8 when invoking in Windows PowerShell:
flutter test --no-pub --reporter json test/functional_regression
# Aggregate the reporter using a runner-owned provenance JSON bound to event checksum and source SHA:
node tests/functional-regression/scripts/aggregate-flutter.mjs EVENTS_NDJSON FLUTTER_REPORT_BASE RUNNER_PROVENANCE_JSON
node tests/functional-regression/scripts/report-needl.mjs BACKEND_OUTPUT_DIR FLUTTER_REPORT_JSON REPORT_DIRECTORY
```

Nonzero exits are expected while the recorded failures/decision remain. No repeat-until-green mutation or weakened assertions are used. CI's existing full backend scheduler now includes NDL and requires 177 backend records; Flutter gates require 56. Full-suite reports declare 241 total / 233 hosted / 8 LOCAL_ONLY and cannot treat this 54-case subset as a full-suite success.

## Delivery and next action

All 54 new cases contain executable assertions, are registered in the existing catalog, and were executed locally. AGENTS.md updated. Implementation commits cb8c5fc and 4765df8 plus the final evidence checkpoint are pushed only to **origin/temp/needl-functional-regression-20261103**. Find the final evidence commit with `git log -1 --format=%H -- docs/VOCLE_NEEDL_REGRESSION_PROGRESS.md`.

The user's original checkout, its branch/remotes and untracked files remain untouched. Both remote master branches remain unchanged; upstream is strictly read-only. No PR, deployment, hosted provider workflow or production operation was performed.

Exact next action: review the temporary branch and the five failures; decide NDL-D1 before implementing an archival-expansion policy. Application fixes and any PR creation require a separate request. Remaining platform limits: component/widget coverage uses controlled repositories/HTTP/socket inputs; backend coverage uses real Express and disposable MongoDB; no new real-device/iOS journey execution. This is broad source-based regression coverage, not a claim of exhaustive input combinations or 241 passing cases.

## Whole-catalog local follow-up — completed execution, non-green verdict

User requested all 241 catalog cases locally and any additional test fixes on the same temporary branch. **All 241 executed: 235 PASS, 5 FAIL, 1 NEEDS_DECISION; ERROR/BLOCKED/SKIP all zero. All original 187 cases PASS.** This supersedes the earlier Needl-only checkpoint's execution limitations. The catalog remains 241; harness contracts and retained tests outside the catalog do not increase its case count.

| Tier | Executed | PASS | FAIL | NEEDS_DECISION | ERROR/BLOCKED/SKIP |
| --- | ---: | ---: | ---: | ---: | --- |
| Backend (retained sanity included) | 177 | 174 | 2 | 1 | 0/0/0 |
| Flutter catalog | 56 | 53 | 3 | 0 | 0/0/0 |
| Android LOCAL_ONLY device | 8 | 8 | 0 | 0 | 0/0/0 |
| **Entire catalog** | **241** | **235** | **5** | **1** | **0/0/0** |

Additional independent checks: **33 retained Flutter tests PASS**, **67 infrastructure/reporting contracts PASS**, default functional harness test PASS (classification self-check plus 17 contracts), and real offline Chromium dashboard PASS with all241 result rows. Deliberately supplied partial device evidence was rejected without producing a complete report. These checks are not additional catalog cases.

### Failure assessment and repairs

Final application failures are unchanged: FR-NDL-28 concurrent expansion responses; FR-NDL-29 incomplete history-copy recovery after a removed database fault; FR-NDL-39 stale search overwriting newer results; FR-NDL-50 add-people modal GoRouter context exception; FR-NDL-53 members-sheet layout overflow. Their assertions and application code remain unchanged. FR-NDL-10 remains NEEDS_DECISION for NDL-D1, archived Needl expansion policy; this is not classified as an application defect.

Problems fixed or recovered during this execution:

- Windows sandbox MongoDB startup failed (fassert), and sandbox Flutter compilation stalled before execution. Host-access runs with the same disposable services and synthetic provider interception completed. Failed initial attempts remain in ignored test-results; they are not application verdicts or final coverage.
- FR-JRN-04 requested undefined synthetic users J4A/J4B, failing before its behavioral assertions. Added dedicated unique phone fixtures without changing journey assertions. Unknown fixtures now raise FixtureError and classify ERROR instead of application FAIL. Added a registry contract covering every literal backend identity reference and an ERROR-versus-FAIL classification guard. The **entire backend177 was rerun** after the committed repair and FR-JRN-04 PASS.
- One Android session-restore driver attachment timed out before its test body started. The existing bounded infrastructure-only retry recovered; subsequent restoration and logged-out cold launch assertions PASS. The original failed attachment diagnostic and retry diagnostic are both retained. No assertion failure was retried. Invite startup was also slow but completed successfully without retry. Read-only VM inspection queried isolate/extension/stack metadata only; it did not resume or modify application execution.
- New report-local-catalog.mjs verifies exact B177/F56/D8 ID sets, completion, original lane gates, cleanup and identical application/lock Git objects across lane revisions. It preserves non-pass outcomes, rejects incomplete/unexecuted evidence, and exits nonzero for this FAIL verdict. Its three contracts are included in the normal functional harness test command.
- PowerShell reporter output was losslessly converted from UTF-16 to UTF-8 before event hashing/aggregation. Test publication uses the existing sanitizer; raw event files/logs remain local, while portable copies may have different bytes after redaction.

### Exact provenance and cleanup

Application baseline remains upstream master **4c01dc24247aa95a73e286a2b42c7f2f81257c7a**. Git objects for backend src/package/lock and Flutter lib/pubspec/lock match that baseline at every execution revision. There were no application functional/security/dependency changes.

- Backend177 and Flutter56 final execution source/harness: **345b6797ab4fb26979a5958836cb2b76f1254999**.
- Android8 and retained Flutter33 execution source/harness: **26118b40f388769eca30c9cb23f590379d8adf41**. The device process started before the fixture repair, and its exact revision is retained. The new J4 fixtures are irrelevant to its cases. No execution is relabeled to a later commit.
- Combined report generator checkout: **618bc75** (full SHA in local-execution-provenance.json). This is a local complete-catalog aggregation across recorded lane revisions with identical application objects, not a hosted success marker or single-harness-revision success claim. Per-case source/harness SHAs remain in the detailed/JSON reports.
- Runtime: isolated Flutter3.29.3 / SDK commit ea121f8859e4b13e47a8f845e4586164519588bc; MongoDB7.0.14; Node24.14.1; owned WHPX Android36.1 x86_64 emulator. Original lockfiles unchanged. iOS and real provider delivery are not claimed.
- All **99 backend module reports** have PASS cleanup/provenance and no remaining runtime directories. Device source verification/cleanup PASS, dedicated test app uninstalled, isolated application archive workspace removed, owned emulator exited, and owned AVD plus temporary truststore removed. Shared processes and user AVDs were not stopped or reused.

### Evidence and reproduction

Portable evidence: **docs/needl-regression-evidence/full-241-2026-11-03/**. Combined five-format report/dashboard and local-execution-provenance.json are under combined/. Includes99 backend module records, execution inventory, full Flutter results/provenance, retained-test summary, complete Android results/coverage/JUnit/phase logs/events, cleanup receipts, contracts and offline browser receipt. Input hashes identify the original raw local inputs; sanitized copies do not claim byte identity to them.

Local original outputs: test-results/full-241-final/backend, test-results/full-241-final/flutter, test-results/full-241-host/device and test-results/full-241-final/combined. The owned-emulator launcher is test-results/full-241-host/launch_device.py; it uses serial/PID ownership and does not invoke legacy wrappers that globally terminate Java/Dart/emulator processes.

```powershell
# From repository root, using a host shell that permits disposable Mongo child processes:
$env:MONGOMS_SYSTEM_BINARY = 'C:/Users/delll/AndroidStudioProjects/Vocle/medcollab-beta-workflows/tests/functional-regression/output/mongo-binaries/mongod-x64-win32-7.0.14.exe'
$env:MONGOMS_VERSION = '7.0.14'
$env:VOCLE_TARGET_DIR = $PWD.Path
$env:VOCLE_OUTPUT_DIR = "$PWD/test-results/NEW-RUN/backend"
$env:VOCLE_SCOPE = 'backend-all'
node tests/functional-regression/scripts/run-backend.mjs
# From medcollab-app, using isolated compatible Flutter3.29.3:
flutter test --no-pub --reporter json test/functional_regression
# Aggregate UTF-8 reporter bytes with runner-owned checksum/source provenance:
node tests/functional-regression/scripts/aggregate-flutter.mjs EVENTS_NDJSON FLUTTER_REPORT_BASE RUNNER_PROVENANCE_JSON
# With a fresh owned emulator, test-only package, JAVA_HOME and synthetic provider configuration:
node tests/functional-regression/scripts/run-device.mjs --source-sha=EXACT_SHA --flutter-bin=SDK_PATH --adb-bin=ADB_PATH --emulator=OWNED_EMULATOR_SERIAL --output=NEW_DEVICE_DIR
# Seal all three complete lanes; FAIL exit is expected until genuine failures/decision are resolved:
# Optional: $env:VOCLE_APPLICATION_BASELINE_SHA pins a historical application snapshot.
node tests/functional-regression/scripts/report-local-catalog.mjs BACKEND_DIR FLUTTER_REPORT_JSON DEVICE_DIR REPORT_DIR
npm.cmd test --prefix tests/functional-regression
```

### Delivery and exact next action

Additional test changes: **345b679** (fixtures/classification/identity contracts), **c9a1931** (full local aggregation/completeness contracts/default harness command), **618bc75** (use the run application snapshot by default, with an optional pinned historical baseline), plus this final evidence checkpoint. Push destination remains only origin/temp/needl-functional-regression-20261103; no master push, upstream write, PR or hosted run is authorized by this follow-up.

Exact next action after delivery: developer fixes for the five recorded Needl defects, plus a product decision on NDL-D1, followed by affected-case reruns and a fresh full gate. No further local environment repair is currently blocking the catalog. Original checkout, unrelated Flutter/Android user work and production systems remain untouched.


## Manual workflow restoration follow-up

Owner changed upstream default branch to master; upstream master4c01dc2 still has PR-only routine triggers. Added manual entry points and exact-commit source/provenance handling on the same temporary fork branch. All14 real Bash context guards passed154 scenarios, and82/82 relevant local contracts plus10 YAML parses passed. No application code/case assertions changed or241-case execution relabeled. See VOCLE_MANUAL_WORKFLOW_RESTORATION.md and docs/workflow-manual-evidence/2026-11-03/. Exact next action: owner review/integration into upstream master, then an actual hosted manual run. No upstream push, PR, merge, workflow dispatch, settings change or production operation was performed by this session.


## Vocle repository delivery — latest user authorization

The user now designates mathiharan29/medcollab-beta as the single **Vocle repo** and explicitly authorizes committing/publishing the workflow fix on the same temporary branch as the extra regression cases there. This supersedes earlier fork-only delivery restrictions. A fresh isolated checkout, vocle-regression-review, uses only origin=https://github.com/mathiharan29/medcollab-beta.git. The original working tree and its untracked work remain untouched. AGENTS.md and current operating instructions reflect this change.

Branch: **temp/needl-functional-regression-20261103** in Vocle repo. Includes the complete54-case Needl expansion, catalog241 wiring, fixture/reporting repairs, prior local execution evidence, and workflow fix **d41386c**. All commits descend from observed master4c01dc2; application source and dependencies are unchanged. Earlier reports retain their actual source/harness/repository identities. They are not imported as a new Vocle hosted execution or success marker.

Local validation in the Vocle checkout: catalog validator and82 workflow/reporting/coverage contracts. No application catalog rerun or hosted execution is claimed for this delivery. Master is not changed. Exact next action: review this same-repository temporary branch and merge through the repository's normal process; then open Actions and run the desired standalone workflow. The existing five functional FAILs and NDL-D1 decision remain visible and must not be bypassed or relabeled.
