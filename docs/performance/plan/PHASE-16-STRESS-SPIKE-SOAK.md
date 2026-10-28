# Phase 16 — Implement saturation, bursts and long-running stability envelopes

[Master index](README.md) · [Shared contracts](ARCHITECTURE-AND-CONVENTIONS.md) · [Decisions](DECISIONS-AND-ASSUMPTIONS.md) · [Progress](IMPLEMENTATION-PROGRESS.md)

**Implementation handoff; not test implementation.** Authoritative source: [complete original report](ORIGINAL-MASTER-REPORT.md), upstream master `4c01dc24247aa95a73e286a2b42c7f2f81257c7a`. Read README, shared contracts and this phase. Upstream SHA was rechecked during packaging and still matched; future drift must be recorded.

## A. Phase overview

- **Objective:** Implement saturation, bursts and long-running stability envelopes.
- **Why necessary:** Reuse scenarios with bounded staircase, peak and soak profiles; record unfinished work, resource slopes and recovery; separate dataset growth from leaks.
- **Scope:** STRESS-SYS-001; SPIKE-SYS-001; SOAK-SYS-001.
- **Exclusions:** No heavy execution, unbounded escalation, or automatic PR load.
- **Priority:** P0; individual priorities retained below.
- **Implementation prerequisites:** [15: Implement transport impairment and slow-receiver scenarios](PHASE-15-NETWORK-SLOW-CONSUMERS.md)
- **Execution dependencies:** original case prerequisites below may reference later scenario implementations; these gate execution, not writing independent code. Missing interfaces block dependent implementation, not unrelated documentation.
- **Expected outcome:** reviewable modules/configurations, independent oracles and metrics, updated catalog/progress, without performance claims.
- **Relative effort:** L. Limit work to this batch.

## B. Relevant architecture and source evidence

Cited application files exist at the investigated SHA; section D paths are proposed. Preserve the copied technical facts and limitations below.

### E. Workload personas and traffic models

#### E1. Units

Use independent controls:

- **Virtual user:** one simulated actor with state.
- **Active user:** actor currently performing business actions.
- **Persistent connection:** one transport connection; a user can have several.
- **HTTP RPS:** attempted and completed HTTP requests per second.
- **Messages/s:** logical message-send operations and persisted messages separately.
- **Events/s:** emitted or received events; include duplicates.
- **Connections/s:** new connection attempts and application-ready connections separately.

For planning:

\[
C \approx U_{\text{connected}} \times D_{\text{devices}}
\]

\[
\lambda_{\text{messages}}
= \sum_p U_p a_p r_p
\]

Here \(a_p\) is the active fraction and \(r_p\) is messages per active second for persona \(p\).

Notification work depends on audience, active viewing, message priority, preferences, and tokens. It cannot be derived from message rate alone.

#### E2. Persona hypotheses

These are **starting hypotheses**, not production usage estimates.

| Persona | Proposed share | Actions and think time | Session/connection | Required data and key metrics |
|---|---:|---|---|---|
| Mostly idle | 45% | Infrequent dashboard/profile/notification reads, 2–5 minutes apart | 30–120 minutes, connected | Multiple spaces; bytes/connection, idle memory, heartbeat failures |
| Direct-message user | 20% | Bursts of 2–5 messages; 10–40 seconds between active sends; read/history actions | 15–45 minutes | Consented pairs; delivery latency, receipts, retry correctness |
| Group participant | 12% | View, scroll, reply, occasional reaction; 20–90 seconds | 20–60 minutes | Space channels and threads; fan-out, hot-root writes |
| Heavy broadcaster | 2% | Short bursts followed by long idle periods; emergency variant separate | 10–30 minutes | Larger space audience; all-recipient tail latency and amplification |
| Search-heavy | 5% | Search/category switching every 5–20 seconds during activity | 5–20 minutes | Common/rare/miss queries, many accessible channels |
| Media-heavy | 4% | Upload then message, 1–5 minutes between transfers | 10–30 minutes | Images/PDF/video; upload memory and later fetch latency |
| Reconnecting mobile | 5% | Resume, refresh, sync, reload, then short activity | 20–60 minutes with outages | Recoverable and expired recovery windows |
| Notification-heavy | 3% | Inbox reads, channel clearing, preference changes | 15–45 minutes | Large unread history, muted/quiet-hour branches |
| Multi-device | 2% | Two or three devices sharing one identity; independent viewing | 30–90 minutes | Token/register/logout races; presence correctness |
| Shift/handoff user | 2% | Draft, edit, submit, acknowledge, note, reassign | 15–40 minutes clustered by shift | Synthetic patients/attachments; transition consistency |

