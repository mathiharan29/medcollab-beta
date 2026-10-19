# Vocle developer QA operating instructions

Use [the local testing guide](../user-guides/LOCAL_TESTING_GUIDE.md) for setup and
commands. [Suite ownership and CI parity](VOCLE_LOCAL_WORKFLOW_PARITY.md) records
every execution lane. PRs target `master`; routine suites always execute without
history or changed-file skipping. Application behavior is unchanged by this tooling.

## Evidence and gates

Tests use synthetic users and disposable databases with loopback provider doubles.
Source/harness SHAs, content fingerprints, repository/PR or development-branch
context, run/attempt identity, environment and execution flags accompany reports.
Source hashes are checked after execution and owned resources are cleaned up.
Failure-time reporting and artifact sanitization preserve application failures,
setup errors, missing required evidence and cleanup failures separately.

Download the owning workflow's artifact and extract it before opening
`vocle-regression-dashboard.html`. JSON, Markdown and JUnit accompany the HTML.
No server is needed. Catalog procedures describe assertions, not per-step traces
or proven root causes. Owners remain UNASSIGNED until an approved mapping exists;
automatic owner assignment and notifications are not implemented.

A success manifest attests only to its recorded current run. It cannot skip later
runs. Optional comparisons follow the same-context rules in the parity guide;
legacy reports lacking context/integrity are unavailable as automatic history.

## Coverage declarations

The catalog has immutable IDs. Application changes require a registered coverage
declaration and independent review of assertion quality and cross-feature effects.
Trusted exceptions remain empty. Initial installation may use an empty base
catalog only when that exact Git commit lacks it, the change has no application
source edits, and the complete new catalog validates. Malformed catalogs, Git
errors, later removals and unregistered IDs fail the coverage check.

## Security and limitations

Security OBSERVATION remains distinct from PASS/FAIL and is not automatically a
strict application failure gate. Review-derived candidate registries are absent.
Live Cloudinary requires separate authorization, the approved test-cloud variable,
runtime secrets, trusted `refs/heads/master`, manual event and existing namespace
and cleanup safeguards. The workflow may remain unavailable until present on the
repository's actual default branch; do not broaden its triggers to work around it.

Android's eight emulator cases are LOCAL_ONLY; iOS, arbitrary APK verification,
real FCM/APNs/camera delivery and complete Actions/secret administration are not
established. Product FAIL, BLOCKED and NEEDS_DECISION remain possible. Do not
weaken tests or change application code to hide them. Backend npm test remains a
placeholder; the two retained Jest files lack runner/configuration and are not
claimed as executed.

## Post-merge protection proposal (documentation only)

Protect `master` after hosted validation: require PRs, at least one approving
review, dismiss stale approvals and require approval of the latest reviewable
push by another person where supported. Require passing uniquely named routine
CI gates using their actual emitted names after hosted validation. Block force
pushes and deletion; enforce protection for administrators/bypass roles where
supported, with no actor exemptions permitting direct pushes or bypass of PR,
review or check requirements. Verify direct and administrator pushes are rejected.
Exceptional Cloudinary and LOCAL_ONLY Android are not required hosted checks.
These instructions do not change repository settings.
