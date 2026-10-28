# Decisions and unresolved requirements

The complete [Astra decision ledger](plan/DECISIONS-AND-ASSUMPTIONS.md) remains unchanged, including all 11 product questions, nine technical questions, missing evidence, assumptions, design review and new-case proposal policy. The upstream [product decisions](../PRODUCT_DECISIONS_2026-10-25.md) remain authoritative. No product question is resolved by implementation convenience.

Phase 00 revalidated the following conflicts at source `4c01dc24247aa95a73e286a2b42c7f2f81257c7a`. These are existing source/policy differences and risks, not drift from Astra's baseline or executed failures.

| ID | Evidence | Affected cases / owner | Disposition and gate |
|---|---|---|---|
| DRAFT-VISIBILITY | Product Q3 says author only; `getHandoffById` permits an admin while draft. | PERF-HAND-001/002 / 09 | PRODUCT_DECISION_REQUIRED for conflicting visibility assertion; preserve policy and observed source separately. No assertion weakening or app fix. |
| MEDIA-LIMIT | Backend `MEDIA.MAX_FILE_SIZE_MB=50`; Flutter `maxFileSizeMb=25`. | PERF-MED-001/002, MOBILE-SYS-001 / 12,20 | PRODUCT_DECISION_REQUIRED; keep backend boundary and real client flow distinct. |
| SEND-IDEMPOTENCY | Product Q7 requires lost-send reconciliation; send handler has no server idempotency field. | PERF-MSG-003 / 05 | Characterize persisted duplicates and UI reconciliation. Do not invent an idempotency key or server acknowledgement. |
| ROOM-EVICTION | Product Q10 requires immediate presence eviction; `syncSocketSpaceRooms` synchronizes `space:*`, without guaranteed removal from `channel:*`. | SCALE-RT-005/006 / 06,08 | Observe all devices, recovery and late payloads. Do not equate presence removal with authorization convergence. |
| COPY-PREVIEW | Product Q2 permits destination preview to retain source ID; copy graph remaps copied thread/quote references. | PERF-SOC-003 / 07B | APPROVED_EXISTING_CONTRACT; source preview ID alone is not a broken-reference failure. Preserve no-500-cap and phone-local midnight requirements. |
| CONFLICT-WINNER | Competing edits, reactions, preferences and reassignments lack a complete approved winner policy. | PERF-MSG-004, PERF-SOC-001/004/005, PERF-HAND-002 / 05,07A,07C,09 | PRODUCT_DECISION_REQUIRED for undefined assertions only; independent invariants can still be implemented. |
| SESSION-REVOCATION | Ordinary authentication checks JWT; recovered sessions can skip middleware; per-event expiry is not established. | PERF-AUTH-002, SCALE-RT-005/006 / 02,06,08 | PRODUCT_DECISION_REQUIRED; do not assume token expiry immediately disconnects sockets. |
| LIMITER-MODE | Global limiter skips `NODE_ENV=test`; auth/upload retain their own keys and windows. | PERF-AUTH-003 / 02 | Separate deployment-policy characterization and controlled ceiling experiments; never spoof identity or silently disable policy. |
| DELIVERY-THRESHOLDS | Delivered-stage meaning, completeness window, SLO/RTO/RPO and usage distributions are unresolved. | All relevant cases / product owner | BASELINE_REQUIRED and PRODUCT_DECISION_REQUIRED; preserve stage observations without invented thresholds. |
| INFRA-AND-PROVIDERS | E2 topology, database/index evidence, budget, simulator overhead, horizontal adapter and device set are unknown. | 01,10,14,19,20 and execution owners | Missing finite limits/identity/authorization block execution; horizontal correctness precedes capacity. |
| INSTRUMENTATION | Internal side-effect debt/pool/render attribution needs suitable observability. | 01,10,14,20 | External measurement first; application hooks and product fixes require separate explicit scope. |
| RETENTION | Baseline promotion, statistical tolerance, artifact retention and cost policy remain open. | REG-SYS-001 / 17,18 | No promoted baselines or passing regression thresholds are fabricated. |

Source paths/lines and hashes are in [source-map.json](source-map.json) and [source-snapshot.json](source-snapshot.json). No unresolved decision blocks freezing metadata or starting independent Phase 01 development after user approval. Exact Artillery version/compatibility review belongs to Phase 01; no dependency installation is authorized by this handoff.

No additional case IDs are proposed. Genuine future gaps must be recorded with evidence, owner and approval state before changing the original denominator. All 45 original scenarios remain planned under their original owners.

## Phase 01 technical elaborations

No product policy above was resolved. The [implemented contracts](PHASE-01-CONTRACTS.md) use a reviewed allowlist and public-key-verified orchestrator evidence; the shipped key/target sets are empty. Real topology, grants, provider access, measurement calibration and application instrumentation remain future execution prerequisites. This fail-closed default does not block developing the interfaces.

Artillery 2.0.34 and socket.io-client 4.8.3 were selected and integrity-locked using registry metadata only ([review](DEPENDENCY-REVIEW.md)); compatibility and lifecycle/native/browser setup were not executed. The schema-shaped template is deliberately denied. Existing empty catalog variant slots will hold `{id,requiredMetrics}` when later owners implement cases; no original IDs or statuses changed. Named accounting functions can be run-bound ledger methods or stateless wrappers carrying an explicit ledger handle; no global accounting singleton or signature replacement was introduced.

Cooperative cancellation cannot establish that a remote mutation stopped. Deadline/abort ambiguity is quarantined before independent cleanup, unknown resource IDs never become prefix deletion, and external worker quiescence/fault restoration remain with later orchestration. Runtime filesystem/fsync/lock semantics, cancellation, actual schema-validator behavior and install compatibility remain explicitly unvalidated. These are execution limitations, not omitted Phase 01 development deliverables.