Treat admin traffic as a separate overlay, initially 0–2 simultaneous operators, rather than diluting the clinical-user distribution.

#### E3. Experimental mixes

Use four distinct mixes:

1. **Representative hypothesis mix:** table above.
2. **Read-heavy:** increase history, search, lists, and inbox activity; retain auth activity writes.
3. **Write/fan-out-heavy:** increase messages, threads, notifications, and hot-room concentration.
4. **Mobile shift-change:** synchronized reconnect, dashboard, handoff, and notification access.

Within each mix:

- Use skewed channel popularity, including a deliberately hot channel.
- Vary spaces/user and devices/user independently.
- Separate viewing recipients from connected non-viewers and offline recipients.
- Maintain multiple accounts; one token shared by all VUs is an invalid default.
- Use distributions for think time and payload size.
- Preserve legitimate repeated identical message content in correctness experiments.
- Model typed bursts with stop events and abandonment, not one typing event per message.

#### E4. Open and closed models

- **Open arrivals:** capacity, message throughput, connection storms, provider backlog.
- **Closed users:** human journeys and UI/device behavior.
- **Barrier concurrency:** competing writes and transition races.
- **Fixed connections plus independent arrivals:** realtime capacity and mixed workloads.

A closed-loop test can reduce offered load as the server slows. Always report that reduction rather than interpreting it as stable throughput.

---

### I. Metrics, observability, and thresholds

#### I1. Required metric stages

| Metric | Definition |
|---|---|
| HTTP scheduled latency | Scheduled arrival → terminal response/failure; captures generator delay |
| HTTP service-observed latency | Actual request start → response completion |
| Server processing | Server request entry → response finish; excludes client network |
| Application-ready connection | Connection attempt → `authenticated` |
| Channel-ready latency | `join_channel` emission → matching success event |
| Message acceptance | HTTP send start → successful response |
| Delivery latency | Send start → first receipt of message ID at a designated recipient |
| Fan-out tail | Send start → last expected eligible recipient receipt |
| Notification completion | Trigger → notification persistence/provider attempt completion, separately |
| Reconciliation latency | Reconnect/resume → client state agrees with authoritative history |
| Recovery time | Fault restoration → predefined stable useful service window |
| Correctness | Lost/duplicate persisted messages, missing deliveries, unauthorized deliveries, invalid state transitions |
| Backlog/debt | Accepted logical work minus completed corresponding stages |
| Generator health | CPU, memory, event-loop delay, socket count, NIC, arrival scheduling delay, dropped starts |

Do not average p95/p99 values across workers. Merge compatible histograms or raw bounded samples with sample counts.

#### I2. Correlation and clock design

For each logical message maintain:

- Run ID and logical action ID.
- Sender/user/device/channel identity.
- Scheduled/start/response timestamps.
- Persisted message ID once known.
- Expected recipient/device set and eligibility snapshot.
- Received message IDs and timestamps.
- Notification/provider evidence.
- Terminal status: completed, failed, ambiguous, censored, or unfinished.

The application has no observed idempotency/correlation field suitable for silently adding arbitrary protocol semantics. Initially:

- Place a synthetic marker in test text where appropriate.
- Map HTTP response ID to previously received events; events can arrive before the response.
- Keep intentional identical-text cases separate from marker-based cases.
- Use the same generator process/monotonic clock for baseline sender/receiver latency.
- For distributed workers, measure clock synchronization uncertainty or use a coordinator/round-trip design. Do not present unsynchronized one-way timings as precise.

#### I3. Current observability gaps

