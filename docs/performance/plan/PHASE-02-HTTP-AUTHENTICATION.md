# Phase 02 — Implement HTTP baseline, login, refresh and limiter scenarios

[Master index](README.md) · [Shared contracts](ARCHITECTURE-AND-CONVENTIONS.md) · [Decisions](DECISIONS-AND-ASSUMPTIONS.md) · [Progress](IMPLEMENTATION-PROGRESS.md)

**Implementation handoff; not test implementation.** Authoritative source: [complete original report](ORIGINAL-MASTER-REPORT.md), upstream master `4c01dc24247aa95a73e286a2b42c7f2f81257c7a`. Read README, shared contracts and this phase. Upstream SHA was rechecked during packaging and still matched; future drift must be recorded.

## A. Phase overview

- **Objective:** Implement HTTP baseline, login, refresh and limiter scenarios.
- **Why necessary:** Create route-template adapters with real auth; preserve bcrypt and OTP claim work; separate widget and server OTP; model IP/user limiter keys and refresh concurrency; expose device-registration fixtures.
- **Scope:** PERF-API-001; PERF-AUTH-001; PERF-AUTH-002; PERF-AUTH-003.
- **Exclusions:** Do not implement receiver cohort here or fake OTP computation in login performance cases.
- **Priority:** P0; individual priorities retained below.
- **Implementation prerequisites:** [01: Build shared harness interfaces and isolation contracts](PHASE-01-HARNESS-CONTRACTS.md)
- **Execution dependencies:** original case prerequisites below may reference later scenario implementations; these gate execution, not writing independent code. Missing interfaces block dependent implementation, not unrelated documentation.
- **Expected outcome:** reviewable modules/configurations, independent oracles and metrics, updated catalog/progress, without performance claims.
- **Relative effort:** M. Limit work to this batch.

## B. Relevant architecture and source evidence

Cited application files exist at the investigated SHA; section D paths are proposed. Preserve the copied technical facts and limitations below.

#### C2. Authentication and users

| ID | Method/path | Handler and source line | Auth/input → behavior | Sensitivity, risk, cases |
|---|---|---|---|---|
| AUTH-01 | POST `/api/auth/request-otp` | `requestOtp`:53 | Public; phone → OTP delivery attempt | bcrypt/provider/phone races; high; AUTH-001, RES-002 |
| AUTH-02 | POST `/api/auth/verify-otp` | `verifyOtp`:74 | Public; phone/otp → account/session | OTP claim, user create race; high; AUTH-001 |
| AUTH-03 | POST `/api/auth/verify-msg91-token` | `verifyMsg91Token`:99 | Public; phone/accessToken → verified session | provider latency/fallback; high; AUTH-001 |
| AUTH-04 | POST `/api/auth/refresh` | `refreshToken`:141 | Refresh JWT → new access token | IP limiter, synchronized expiry; high; AUTH-002/003 |
| AUTH-05 | POST `/api/auth/logout` | `logout`:173 | A; optional fcmToken → token removal | device cleanup; medium; AUTH-002 |
| USER-01 | GET `/api/users/me` | `getMe`:51 | A → profile | additional user read; medium; API-001 |
| USER-02 | PUT `/api/users/me` | `updateMe`:62 | A; profile/preferences/avatar → updated profile | preference lost updates; avatar deletion wait; medium/high; API-001, MED-002 |
| USER-03 | PUT `/api/users/me/availability` | `updateAvailability`:124 | A; status/until/note → DB update and presence | spaces-per-user amplification; high; RT-003 |
| USER-04 | PUT `/api/users/me/fcm-token` | `registerFcmToken`:174 | A; token → deduped/capped list | same-user concurrent saves; medium; AUTH-002 |
| USER-05 | GET `/api/users/search` | `searchUsers`:196 | A+O; q/spaceId → up to 20 users | known-user scan/regex; high; SEARCH-001 |
| USER-06 | GET `/api/users/lookup` | `lookupByPhone`:256 | A+O; phone → relationship/capabilities | repeated relationship queries; medium/high; SEARCH-001 |
| USER-07 | GET `/api/users/:id` | `getUserById`:185 | A → public profile | lookup/activity-write overhead; medium; API-001 |
| USER-08 | GET `/api/users/me/needl` | `getNeedl`:347 | A+O → up to 40 roots, reply-root probe capped 80 | sequential channel access; high; SEARCH-002 |

