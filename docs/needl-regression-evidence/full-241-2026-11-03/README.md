# Full local 241-case regression evidence — 3 November 2026

241 executed: **235 PASS / 5 FAIL / 1 NEEDS_DECISION / 0 ERROR / 0 BLOCKED / 0 SKIP**. All original187 cases PASS. Backend174/177 PASS; Flutter53/56 PASS; Android8/8 PASS. Overall functional verdict remains FAIL.

Open combined/vocle-regression-dashboard.html for the offline visual report. The same directory contains detailed Markdown, JSON, JUnit, summary and exact lane/input provenance. Each detailed case retains its actual execution source/harness revision; the report header has no single harness SHA because lanes ran at different recorded commits with identical application source and lock objects. This is not hosted or single-revision full-suite success evidence.

Backend/Flutter final execution:345b679. Android/retained Flutter:26118b4. Application source baseline:4c01dc2. Reporter:618bc75. Later evidence-only commits do not relabel execution. See ../../VOCLE_NEEDL_REGRESSION_PROGRESS.md for exact SHAs, failures, recovery, reproduction and limitations.

Five application FAIL IDs: FR-NDL-28,29,39,50,53. FR-NDL-10 remains NEEDS_DECISION for archival expansion (NDL-D1). All99 backend module cleanup reports PASS. Android source/cleanup PASS; owned emulator/AVD removed. One pre-body driver attachment timeout recovered through the existing single infrastructure retry; both diagnostics are preserved in android/diagnostics/.

Portable text/JSON copies are sanitized. Checksums in provenance identify original local raw inputs, which remain in ignored test-results; redaction can change published copy bytes. Android source archive, binaries, native userdata, provider inboxes and credentials are excluded. The offline browser check used a separate copy with an intentionally hostile diagnostic; only its receipt is included, not its modified report.

No iOS, real Firebase/FCM/MSG91/Cloudinary delivery, production data, hosted success or deployment is claimed.