The backend currently provides console logging, Morgan request logging, health metadata, and selected error logs. No application metrics endpoint, distributed traces, side-effect queue metrics, or delivery acknowledgement ledger was found.

Also:

- Production Morgan uses combined format; it should not be assumed to expose detailed server processing timings.
- Socket debug logs are suppressed in production mode.
- Notification failures can be caught without failing the originating HTTP operation.
- Administrative “infrastructure” estimates are not actual resource measurements.

#### I4. Instrumentation levels

| Level | Changes required | What it establishes |
|---|---|---|
| External only | No application source changes; generator, reverse proxy, container/host and Mongo telemetry | HTTP/client latency, received events, DB state, resource trends |
| Diagnostic preload | New test-owned module loaded in an explicitly marked diagnostic run | Pool/driver events and bounded hooks, subject to measured overhead |
| Application instrumentation | Separate approved application change | Reliable server-stage timing, pending side effects, outcome counters, emit timing, trace correlation |
| Device instrumentation | New performance-specific Flutter instrumentation | Rendering/jank, parsing, cache/reconciliation, lifecycle |

Do not monkey-patch business handlers or replace MongoDB operations in a run advertised as application capacity. Provider doubles should replace only provider boundaries.

Application instrumentation is required for defensible internal queueing and stage-attribution claims. External-only tests can show symptoms but not always locate the responsible internal stage.

#### I5. Baseline and regression methodology

1. Pin source, harness, dependencies, OS/image, Node/DB versions, hardware limits, topology, dataset, seed, indexes, timezone, provider mode, and workload.
2. Record startup/index-build completion separately from warm-up.
3. Establish stable warm-up using resource/latency trends.
4. Run at least three initial independent repetitions; increase repetitions when variance prevents a conclusion.
5. Pair baseline/candidate experiments; randomize or alternate order.
6. Compare equal **offered** load and achieved load. Flag generator saturation.
7. Preserve timeouts/errors in accounting. Do not calculate “fast p99” from successful requests only while ignoring failures.
8. Use run-level or block-bootstrap confidence intervals, avoiding an assumption that every request is independent.
9. Define meaningful regression deltas only after noise characterization and product priorities.
10. Require both statistical evidence and practical significance.
11. Treat correctness failure as failure regardless of latency improvement.
12. Record inconclusive results explicitly.

Until approved:

- Latency thresholds: `BASELINE_REQUIRED`.
- Production SLOs: `PRODUCT_DECISION_REQUIRED`.
- Recovery objectives/RPO: `PRODUCT_DECISION_REQUIRED`.
- Capacity claim: permitted only for the specific measured workload/environment and validated stable duration.

---

## C. Test cases to implement

<a id="stress-sys-001"></a>

### STRESS-SYS-001 — Saturation and failure thresholds

**Priority:** P1. **Owner:** Phase 16. **Status:** PLANNED / NOT IMPLEMENTED / NOT EXECUTED.

#### Preserved original specification

- **Original category, priority, objective and source:** Stress/capacity, P1; locate first limiting resource
- **Original workload, data, actions and invariants:** T; separately HTTP, messages, connections, fan-out; change one dimension per run
- **Original metrics, acceptance, limits, environment and dependencies:** Saturation knee, errors, queue growth, recovery after load reduction; do not call failure point sustainable capacity; E2; depends LOAD-SYS-001

#### Detailed scenario logic

