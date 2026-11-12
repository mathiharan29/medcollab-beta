# Decisions and assumptions

[README](README.md) · [Architecture](ARCHITECTURE-AND-CONVENTIONS.md) · [Full original](ORIGINAL-MASTER-REPORT.md)

**Source baseline and packaging recheck:** `4c01dc24247aa95a73e286a2b42c7f2f81257c7a`. No upstream drift detected by the single packaging SHA check. Future changes require affected-path revalidation; the approved plan is not silently retargeted.

## M. Open decisions

### Product decisions

1. Expected users, connected fraction, active fraction, devices/user, geographic distribution, and shift-change peaks.
2. p95/p99 objectives by operation class.
3. Acceptable delivery completeness window and recovery RTO/RPO.
4. Meaning of “delivered”: persisted, emitted, client received, displayed, or read.
5. Conflict policy for competing edits, reactions, preference changes, and reassignments.
6. Required session revocation behavior for already-connected/recovered sockets.
7. How to resolve author-only draft policy versus admin-readable implementation.
8. Backend 50 MiB versus client 25 MiB upload limit.
9. Maximum supported space membership, history, handoff size, and list cardinality.
10. Whether synchronous unbounded history copy remains the intended user experience.
11. Baseline-relative regression tolerance and cost budget.

### Technical decisions

1. Fixed E2 topology, Mongo version/topology, storage, CPU/memory limits, and network placement.
2. Separate deployment-policy measurements from controlled application-ceiling experiments.
3. Instrumentation scope allowed in application code.
4. Whether durable post-send processing/idempotency is prerequisite product work.
5. Multi-instance architecture and recovery-compatible adapter choice.
6. Source-IP strategy for auth load without disabling or spoofing real policy.
7. Provider simulator design and overhead target.
8. Physical device set and release/profile build configuration.
9. Artifact retention and baseline promotion policy.

---

## N. Missing evidence and assumptions

Not verified in this investigation:

- Actual production topology, instance count, hardware, reverse proxy, TLS termination, or autoscaling.
- MongoDB server version, replica topology, actual indexes, storage, connection limits, concerns, or query plans.
- Production traffic distribution, history sizes, upload sizes, or user concurrency.
- Any measured latency, throughput, leak, capacity, failure threshold, or recovery time.
- Actual external-provider account tiers, quotas, latency distributions, or delivery guarantees.
- Current deployment revision.
- Current CI run outcomes.
- Device performance and real network behavior.
- Runtime dependency defaults not explicitly configured in source.

Important assumptions to validate:

- A dedicated isolated environment can be provisioned later.
- Synthetic provider doubles can reproduce response shapes without replacing application logic.
- Infrastructure metrics and Mongo driver/pool observations can be collected.
- Product decisions in the upstream ledger are authoritative unless superseded.
- A fixed workload and dataset can be retained long enough for repeated comparison.

The source inventory is strong evidence of **what to test**, not evidence that the application passes those tests.

---

## O. Critical design review

| Challenge | Resolution in this plan |
|---|---|
| Are we measuring application or generator? | Separate hosts, generator telemetry, scheduled-arrival delay, calibration, invalid-run status |
| Are synthetic users realistic? | Persona distributions, idle connections, skew, multi-device state, viewing/offline distinctions, usage hypotheses labelled |
| Are we exercising actual backend behavior? | Real Express/auth/Mongoose/Socket.IO paths; provider-boundary substitution only |
| Are Socket.IO interactions correct? | Native client, app-ready event, explicit join response, separate recovery/socket-replacement modes |
| Can DB contention distort results? | Ten-pool baseline, hidden activity writes, hot/cold comparisons, independent query plans |
| Can providers distort backend conclusions? | Provider modes and timing reported separately; no bulk real-provider load |
| Could tests target production? | Fixed repository, target allowlist, isolation identity, blocked egress, explicit budgets |
| Could tests pass while losing messages? | Accepted/persisted/received/notification ledgers and post-run DB reconciliation |
| Are thresholds justified? | No invented SLO; baseline/noise characterization first |
| Can infrastructure failure be distinguished? | Separate infrastructure, generator, correctness, performance, abort, and inconclusive outcomes |
| Can results be reproduced? | Source/harness/runtime/data/index/topology/fault manifests |
| Are cases unnecessarily duplicated? | Route aliases are variants; system-level envelopes reuse feature scenarios; no case per cosmetic path |
| Are runner assumptions realistic? | Hosted runners limited to static/small characterization; capacity on calibrated dedicated infrastructure |
| Can implementation avoid application changes? | External measurement and most scenarios can; internal attribution and remediation cannot always |
| Which results require instrumentation? | Deferred-work counts, pool waiting, stage tracing, outbound buffering, actual UI/rendering |
| What could make results misleading? | Counting 201 as delivery; ignoring timeouts; bypassed limiter; fake OTP computation; zero-latency provider; averaging quantiles; changing data/indexes between runs; assuming successful recovery; unobserved recipients |

### Final architectural recommendations

- Make **correctness under load a prerequisite for capacity claims**.
- Prioritize message accounting, fan-out, DB pool competition, full-history expansion, and recovery.
- Treat horizontal scaling as a **correctness investigation first**.
- Preserve separate outcomes for persistence, realtime, inbox, provider acceptance, and actual device receipt.
- Keep current business behavior unchanged in the testing branch; submit product fixes and instrumentation separately when needed.
- Use narrowly scoped, evidence-driven optimization experiments after establishing the unchanged baseline.