Sources: [auth routes][auth-routes], [auth controller][auth], [user routes][user-routes], [user controller][users].

## C. Test cases to implement

<a id="perf-api-001"></a>

### PERF-API-001 — Route-family baseline

**Priority:** P0. **Owner:** Phase 02. **Status:** PLANNED / NOT IMPLEMENTED / NOT EXECUTED.

#### Preserved original specification

- **Category/component/priority:** baseline; HTTP/auth middleware; P0.
- **Objective/risk:** establish low-load route cost before interpreting scalability; detect read routes with hidden writes.
- **Sources:** all inventory routes; especially `protect`:37–79, message feed:49, notifications:14.
- **Data/preconditions:** S dataset; valid role-specific accounts; fresh mutation targets; no shared state between variants.
- **Workload:** B; route-specific samples for profile, spaces, channels, messages, handoffs, notifications, support/admin, and platform reads. Mutations run only against disposable entities.
- **Actions/invariants:** validate actual response envelopes and persisted state; paginate without duplicates; record expected rejects separately.
- **Metrics/acceptance:** per-operation baseline, bytes, queries/writes per request; no pooled “all APIs” latency threshold.
- **Failure indicators:** unexpected 4xx/5xx, mismatched payload/state, hidden provider call, excessive unrelated background work.
- **Limits/cleanup:** B limits; reset mutated fixtures between samples.
- **Infrastructure/environment/automation:** E1; hosted yes; dedicated no; automatic.
- **Dependencies:** foundation only.

#### Detailed scenario logic

1. Build one variant per operation ID in the 87-route inventory, including the group-DM alias; classify public, authenticated, onboarded and platform-admin identities.
2. Prepare isolated mutation fixtures and capture the expected response envelope, status, result IDs and DB delta before measuring each variant.
3. Schedule B samples separately by route template; keep user activity writes and response serialization in scope; collect operation counts without combining unrelated percentiles.
4. Drain and reconcile mutation state, pagination and provider journal; retain expected rejection variants separately from successful requests.

#### Preconditions, results and required fields

- **Preconditions:** shared interfaces exist; later authorized setup validates isolated target identity, source/harness SHA, data/index manifest, provider mode and finite budgets. No setup executes in this documentation/development handoff.
- **Test data:** use case-specific dimensions above plus deterministic actor/resource manifests. Precompute expected audiences/state; keep negative/boundary variants distinct.
- **Concurrency and timing:** original profile above plus B/C/L/T/P/Z/G/F definitions below. Barrier races use coordinated release, not guessed sleeps. Record scheduled and actual arrival. Observation/drain deadlines are mandatory; expiry is censored/failure evidence.
- **Metrics:** preserve original metrics plus stage histograms, useful throughput, errors, generator health and relevant SUT/DB/provider/device resources. IDs belong in bounded ledgers, not unbounded metric labels.
- **Functional assertions:** implement original invariants and the numbered independent DB/event/state oracle. A 2xx is not proof of delivery, notification or rendering.
- **Expected results:** correct terminal state and complete eligible fault-free accounting; faults classify preserved/lost/rejected/ambiguous work. The current application may fail requirements; retain failures and do not repair it here.
- **Failure conditions:** invariant violation, unexpected egress, unexplained unfinished work, safety breach or missing evidence. Generator saturation invalidates measurement; undefined policy blocks the affected assertion without discarding observations.
- **Cleanup:** stop arrivals, bounded drain, capture terminal evidence, restore owned faults, close actors, remove only journal-owned data/assets/resources and independently verify. Preserve cleanup failures separately.
- **Execution environment / hosted versus dedicated:** original case E-code above is binding. E1 is small hosted characterization only; E2/E3 require dedicated measurement resources; E4 physical devices/controlled network; E5 sandbox approval. Hosted orchestration is not hosted capacity evidence.
- **Safety limits:** inherit F3 and tighter case limits. Missing numerical arrival/connection/event/byte/total-work/duration/provider ceilings block execution. Never extend a stage automatically.
- **Dependencies for execution:** Foundation only. Shared adapters can be authored earlier than the full prerequisite measurement case.
- **Unknown thresholds/product decisions:** `BASELINE_REQUIRED` and `PRODUCT_DECISION_REQUIRED` where not established; preserve specific conflicts above and consult the shared decision ledger.
- **Automation feasibility:** automated scenario/oracle/reporting; infrastructure and provider authorization external. Actual-device/real-push observations require their environment and are not proven by protocol doubles.

