# Frozen architecture and contracts

Repository: `https://github.com/mathiharan29/medcollab-beta.git`. Base and investigation: `4c01dc24247aa95a73e286a2b42c7f2f81257c7a`. Branch: `testing/vocle-performance-scale`. Upstream `master` and branch absence were checked on 2026-10-28 before creating the branch. The clean upstream clone matched Astra's investigation; there are no intervening commits or changed source paths. `origin` points only to the original upstream.

The full [architecture and conventions](plan/ARCHITECTURE-AND-CONVENTIONS.md) and [original investigation](plan/ORIGINAL-MASTER-REPORT.md) are frozen evidence. Preserve their distinction between verified source facts, inferred risks, workload hypotheses and runtime unknowns. [Source snapshot](source-snapshot.json) and [source map](source-map.json) pin the evidence; [stale references](stale-references.json) records drift. Source SHA identifies the application, while harness SHA is the eventual test-infrastructure commit; never conflate them.

The application uses HTTP to persist messages and Socket.IO for realtime delivery. Express and Socket.IO share a Node process; the configured Mongoose pool has ten connections. A successful HTTP send precedes in-process deferred delivery/notification work; no durable queue is verified. Channel-room and user-room emissions can deliver duplicate copies. Presence, typing caches and socket enumeration are process-local. No horizontal capacity claim is justified by repository inspection.

Receiver listeners must precede traffic. Transport connection, `authenticated`, and matching `join_channel` success events are distinct readiness stages. `join_channel` is an event response, not a callback acknowledgement. There is no implemented `send_message` listener and no general delivery-ack route. `/read` records direct-channel user reading. Provider acceptance does not prove device receipt. Recovery can skip middleware and requires independent identity, authorization and replay accounting.

The [operation map](source-map.json) expands every existing inventory identifier with `OP-`. It includes 87 feature-route method/path pairs. `OP-CH-05` and `OP-CH-06` are distinct aliases for the same case, not duplicate cases. Platform, realtime and background entries are separate from the 87 denominator. Static asset paths are inventory patterns, not additional Express feature registrations. Developer routes remain traceable but are forbidden as representative user workloads. API-001's generic all-route instruction is constrained by that explicit exclusion. System cases compose their selected feature dependencies rather than owning duplicate feature implementations; compute the dynamic prerequisite closure before execution.

The catalog materializes every original case's inherited fields, original specification and numbered implementation sequence. Runtime variant names are not invented in Phase 00; later owners must derive them from these preserved requirements. Catalog operation associations support traceability, not automatic workload selection. Missing scenario modules, required observations or decisions cannot produce a pass.

| Contract owner | Future interface |
|---|---|
| 01 | `defineScenario`, `validateRunConfig`, `assertIsolatedTarget`, `captureProvenance`, `allocateActors`, `registerOwnedResource`, `recordStage`, `recordOutcome`, `finalizeRun`, `cleanupOwnedResources` |
| 02 | `http.request` |
| 03 | `openCohort`, `awaitApplicationReady`, `joinChannelAndWait`, `recordDelivery`, `closeCohort` |
| 07A | `runBarrierRound` |
| 10 | `buildDatasetManifest`, `verifyIndexes`, `sampleExplain` |
| 14 | `applyOwnedFault`, `restoreOwnedFault` |

Exact signatures and required behavior remain in the [shared interface contract](plan/ARCHITECTURE-AND-CONVENTIONS.md#exact-shared-utility-ownership). Phase 00 exports metadata only. Generic scenario/oracle/metrics/cleanup instructions in the phase template apply when cases are assigned; Phase 00 explicitly owns zero cases and excludes their implementation. This interpretation follows its scope and exclusions, and introduces no dependency on later code.

Versioned metadata starts at `schemaVersion: 1`. Breaking changes need reviewed migration. Future run configurations require immutable provenance, isolated target identity/address checks, deterministic synthetic actors/data, all finite traffic/resource/cost ceilings, deadlines for every stage, provider budgets and a cleanup journal. Runtime validation and enforcement belong to Phase 01. The B/C/L/T/P/Z/G/F bounds and E0-E5 environments in [F1-F3](plan/ARCHITECTURE-AND-CONVENTIONS.md#f1-case-specification-and-inherited-fields) are experiment hypotheses, not SLOs or authorized runtime configurations.

Keep implementation, review, static validation, execution and threshold state separate. Terminal run statuses remain `PASSED`, `FAILED_FUNCTIONAL`, `FAILED_PERFORMANCE`, `INVALID_GENERATOR`, `FAILED_INFRASTRUCTURE`, `ABORTED_LIMIT`, `BLOCKED_PREREQUISITE`, `NOT_EXECUTED`, and `INCONCLUSIVE`. Unknown baseline and product objectives remain `BASELINE_REQUIRED` and `PRODUCT_DECISION_REQUIRED`; no performance pass is possible from missing evidence.

Metrics use milliseconds, bytes, counts and rates/second with explicit clock domains. Keep scheduled/started/completed/censored/ambiguous work and accepted/persisted/emitted/received/inbox/provider/rendered stages separate. Merge compatible histogram counts, never worker percentiles. IDs belong in bounded ledgers. Provider doubles may replace only MSG91/FCM/Cloudinary boundaries; auth, bcrypt, persistence and business logic stay real. Journal intent before mutation, restore owned faults before cleanup, independently validate ownership and retain primary/cleanup failures separately. No such runtime functionality is implemented here.

Application behavior, dependency files, regression/security assertions and workflows remain unchanged. Artillery version selection and installation are deferred to Phase 01 review; Socket.IO observer compatibility is planned at 4.8.3. Capacity, production topology, actual indexes, provider limits and device behavior remain unknown.
