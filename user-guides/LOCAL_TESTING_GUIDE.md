# Local testing guide

Run commands from the `mathiharan29/medcollab-beta` repository root. Install Python
3.10+ and Git and make them available on PATH. The launcher discovers or prepares
Node 22+, pinned Flutter 3.29.3 and an isolated Linux container runtime using the
checksummed runtime lock. Windows managed containers require WSL/virtualization;
an OS installation or restart can be a prerequisite. Existing local Docker can be
selected with `--runtime existing`. The launcher explains missing prerequisites.

```powershell
python scripts/test_vocle.py --source . --commit (git rev-parse HEAD) --profile tooling
python scripts/test_vocle.py --source . --commit (git rev-parse HEAD) --profile backend-smoke
python scripts/test_vocle.py --source . --commit (git rev-parse HEAD)
```

The full default run selects all 147 backend and 32 Flutter cases plus retained
Flutter tests. No previous reports are required. Omit `--commit` to test a measured
working-tree snapshot; this cannot substitute for immutable submitted-SHA evidence.

## Add local Android and offline security

Install Android Studio's SDK, platform-tools, emulator, command-line tools and an
x86_64 system image. Select a supported JDK via JAVA_HOME or the Android Studio
bundled JDK. Close other emulators and disconnect physical devices. Then run:

```powershell
python scripts/test_vocle.py --source . --commit (git rev-parse HEAD) --all
```

`--all` selects eight Android cases, offline security and CI tooling checks.
Android requires an exact commit. The launcher creates a disposable emulator;
it preserves user AVD data. JDK/CA-store and integration/plugin dependencies are
overlaid only in its temporary build project. TLS verification stays enabled.
See [the native runner guide](../docs/VOCLE_FUNCTIONAL_REGRESSION_DEVICE_RUNNER.md)
for focused commands and scope limitations. PR coverage lists these eight cases
as LOCAL_ONLY, unexecuted SKIP, excluded from hosted passed/executed totals.

## Read and compare results

Each invocation creates a fresh scope-specific folder under `test-results/`.
Open its README, local-session details and offline dashboard. Original results,
checksummed manifest, QA/JUnit and diagnostics are under `evidence/`. A full run
also has a functional dashboard and actual execution summary at the session root.
Setup, interrupted execution, missing artifacts and cleanup errors stay visible.
Historical PASS is never counted as current execution. Do not publish raw secrets,
credentials, real patient information or unsanitized provider recovery journals.

Local history is optional and searches only completed results in this repository
with matching development context. To request a specific candidate:

```powershell
python scripts/test_vocle.py --source . --commit (git rev-parse HEAD) --previous PATH_TO_PRIOR_SESSION
```

This still requires the same repository and full branch ref, or the same explicit
PR number. `--repository OWNER/REPO`, `--branch-ref refs/heads/NAME` and
`--pr-number NUMBER` record context when explicitly known. Detached sources without
trustworthy context report historical comparison UNAVAILABLE. Checksums, scope,
source kind, definitions, harness and environment must match. Source SHAs may
differ. Invalid or missing history never changes the current run's exit status.

## Live Cloudinary (separate authorization)

Only with approval for a synthetic test cloud, run the explicit provider command
and enter credentials privately in your terminal:

```powershell
python scripts/test_vocle_cloudinary.py --commit (git rev-parse HEAD) --test-cloud APPROVED_TEST_CLOUD
```

No production credentials or real patient media are permitted. Keep unresolved
cleanup journals and follow the existing namespace recovery safeguards. Routine
PR and offline validation do not authorize real provider calls. The exceptional
hosted manual workflow is guarded to this repository and trusted master ref.

See [suite ownership](../docs/VOCLE_LOCAL_WORKFLOW_PARITY.md) for PR triggers,
security observations and unsupported delivery/platform coverage. Do not broadly
prune Docker, unregister unrelated WSL distributions or delete existing AVD data.