<a id="perf-auth-001"></a>

### PERF-AUTH-001 — Login computation and account races

**Priority:** P0. **Owner:** Phase 02. **Status:** PLANNED / NOT IMPLEMENTED / NOT EXECUTED.

#### Preserved original specification

- **Category/component/priority:** baseline/load/concurrency; OTP/widget login; P0.
- **Sources:** AUTH-01–03; OTP model:81–144; `issueAuthTokensForPhone`:24.
- **Data:** distinct synthetic phones plus a contested first-login identity; real OTP hashing/claim path; provider double.
- **Workload:** B and C, then L in E2. Separate server OTP, widget success, widget fallback, existing-user, and new-user variants.
- **Actions/invariants:** one user per phone; one successful claim per real OTP; correct failed-attempt behavior; provider failures issue no unintended session.
- **Metrics/acceptance:** hash/verify CPU, provider attempts, token latency, unique-index conflicts, account count. Performance `BASELINE_REQUIRED`.
- **Limits:** respect actual IP auth limiter; use controlled source addresses for scale. `OTP_BYPASS` must not substitute for OTP computation measurements.
- **Cleanup/environment:** owned users/OTPs; E1 characterization, E2 load; hosted small yes, sustained dedicated.
- **Dependencies:** API-001.

#### Detailed scenario logic

1. Seed distinct existing users and an absent contested phone; configure provider success, response rejection and transport-error modes.
2. Implement actual OTP issuance/hash and atomic claim; obtain synthetic OTP only through owned provider capture, never bypass the measured verification path.
3. Barrier concurrent first-account creation and repeated OTP claims; separately drive independent widget/server-OTP arrivals within authentic limiter constraints.
4. Compare users, claims, token issuance and provider attempts; include the failure boundary after OTP claim but before completed account creation.

#### Preconditions, results and required fields