---

## Existing product contracts and conflicts

The original product ledger remains authoritative planning evidence: expansion all has no 500 cap; today uses phone-local midnight; copied thread/quote graph remaps; source preview ID is permitted; group membership uniqueness; lost-send reconciliation; author-only handoff drafts; immediate presence eviction; server-timezone quiet hours. Do not invent replacements.

| Decision/risk | Affected phase/cases | Implementation instruction |
|---|---|---|
| Draft author-only versus admin-readable detail | Phase 09, HAND cases | Keep policy oracle and implementation observation separate; no assertion weakening |
| No server send idempotency key observed | Phase 05, MSG-003 | Characterize persisted duplicates and UI reconciliation; product fix separate |
| Channel room eviction not guaranteed by space sync | Phase 08, RT-006 | Observe late payloads across devices/recovery, not just presence |
| Client 25 MiB versus backend 50 MiB | Phase 12/20, MED/MOBILE | Keep backend-boundary and client-flow variants distinct |
| Competing edits/reassignments/conflict winner | Phases 05/07/09 | Record approved state machine or block only undefined assertion |
| Active/recovered token expiry and revocation | Phases 02/06/08 | Product policy pending; do not assume per-event JWT check |
| Durable side effects and horizontal adapter | Phases 14/19 | Tests may reveal limitations; implementation is separate app work |
| Product SLO/RTO/RPO and target usage | Phases 13–20 | BASELINE_REQUIRED/PRODUCT_DECISION_REQUIRED; no invented thresholds |
| Instrumentation permission | Phases 01/10/14/20 | External first; explicit separate scope for app hooks |
| Fixed infra/provider budget | Phases 14–20 | Finite run manifests and separate authorization before execution |

## Approval boundaries

This task authorizes documentation files and ZIP only. Future implementation approval authorizes code in the dedicated upstream branch, not runtime execution, real-provider access, dependency installation, infrastructure provisioning, application fixes, commits/pushes/PRs beyond the user's explicit instruction. Load/performance tests must not run in Codex Cloud even if code is developed there; execution belongs to the approved external environment.

## New-case proposals

**None added.** The original 45 IDs remain unchanged. A future genuine gap must be submitted here with evidence, proposed ID, impact and approval state; it must not silently enter the original coverage denominator.

## Handoff clarification

The original compact system-case table did not supply standalone titles. Their titles in these documents are descriptive expansions of the unchanged row objectives, not new cases. Original wording is retained in each case. Case dependencies are expanded to canonical IDs; dynamic mixed-workload prerequisite closure must include every selected feature variant, not just the initially enumerated representative dependencies.


[package]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/package.json
[app]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/app.js
[server]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/server.js#L82
[db]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/config/database.js#L56
[railway]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/railway.json
[auth-middleware]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/middleware/auth.js#L37
[limits]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/middleware/rateLimiter.js#L60
[auth]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/auth/auth.controller.js
[auth-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/auth/auth.routes.js
[otp-model]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/auth/otp.model.js#L70
[otp-service]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/services/otp.service.js
[msg91]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/services/msg91Widget.service.js#L107
[users]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/users/user.controller.js
[user-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/users/user.routes.js
[user-model]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/users/user.model.js
[spaces]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/spaces/space.controller.js
[space-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/spaces/space.routes.js
[space-model]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/spaces/space.model.js
[channels]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/channels/channel.controller.js
[channel-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/channels/channel.routes.js
[channel-model]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/channels/channel.model.js#L150
[messages]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/messages/message.controller.js
[message-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/messages/message.routes.js
[message-model]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/messages/message.model.js
[requests]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/message-requests/messageRequest.controller.js
[request-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/message-requests/messageRequest.routes.js
[request-model]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/message-requests/messageRequest.model.js
[handoffs]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/handoffs/handoff.controller.js
[handoff-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/handoffs/handoff.routes.js
[handoff-model]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/handoffs/handoff.model.js
[notifications]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/notifications/notification.controller.js
[notification-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/notifications/notification.routes.js
[notification-model]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/notifications/notification.model.js
[notify]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/services/notification.service.js
[search]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/search/search.controller.js
[known]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/utils/knownUsers.js#L49
[media]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/media/media.controller.js
[media-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/media/media.routes.js
[socket]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/socket/index.js
[presence]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/socket/handlers/presence.handler.js
[typing]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/socket/handlers/message.handler.js
[rooms]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/socket/spaceRooms.js
[admin]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/admin/admin.controller.js
[admin-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/admin/admin.routes.js
[support]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/support/support.controller.js
[support-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/support/support.routes.js
[dev-routes]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-backend/src/features/dev/dev.routes.js
[client-socket]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-app/lib/core/socket/socket_client.dart
[client-cache]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/medcollab-app/lib/core/chat/chat_transcript_cache.dart
[runtime]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/scripts/vocle-runtime-lock.json
[decisions]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/docs/PRODUCT_DECISIONS_2026-10-25.md
[provider-preload]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/tests/functional-regression/providers/preload.cjs
[ci-functional]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/.github/workflows/vocle-functional-regression.yml
[ci-security]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/.github/workflows/vocle-api-realtime-security.yml
[ci-cloudinary]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/.github/workflows/vocle-cloudinary-security.yml
[ci-reporting]: https://github.com/mathiharan29/medcollab-beta/blob/4c01dc24247aa95a73e286a2b42c7f2f81257c7a/.github/workflows/vocle-reporting.yml
