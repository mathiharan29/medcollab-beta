# Vocle performance implementation plan

**Documentation-only handoff package.** Original repository: [mathiharan29/medcollab-beta](https://github.com/mathiharan29/medcollab-beta). Base: `master`. Future branch: `testing/vocle-performance-scale`. Investigation SHA: `4c01dc24247aa95a73e286a2b42c7f2f81257c7a`; packaging recheck matched. No test code, application changes or workflows were created or executed.

## Start here

1. Read this file.
2. Read [ARCHITECTURE-AND-CONVENTIONS.md](ARCHITECTURE-AND-CONVENTIONS.md).
3. Read your assigned phase document below. Its original cases, architecture and acceptance gates are self-contained with those two shared files.
4. Check visible [decisions](DECISIONS-AND-ASSUMPTIONS.md) only for affected unresolved requirements; stop dependent work if a required policy is missing, and continue independent work.
5. Implement only the assigned batch in the original upstream testing branch. No load/performance execution in Codex Cloud. Ask for separate execution authorization outside Codex Cloud.

**Give Phase 00 to Sol/Codex Cloud first.** The 23 documents refine the original Phase 0–9 roadmap into manageable ownership batches without changing any of the 45 case IDs. The history-copy and social-state work is explicitly split. Every phase distinguishes implementation, review, execution and threshold validation.

## Architecture in one page

Flutter uses HTTP for message persistence and Socket.IO for delivery/presence. Node/Express and Socket.IO share one process. Mongoose has a configured ten-connection pool. HTTP success precedes in-process message/handoff side effects; no durable queue is verified. Fan-out emits to channel and user rooms and can produce duplicate event copies. Presence, typing membership cache and room enumeration are process-local; horizontal correctness must precede capacity claims. Media uses a complete memory upload buffer and Cloudinary or synchronous local disk. MSG91 and FCM are external boundaries; load uses controlled doubles. Search/Needl/unpaginated lists/history expansion create data-volume risks. No measured SLO or capacity is available.

## Documents

- [Complete original master report](ORIGINAL-MASTER-REPORT.md) — verbatim authoritative investigation, including source-link definitions.
- [Shared architecture/contracts](ARCHITECTURE-AND-CONVENTIONS.md) — original technical inventory, risk/workload/environment/metrics/data/CI decisions plus concrete proposed interfaces.
- [Case matrix](TEST-CASE-MATRIX.md) — all 45 IDs, priorities, prerequisites, source references and unique ownership.
- [Decisions and assumptions](DECISIONS-AND-ASSUMPTIONS.md) — unresolved policies and approval boundaries.
- [Progress tracker](IMPLEMENTATION-PROGRESS.md) — all implementation and execution initially pending.
- [Documentation validation](DOCUMENTATION-VALIDATION.md) — actual file/link/coverage reconciliation results; not application tests.
- [Machine-readable ownership](CASE-OWNERSHIP.json) and [plan specification](PLAN-SPECIFICATION.json) — documentation metadata only, not executable tests or approved runtime configuration.

## Recommended implementation order

Follow this table top to bottom. Explicit predecessor interfaces must exist; no phase requires execution of the previous phase during development. Later execution follows the case dependency graph and environment prerequisites in the matrix.

| Phase | Scope | Original cases | Prerequisite implementation | Relative effort |
|---|---|---|---|---|
| [00 — FOUNDATION](PHASE-00-FOUNDATION.md) | Freeze source, contracts, decisions and case ownership | Shared artifacts; no new IDs | None | M |
| [01 — HARNESS-CONTRACTS](PHASE-01-HARNESS-CONTRACTS.md) | Build shared harness interfaces and isolation contracts | Shared artifacts; no new IDs | 00 | L |
| [02 — HTTP-AUTHENTICATION](PHASE-02-HTTP-AUTHENTICATION.md) | Implement HTTP baseline, login, refresh and limiter scenarios | PERF-API-001, PERF-AUTH-001, PERF-AUTH-002, PERF-AUTH-003 | 01 | M |
| [03 — SOCKET-COHORTS](PHASE-03-SOCKET-COHORTS.md) | Implement persistent receiver cohorts and fan-out accounting | SCALE-RT-001, SCALE-RT-002 | 02 | L |
| [04 — NOTIFICATIONS](PHASE-04-NOTIFICATIONS.md) | Implement notification amplification and inbox correctness | PERF-NOT-001, PERF-NOT-002 | 03 | L |
| [05 — MESSAGING](PHASE-05-MESSAGING.md) | Implement message, thread, retry and mutation scenarios | PERF-MSG-001, PERF-MSG-002, PERF-MSG-003, PERF-MSG-004 | 04 | XL |
| [06 — PRESENCE-RECOVERY](PHASE-06-PRESENCE-RECOVERY.md) | Implement presence, typing and recovery scenarios | SCALE-RT-003, SCALE-RT-004, SCALE-RT-005 | 05 | L |
| [07A — REQUESTS-CONVERSATIONS](PHASE-07A-REQUESTS-CONVERSATIONS.md) | Implement consent and unique conversation creation | PERF-SOC-001, PERF-SOC-002 | 06 | L |
| [07B — HISTORY-EXPANSION](PHASE-07B-HISTORY-EXPANSION.md) | Implement full-history copy and partial-expansion scenarios | PERF-SOC-003 | 07A | L |
| [07C — SPACES-PINS](PHASE-07C-SPACES-PINS.md) | Implement membership, invitation and pin races | PERF-SOC-004, PERF-SOC-005 | 07B | L |
| [08 — MEMBERSHIP-EVICTION](PHASE-08-MEMBERSHIP-EVICTION.md) | Implement membership/archive changes during live traffic | SCALE-RT-006 | 07C | M |
| [09 — HANDOFFS](PHASE-09-HANDOFFS.md) | Implement shift-change lifecycle and transition races | PERF-HAND-001, PERF-HAND-002 | 08 | L |
| [10 — DATABASE-GROWTH](PHASE-10-DATABASE-GROWTH.md) | Implement dataset growth, query/pool and TTL experiments | PERF-DATA-001, PERF-DATA-002, PERF-DATA-003 | 09 | L |
| [11 — DISCOVERY-OPERATIONS](PHASE-11-DISCOVERY-OPERATIONS.md) | Implement search, Needl, lists and admin/support interference | PERF-SEARCH-001, PERF-SEARCH-002, PERF-OPS-001 | 10 | L |
| [12 — MEDIA](PHASE-12-MEDIA.md) | Implement upload, delivery, deletion and avatar scenarios | PERF-MED-001, PERF-MED-002 | 11 | L |
| [13 — MIXED-LOAD](PHASE-13-MIXED-LOAD.md) | Compose personas and sustained normal-load scenarios | PERF-MIX-001, LOAD-SYS-001 | 12 | L |
| [14 — RESILIENCE](PHASE-14-RESILIENCE.md) | Implement owned dependency/process failure scenarios | RES-DATA-001, RES-SYS-001, RES-SYS-002 | 13 | XL |
| [15 — NETWORK-SLOW-CONSUMERS](PHASE-15-NETWORK-SLOW-CONSUMERS.md) | Implement transport impairment and slow-receiver scenarios | SCALE-RT-007, NET-SYS-001 | 14 | L |
| [16 — STRESS-SPIKE-SOAK](PHASE-16-STRESS-SPIKE-SOAK.md) | Implement saturation, bursts and long-running stability envelopes | STRESS-SYS-001, SPIKE-SYS-001, SOAK-SYS-001 | 15 | L |
| [17 — REPORTING-REGRESSION](PHASE-17-REPORTING-REGRESSION.md) | Implement statistical comparison and evidence reports | REG-SYS-001 | 16 | L |
| [18 — GITHUB-ACTIONS](PHASE-18-GITHUB-ACTIONS.md) | Implement separate validation and authorized orchestration design | Shared artifacts; no new IDs | 17 | M |
| [19 — ADVANCED-SCALING](PHASE-19-ADVANCED-SCALING.md) | Implement vertical and cross-instance scaling scenarios | SCALE-SYS-001, SCALE-SYS-002 | 18 | XL |
| [20 — MOBILE-PERFORMANCE](PHASE-20-MOBILE-PERFORMANCE.md) | Implement device performance and lifecycle observers | MOBILE-SYS-001 | 19 | L |


## Mapping from original roadmap

| Original phase | Refined documents |
|---|---|
| 0 Contracts/decisions | 00 |
| 1 Foundation | 01 |
| 2 Baseline/auth | 02 |
| 3 Realtime/message correctness | 03, 05, 06, 08 |
| 4 Business concurrency | 07A, 07B, 07C, 09 |
| 5 Data/search/media/providers | 04, 10, 11, 12 |
| 6 Mixed/fault/network/long-run | 13, 14, 15, 16 |
| 7 Reports/baselines | 17 |
| 8 CI safeguards | 18 |
| 9 Advanced scaling/devices | 19, 20 |

Notification implementation precedes message load composition because message fan-out depends on its accounting. All shared metrics/provenance/guards begin in Phase 01; Phase 17 adds analysis and comparisons. Numeric order is a conservative implementation order, not a claim that all work must execute sequentially.

## Runtime separation

- Ordinary PRs: future static validation only; existing regression/security workflows preserved.
- Manual E1: tiny hosted characterization, no capacity certification.
- E2/E3: separated calibrated generator, backend and DB; dedicated resources.
- E4: physical devices and controlled network.
- E5: explicitly approved bounded provider sandbox, never bulk real-provider load.
- No load/performance tests in Codex Cloud; no implementation approval implicitly authorizes tests/provisioning.

## Agent completion requirements

Each phase defines its full report. Always include files, implemented/deferred cases, static checks, explicitly authorized tests or none, limitations/decisions, next interfaces and branch/commit details. Do not invent commits or test results. Missing evidence, skipped cases and unknown thresholds cannot pass.

## Coverage and provenance

45 original cases assigned once; no additional test cases invented. 20 original architectural risks retained. Full original source inventory, workload models, environment definitions, threshold methodology, provider isolation and CI plan preserved in shared documents. A future source change must produce a stale-reference entry rather than rewriting this plan silently.

The source report's exact UTF-8 content hash and mechanical reconciliation results are in DOCUMENTATION-VALIDATION.md. Markdown links inside the package are relative so the ZIP can move between environments.

## Complete package tree

```text
vocle-performance-implementation-plan/
  ARCHITECTURE-AND-CONVENTIONS.md
  CASE-OWNERSHIP.json
  DECISIONS-AND-ASSUMPTIONS.md
  DOCUMENTATION-VALIDATION.md
  IMPLEMENTATION-PROGRESS.md
  ORIGINAL-MASTER-REPORT.md
  PHASE-00-FOUNDATION.md
  PHASE-01-HARNESS-CONTRACTS.md
  PHASE-02-HTTP-AUTHENTICATION.md
  PHASE-03-SOCKET-COHORTS.md
  PHASE-04-NOTIFICATIONS.md
  PHASE-05-MESSAGING.md
  PHASE-06-PRESENCE-RECOVERY.md
  PHASE-07A-REQUESTS-CONVERSATIONS.md
  PHASE-07B-HISTORY-EXPANSION.md
  PHASE-07C-SPACES-PINS.md
  PHASE-08-MEMBERSHIP-EVICTION.md
  PHASE-09-HANDOFFS.md
  PHASE-10-DATABASE-GROWTH.md
  PHASE-11-DISCOVERY-OPERATIONS.md
  PHASE-12-MEDIA.md
  PHASE-13-MIXED-LOAD.md
  PHASE-14-RESILIENCE.md
  PHASE-15-NETWORK-SLOW-CONSUMERS.md
  PHASE-16-STRESS-SPIKE-SOAK.md
  PHASE-17-REPORTING-REGRESSION.md
  PHASE-18-GITHUB-ACTIONS.md
  PHASE-19-ADVANCED-SCALING.md
  PHASE-20-MOBILE-PERFORMANCE.md
  PLAN-SPECIFICATION.json
  README.md
  TEST-CASE-MATRIX.md
```