1. Select one established stable dimension: HTTP, messages, connections or fan-out; hold other dimensions and data fixed.
2. Apply T stages of 25% increases, at most six, with watchdog and finite total-work caps.
3. Identify first resource/debt/latency instability while validating generator headroom, then reduce load.
4. Verify recovery and retained correctness; label failure threshold separately from sustainable capacity.

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
- **Dependencies for execution:** [LOAD-SYS-001](PHASE-13-MIXED-LOAD.md#load-sys-001). Shared adapters can be authored earlier than the full prerequisite measurement case.
- **Unknown thresholds/product decisions:** `BASELINE_REQUIRED` and `PRODUCT_DECISION_REQUIRED` where not established; preserve specific conflicts above and consult the shared decision ledger.
- **Automation feasibility:** automated scenario/oracle/reporting; infrastructure and provider authorization external. Actual-device/real-push observations require their environment and are not proven by protocol doubles.

<a id="spike-sys-001"></a>

### SPIKE-SYS-001 — Shift-change demand spikes

**Priority:** P0. **Owner:** Phase 16. **Status:** PLANNED / NOT IMPLEMENTED / NOT EXECUTED.

#### Preserved original specification

- **Original category, priority, objective and source:** Spike, P0; shift-change login/connect/message/sync bursts
- **Original workload, data, actions and invariants:** P; independent spike variants then combined; maintain ordinary-user observers
- **Original metrics, acceptance, limits, environment and dependencies:** Setup success, recovery time, admitted/completed work, ordinary-user tails; finite peak/total caps; E2; depends AUTH-003, RT-003, LOAD-SYS-001

#### Detailed scenario logic

1. Establish base workload and normal-user observers; select login, connection, message or sync spike independently.
2. Apply bounded P peak initially no more than twice demonstrated stable rate; respect IP/user limiter behavior.
3. Track admitted/completed/censored operations and ordinary-user tails during peak and recovery.
4. Reconcile work and time-to-stability; combine spike types only after independent variants are interpretable.

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
- **Dependencies for execution:** [PERF-AUTH-003](PHASE-02-HTTP-AUTHENTICATION.md#perf-auth-003), [SCALE-RT-003](PHASE-06-PRESENCE-RECOVERY.md#scale-rt-003), [LOAD-SYS-001](PHASE-13-MIXED-LOAD.md#load-sys-001). Shared adapters can be authored earlier than the full prerequisite measurement case.
- **Unknown thresholds/product decisions:** `BASELINE_REQUIRED` and `PRODUCT_DECISION_REQUIRED` where not established; preserve specific conflicts above and consult the shared decision ledger.
- **Automation feasibility:** automated scenario/oracle/reporting; infrastructure and provider authorization external. Actual-device/real-push observations require their environment and are not proven by protocol doubles.

<a id="soak-sys-001"></a>

### SOAK-SYS-001 — Long-running resource stability

**Priority:** P1. **Owner:** Phase 16. **Status:** PLANNED / NOT IMPLEMENTED / NOT EXECUTED.

#### Preserved original specification

- **Original category, priority, objective and source:** Endurance, P1; memory/resource drift
- **Original workload, data, actions and invariants:** Z; session churn, channel churn, normal traffic, limited media; fixed-rate and fixed-data variants separated
- **Original metrics, acceptance, limits, environment and dependencies:** Heap/RSS/external slope, handles, sockets, cache cardinality, GC, DB growth, latency drift; no unexplained post-drain retention; E2; depends LOAD-SYS-001, RT-004, DATA-003

#### Detailed scenario logic

1. Choose fixed-data and controlled-growth variants with known session/channel churn and media budget.
2. Run Z first-pass two-hour profile; eight-hour profile is separately authorized, never an automatic continuation.
3. Collect memory/handles/sockets/cache/GC/DB-growth trends with periodic bounded correctness observations.
4. Stop arrivals, drain and inspect retention/recovery; separate intentional retained data from unexplained leaks.

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
- **Dependencies for execution:** [LOAD-SYS-001](PHASE-13-MIXED-LOAD.md#load-sys-001), [SCALE-RT-004](PHASE-06-PRESENCE-RECOVERY.md#scale-rt-004), [PERF-DATA-003](PHASE-10-DATABASE-GROWTH.md#perf-data-003). Shared adapters can be authored earlier than the full prerequisite measurement case.
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

- `tests/performance/workloads/stress.json`
- `tests/performance/workloads/spike.json`
- `tests/performance/workloads/soak.json`
- `tests/performance/lib/watchdog.mjs`
- `tests/performance/analysis/resource-drift.mjs`

These are future repository paths, not code created by this task. Existing application files in B are read-only references. Store run artifacts separately from source.

### Implementation tasks

Reuse scenarios with bounded staircase, peak and soak profiles; record unfinished work, resource slopes and recovery; separate dataset growth from leaks.

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
- Exclusions honored: No heavy execution, unbounded escalation, or automatic PR load.
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