- **Preconditions:** shared interfaces exist; later authorized setup validates isolated target identity, source/harness SHA, data/index manifest, provider mode and finite budgets. No setup executes in this documentation/development handoff.
- **Test data:** use case-specific dimensions above plus deterministic actor/resource manifests. Precompute expected audiences/state; keep negative/boundary variants distinct.
- **Concurrency and timing:** original profile above plus B/C/L/T/P/Z/G/F definitions below. Barrier races use coordinated release, not guessed sleeps. Record scheduled and actual arrival. Observation/drain deadlines are mandatory; expiry is censored/failure evidence.
- **Metrics:** preserve original metrics plus stage histograms, useful throughput, errors, generator health and relevant SUT/DB/provider/device resources. IDs belong in bounded ledgers, not unbounded metric labels.
- **Functional assertions:** implement original invariants and the numbered independent DB/event/state oracle. A 2xx is not proof of delivery, notification or rendering.
- **Expected results:** correct terminal state and complete eligible fault-free accounting; faults classify preserved/lost/rejected/ambiguous work. The current application may fail requirements; retain failures and do not repair it here.
- **Failure conditions:** invariant violation, unexpected egress, unexplained unfinished work, safety breach or missing evidence. Generator saturation invalidates measurement; undefined policy blocks the affected assertion without discarding observations.
- **Cleanup:** stop arrivals, bounded drain, capture terminal evidence, restore owned faults, close actors, remove only journal-owned data/assets/resources and independently verify. Preserve cleanup failures separately.
- **Execution environment / hosted versus dedicated:** original case E-code above is binding. E1 is small hosted characterization only; E2/E3 require dedicated measurement resources; E4 physical devices/controlled network; E5 sandbox approval. Hosted orchestration is not hosted capacity evidence.
- **Safety limits:** inherit F3 and tighter case limits. Missing numerical arrival/connection/event/byte/total-work/duration/provider ceilings block execution. Never extend a stage automatically.
- **Dependencies for execution:** [PERF-API-001](PHASE-02-HTTP-AUTHENTICATION.md#perf-api-001). Shared adapters can be authored earlier than the full prerequisite measurement case.
- **Unknown thresholds/product decisions:** `BASELINE_REQUIRED` and `PRODUCT_DECISION_REQUIRED` where not established; preserve specific conflicts above and consult the shared decision ledger.
- **Automation feasibility:** automated scenario/oracle/reporting; infrastructure and provider authorization external. Actual-device/real-push observations require their environment and are not proven by protocol doubles.

<a id="perf-auth-002"></a>

### PERF-AUTH-002 — Session expiry and multi-device contention

**Priority:** P0. **Owner:** Phase 02. **Status:** PLANNED / NOT IMPLEMENTED / NOT EXECUTED.

#### Preserved original specification

- **Category/component/priority:** concurrency/recovery; refresh/logout/FCM registration; P0.
- **Sources:** AUTH-04/05, USER-04; JWT generation:123–136; mobile refresh:274–307.
- **Data:** one identity with 1/2/3 devices; tokens around expiry; more than five registration attempts.
- **Workload:** C for writes; L across token expiry; device variant in E4.
- **Actions/invariants:** compare HTTP refresh coalescing with socket recovery refreshes; logout one token; ensure other device presence remains; verify token dedupe/cap and deactivated-account handling.
- **Metrics:** refresh attempts/logical expiry, 401 recovery time, active sockets, token list consistency.
- **Acceptance:** existing token-cap and active-account contracts; socket revocation timing needs explicit product policy.
- **Limits/cleanup:** no real FCM tokens; reset expiry settings and remove fixtures.
- **Environment:** E1/E2, E4 for actual client; hosted protocol subset yes; device/durable load dedicated.
- **Dependencies:** API-001, RT-001.

#### Detailed scenario logic

1. Allocate one identity to 1/2/3 device actors with independent sockets and tokens; record initial token array.
2. Coordinate simultaneous protected HTTP calls around expiry, concurrent registrations exceeding five distinct tokens, and one-device logout.
3. Observe HTTP refresh coalescing separately from socket recovery refreshes; keep one device connected while another disconnects; include account deactivation.
4. Reconcile token deduplication/cap, presence and retry outcomes; label active-socket revocation semantics as decision-dependent.

#### Preconditions, results and required fields

- **Preconditions:** shared interfaces exist; later authorized setup validates isolated target identity, source/harness SHA, data/index manifest, provider mode and finite budgets. No setup executes in this documentation/development handoff.
- **Test data:** use case-specific dimensions above plus deterministic actor/resource manifests. Precompute expected audiences/state; keep negative/boundary variants distinct.
- **Concurrency and timing:** original profile above plus B/C/L/T/P/Z/G/F definitions below. Barrier races use coordinated release, not guessed sleeps. Record scheduled and actual arrival. Observation/drain deadlines are mandatory; expiry is censored/failure evidence.
- **Metrics:** preserve original metrics plus stage histograms, useful throughput, errors, generator health and relevant SUT/DB/provider/device resources. IDs belong in bounded ledgers, not unbounded metric labels.
- **Functional assertions:** implement original invariants and the numbered independent DB/event/state oracle. A 2xx is not proof of delivery, notification or rendering.
- **Expected results:** correct terminal state and complete eligible fault-free accounting; faults classify preserved/lost/rejected/ambiguous work. The current application may fail requirements; retain failures and do not repair it here.
- **Failure conditions:** invariant violation, unexpected egress, unexplained unfinished work, safety breach or missing evidence. Generator saturation invalidates measurement; undefined policy blocks the affected assertion without discarding observations.
- **Cleanup:** stop arrivals, bounded drain, capture terminal evidence, restore owned faults, close actors, remove only journal-owned data/assets/resources and independently verify. Preserve cleanup failures separately.
- **Execution environment / hosted versus dedicated:** original case E-code above is binding. E1 is small hosted characterization only; E2/E3 require dedicated measurement resources; E4 physical devices/controlled network; E5 sandbox approval. Hosted orchestration is not hosted capacity evidence.
- **Safety limits:** inherit F3 and tighter case limits. Missing numerical arrival/connection/event/byte/total-work/duration/provider ceilings block execution. Never extend a stage automatically.
- **Dependencies for execution:** [PERF-API-001](PHASE-02-HTTP-AUTHENTICATION.md#perf-api-001), [SCALE-RT-001](PHASE-03-SOCKET-COHORTS.md#scale-rt-001). Shared adapters can be authored earlier than the full prerequisite measurement case.
- **Unknown thresholds/product decisions:** `BASELINE_REQUIRED` and `PRODUCT_DECISION_REQUIRED` where not established; preserve specific conflicts above and consult the shared decision ledger.
- **Automation feasibility:** automated scenario/oracle/reporting; infrastructure and provider authorization external. Actual-device/real-push observations require their environment and are not proven by protocol doubles.

<a id="perf-auth-003"></a>

### PERF-AUTH-003 — Limiter-constrained capacity

**Priority:** P0. **Owner:** Phase 02. **Status:** PLANNED / NOT IMPLEMENTED / NOT EXECUTED.

#### Preserved original specification

- **Category/component/priority:** load/spike/control behavior; rate limits; P0.
- **Sources:** `rateLimiter.js`:27–105; `app.js`:99 and trust-proxy setting.
- **Data:** many users behind one IP, one user across controlled IPs, independent users.
- **Workload:** low bounded bursts spanning configured windows; separate global, OTP, auth, upload variants.
- **Actions/invariants:** distinguish expected 429s from saturation; verify recovery after window; identify shared-NAT bottleneck.
- **Metrics:** accepted/limited rates, limiter keys, latency before/after limit, application/DB work rejected requests avoid.
- **Acceptance:** configured policy behavior; business suitability `PRODUCT_DECISION_REQUIRED`.
- **Limits:** no identity spoofing to bypass policy; no uncontrolled proxy headers; real deployment-mode limiter enabled.
- **Environment:** E1/E2; hosted small yes; distributed-IP characterization dedicated.
- **Dependencies:** AUTH-001/002.

#### Detailed scenario logic

1. Represent controlled source IP and authenticated user IDs as distinct dimensions; retain production-mode global limiter behavior.
2. Schedule bounded requests at window edges for global, OTP, shared-IP auth and per-user upload limits; never spoof headers to evade policy.
3. Count 429 admission separately from service failures and verify accepted requests resume after the applicable window.
4. Record configuration and any isolated ceiling variant explicitly; do not use NODE_ENV=test results as deployed policy capacity.

#### Preconditions, results and required fields

- **Preconditions:** shared interfaces exist; later authorized setup validates isolated target identity, source/harness SHA, data/index manifest, provider mode and finite budgets. No setup executes in this documentation/development handoff.
- **Test data:** use case-specific dimensions above plus deterministic actor/resource manifests. Precompute expected audiences/state; keep negative/boundary variants distinct.
- **Concurrency and timing:** original profile above plus B/C/L/T/P/Z/G/F definitions below. Barrier races use coordinated release, not guessed sleeps. Record scheduled and actual arrival. Observation/drain deadlines are mandatory; expiry is censored/failure evidence.
- **Metrics:** preserve original metrics plus stage histograms, useful throughput, errors, generator health and relevant SUT/DB/provider/device resources. IDs belong in bounded ledgers, not unbounded metric labels.
- **Functional assertions:** implement original invariants and the numbered independent DB/event/state oracle. A 2xx is not proof of delivery, notification or rendering.
- **Expected results:** correct terminal state and complete eligible fault-free accounting; faults classify preserved/lost/rejected/ambiguous work. The current application may fail requirements; retain failures and do not repair it here.
- **Failure conditions:** invariant violation, unexpected egress, unexplained unfinished work, safety breach or missing evidence. Generator saturation invalidates measurement; undefined policy blocks the affected assertion without discarding observations.
- **Cleanup:** stop arrivals, bounded drain, capture terminal evidence, restore owned faults, close actors, remove only journal-owned data/assets/resources and independently verify. Preserve cleanup failures separately.
- **Execution environment / hosted versus dedicated:** original case E-code above is binding. E1 is small hosted characterization only; E2/E3 require dedicated measurement resources; E4 physical devices/controlled network; E5 sandbox approval. Hosted orchestration is not hosted capacity evidence.
- **Safety limits:** inherit F3 and tighter case limits. Missing numerical arrival/connection/event/byte/total-work/duration/provider ceilings block execution. Never extend a stage automatically.
- **Dependencies for execution:** [PERF-AUTH-001](PHASE-02-HTTP-AUTHENTICATION.md#perf-auth-001), [PERF-AUTH-002](PHASE-02-HTTP-AUTHENTICATION.md#perf-auth-002). Shared adapters can be authored earlier than the full prerequisite measurement case.
- **Unknown thresholds/product decisions:** `BASELINE_REQUIRED` and `PRODUCT_DECISION_REQUIRED` where not established; preserve specific conflicts above and consult the shared decision ledger.
- **Automation feasibility:** automated scenario/oracle/reporting; infrastructure and provider authorization external. Actual-device/real-push observations require their environment and are not proven by protocol doubles.

## Original inherited case contract

### F1. Case specification and inherited fields

The catalog is normalized to avoid repeating the same safety and measurement text dozens of times. **Each case inherits all fields below; its entry supplies the operation-specific fields.** The implementation should materialize these into full machine-readable case records.

Every case has:

- **Status:** `PLANNED / NOT IMPLEMENTED / NOT EXECUTED`.
- **Common preconditions:** pinned upstream source and harness SHA; validated isolated target; seeded owned database; confirmed required indexes; provider mode recorded; generator calibrated; instrumentation operational.
- **Baseline acceptance:** `BASELINE_REQUIRED`.
- **Product latency/throughput/recovery objectives:** `PRODUCT_DECISION_REQUIRED`.
- **Functional acceptance:** the stated case invariants, checked independently of HTTP status.
- **Common failure indicators:** unexpected response/event errors, lost accepted work, incorrect state, growing unfinished work, generator inability to sustain arrivals, or a safety-limit breach.
- **Common metrics:** HTTP/event stage latency histograms, offered/completed rates, errors, correctness counts, generator telemetry, SUT CPU/RSS/heap/external memory/event-loop delay, DB utilization and query/pool metrics.
- **Common cleanup:** stop arrivals; bounded drain; capture terminal ledger; disconnect clients; remove only run-owned data/files/provider objects; verify cleanup. Fault tests restore connectivity/processes before cleanup.
- **Automation:** fully automatable except real-device/provider observations noted below.
- **Source references:** operation inventory entries plus the function references named in each case.
- **Dependencies:** `PERF-API-001` and validated foundation unless the case explicitly names others.
- **Limits:** the selected profile’s resource/traffic cap plus any tighter case-specific limit.

A timeout, unexecuted case, inconclusive measurement, or missing oracle must never become a pass.

### F2. Execution environments

| Code | Environment/infrastructure | Standard GitHub-hosted runner? | Dedicated infrastructure? |
|---|---|---|---|
| E0 | Static validation, no SUT/network load | Yes | No |
| E1 | Small isolated Node/Mongo/provider-double environment; bounded local generator | Yes, for characterization only | No |
| E2 | Separate fixed-resource generator, backend, MongoDB, provider-double host/network; OS/DB telemetry | Hosted runner may orchestrate, not supply defensible sustained capacity by assumption | Yes |
| E3 | E2 plus disposable multi-instance backend/load balancer and optional Mongo replica set | No as the measurement platform | Yes |
| E4 | E2 plus controlled network impairment and physical Android devices | Hosted runner only orchestrates/reporting | Yes |
| E5 | Explicitly approved provider sandbox and registered synthetic devices | A tiny integration check may be orchestrated there | Provider sandbox; dedicated generator for any sustained experiment |

### F3. Workload profiles and limits

Numbers below are **initial experiment bounds**, not promised capacity or acceptable production performance.

| Profile | Arrival/concurrency/ramp/duration | Limits |
|---|---|---|
| B: baseline | One actor, then 5 actors; 60-second ramp; 2-minute warm-up; 5-minute sample; three independent runs | E1 cap 10 HTTP starts/s, 20 connections, 20 synthetic accounts; no provider egress |
| C: race | 2, 5, then 10 actors synchronized at a barrier; up to 20 rounds; 10-minute overall limit | Fresh owned entity per round; no uncontrolled retry loop |
| L: load | 5-minute ramp, 5-minute warm-up, 30-minute steady state, 5-minute drain | Requires signed manifest with finite request/event/connection/byte caps |
| T: staircase | Start below known sustainable rate; increase offered rate 25% per 10-minute stage; maximum six stages | E2 only; stop at saturation/safety limit; no automatic unbounded escalation |
| P: spike | 5-minute base, 30-second bounded jump, 2-minute peak, 10-minute recovery | Peak explicitly capped; initially no more than 2× established stable rate |
| Z: soak | 10-minute ramp; 2-hour first pass; separately approved 8-hour pass; 15-minute drain | Provisioned storage budget, finite session churn, abort watchdog |
| G: growth | Same low offered rate across independent S/M/L datasets; 5-minute warm-up and 10-minute sample each | One data dimension changed at a time; setup excluded from timed sample |
| F: failure | 5-minute stable load; one bounded fault; restore; up to 10-minute recovery | Initial outage 15 seconds, then separately 60 seconds; process-owned resources only |

For E2–E5, **missing numerical limits block execution**. The manifest must specify maximum connections, new connections/s, HTTP/s, messages/s, application events/s, total requests/messages, transferred bytes, duration, database growth, and provider calls.

Initial watchdog defaults may stop at 85% container memory or 20% free-disk reserve, but these are operational safeguards, **not SLOs**. Final budgets must be selected from the provisioned environment.

## D. Implementation instructions

### Proposed files and ownership

- `tests/performance/scenarios/http/`
- `tests/performance/scenarios/auth/`
- `tests/performance/providers/msg91/`
- `tests/performance/oracles/auth/`

These are future repository paths, not code created by this task. Existing application files in B are read-only references. Store run artifacts separately from source.

### Implementation tasks

Create route-template adapters with real auth; preserve bcrypt and OTP claim work; separate widget and server OTP; model IP/user limiter keys and refresh concurrency; expose device-registration fixtures.

1. Revalidate affected signatures and record drift; do not silently alter requirements.
2. Add assigned variants to catalog using exact case/operation IDs.
3. Develop scenario hooks using immutable actor/data manifests and shared adapters.
4. Build independent state/event oracles; do not call the same business function to compute expected state.
5. Substitute provider boundaries only; retain real auth/persistence/access/business computation.
6. Integrate schema-compatible histograms and terminal statuses, retaining timeout/censored outcomes.
7. Journal resources before mutation; cleanup/fault restore survive partial setup and exceptions.
8. Update source map, decisions, progress and interface documentation.

### Framework/configuration

Use Artillery scheduling and Node Socket.IO 4.8.3 observer contracts. Lock exact harness dependency versions during implementation; do not alter backend dependencies. Validated versioned JSON creates bounded scheduler inputs; never accept an arbitrary URL as the target contract. Device code uses new performance-only Flutter instrumentation.

### Imported interfaces

Phase 01: `validateRunConfig`, `assertIsolatedTarget`, `captureProvenance`, `allocateActors`, `registerOwnedResource`, `recordStage`, `recordOutcome`, `finalizeRun`, `cleanupOwnedResources`.
Phase 02: shared HTTP adapter.
Phase 03: `openCohort`, `awaitApplicationReady`, `joinChannelAndWait`, `recordDelivery`, `closeCohort`.
Phase 07A: `runBarrierRound`.
Phase 10: `buildDatasetManifest`, `verifyIndexes`, `sampleExplain`.
Phase 14: `applyOwnedFault`, `restoreOwnedFault`.

Exact proposed signatures are in [shared contracts](ARCHITECTURE-AND-CONVENTIONS.md). If a later interface is needed, declare the dependency and implement independent config/oracle logic; do not clone the utility. Fault activation remains deferred. Every scenario exports metadata and `prepare/run/observe/reconcile/cleanup` hooks. Module import performs no network access/startup. Missing prerequisites return BLOCKED_PREREQUISITE.

### Error handling, logging and cleanup

Use finally-style restoration plus supervisor recovery after process death. Preserve primary and cleanup failures separately. Bound retries, waits and evidence buffers. Log run/case/variant/operation and redacted error classes; no credentials, full tokens, personal data or full provider payloads. Every abort/missing observation appears in the report; no continue-on-error conversion to success.

### Documentation updates

Record changed interfaces and next-phase prerequisites. New genuine gaps go to proposed-addition ledger, not the original catalog. Keep implemented/executed status separate.

## E. Acceptance criteria

### 1. Implementation completeness

Every assigned ID/variant has scenario logic, finite configuration, deterministic data, independent correctness oracles, stage metrics and owned cleanup. Shared utilities are reused. Deferred variants retain reason, owner and prerequisite. No duplicate ownership or silent omissions.

### 2. Static/code-review validation

Revalidate paths/handlers against the pinned source and record drift. Parse configuration/schema/syntax without application imports or target startup. Check correct event names, finite limits, permissions, timing/accounting, propagation, redaction and cleanup ownership. Report checks actually performed, not proposed checks.

### 3. Execution validation

**NOT EXECUTED in this development handoff.** Later authorized execution must use the specified environment and calibrated generator, preserving offered/started/completed/censored work and terminal state. Infrastructure failure or missing observations cannot produce PASS. Load/performance execution stays outside Codex Cloud.

### 4. Performance threshold validation

`BASELINE_REQUIRED` until repeated valid measurements exist. Undefined production latency, throughput, recovery and loss requirements are `PRODUCT_DECISION_REQUIRED`. An invariant can fail without a latency threshold. Unknown thresholds produce NOT_EVALUATED/INCONCLUSIVE, never invented passing baselines.

### Completion condition

Implementation/review can finish while execution/thresholds remain pending. Mark implementation complete only after all scoped deliverables are implemented or explicitly deferred with approval and no blocking interface ambiguity remains. That condition never marks a case PASSED.


### Phase-specific gates

- Section D tasks and assigned numbered scenario sequences have concrete module/oracle mappings.
- Exact IDs/variants, source references, metrics and original constraints remain present.
- Exclusions honored: Do not implement receiver cohort here or fake OTP computation in login performance cases.
- Next agent can use exported interfaces without earlier chat history.
- No measured result is claimed by scaffold or document creation.

## F. Implementation restrictions

Work only in `mathiharan29/medcollab-beta`, based on upstream `master`, on `testing/vocle-performance-scale`. Never use the previous fork or edit master directly. Verify repository identity and capture branch/base/HEAD before future implementation; flag source drift rather than silently revising the plan.

Preserve existing regression/security suites and assertions. Do not alter application behavior to make a test pass. Application instrumentation or product fixes require separate explicit scope and review. Keep load execution separate from development.

**Do not run load/performance tests in Codex Cloud.** Do not start the app, MongoDB, Docker, Flutter, emulators, servers or infrastructure to validate implementation. Dependency installation, provisioning, application/regression/security/smoke tests and workflow execution need separate authorization. Default validation is read-only parsing, syntax/configuration review and source inspection without importing executable application code or contacting a target. Implementation approval is not execution approval.

No production connections/credentials, real patient information or personal data. No invented baselines/SLOs, silent skips, weakened assertions or pass from absent evidence. Real-provider sandbox use requires separate authorization, owned-resource journal, finite call/byte budget and cleanup.


## G. Required completion report

The implementing agent must report:

- Repository, branch, base SHA and resulting HEAD/commit; say if no commit was created.
- Files created/modified, separating harness, docs, workflows and approved instrumentation.
- Case IDs/variants implemented and deferred, with reasons/owners.
- Exact static checks and outcomes.
- Tests/workflows executed, if any, with explicit authorization/environment; otherwise **none**.
- Known limitations, source drift, unresolved product/technical decisions.
- Next-phase dependencies and exact exported interfaces.
- Separate implementation/review/execution/threshold status.
- Review checklist: upstream identity; unchanged assertions; finite budgets; privacy; no production access; unique IDs; cleanup journal; no invented baselines; no missing-result pass.


### Source-link definitions

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
