# Implementation progress

[README](README.md) · [Case matrix](TEST-CASE-MATRIX.md)

Documentation package creation does not implement or execute a test. All implementation/review/execution/threshold fields below are intentionally pending. Update only from actual evidence and preserve deferred cases.

| Phase | Cases | Implementation | Review | Execution | Threshold validation |
|---|---|---|---|---|---|
| [00](PHASE-00-FOUNDATION.md) | Shared contracts/integration | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [01](PHASE-01-HARNESS-CONTRACTS.md) | Shared contracts/integration | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [02](PHASE-02-HTTP-AUTHENTICATION.md) | PERF-API-001, PERF-AUTH-001, PERF-AUTH-002, PERF-AUTH-003 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [03](PHASE-03-SOCKET-COHORTS.md) | SCALE-RT-001, SCALE-RT-002 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [04](PHASE-04-NOTIFICATIONS.md) | PERF-NOT-001, PERF-NOT-002 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [05](PHASE-05-MESSAGING.md) | PERF-MSG-001, PERF-MSG-002, PERF-MSG-003, PERF-MSG-004 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [06](PHASE-06-PRESENCE-RECOVERY.md) | SCALE-RT-003, SCALE-RT-004, SCALE-RT-005 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [07A](PHASE-07A-REQUESTS-CONVERSATIONS.md) | PERF-SOC-001, PERF-SOC-002 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [07B](PHASE-07B-HISTORY-EXPANSION.md) | PERF-SOC-003 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [07C](PHASE-07C-SPACES-PINS.md) | PERF-SOC-004, PERF-SOC-005 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [08](PHASE-08-MEMBERSHIP-EVICTION.md) | SCALE-RT-006 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [09](PHASE-09-HANDOFFS.md) | PERF-HAND-001, PERF-HAND-002 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [10](PHASE-10-DATABASE-GROWTH.md) | PERF-DATA-001, PERF-DATA-002, PERF-DATA-003 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [11](PHASE-11-DISCOVERY-OPERATIONS.md) | PERF-SEARCH-001, PERF-SEARCH-002, PERF-OPS-001 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [12](PHASE-12-MEDIA.md) | PERF-MED-001, PERF-MED-002 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [13](PHASE-13-MIXED-LOAD.md) | PERF-MIX-001, LOAD-SYS-001 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [14](PHASE-14-RESILIENCE.md) | RES-DATA-001, RES-SYS-001, RES-SYS-002 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [15](PHASE-15-NETWORK-SLOW-CONSUMERS.md) | SCALE-RT-007, NET-SYS-001 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [16](PHASE-16-STRESS-SPIKE-SOAK.md) | STRESS-SYS-001, SPIKE-SYS-001, SOAK-SYS-001 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [17](PHASE-17-REPORTING-REGRESSION.md) | REG-SYS-001 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [18](PHASE-18-GITHUB-ACTIONS.md) | Shared contracts/integration | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [19](PHASE-19-ADVANCED-SCALING.md) | SCALE-SYS-001, SCALE-SYS-002 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |
| [20](PHASE-20-MOBILE-PERFORMANCE.md) | MOBILE-SYS-001 | NOT_IMPLEMENTED | NOT_REVIEWED | NOT_EXECUTED | BASELINE_REQUIRED / PRODUCT_DECISION_REQUIRED |

## Per-phase checklist

### Phase 00 — Freeze source, contracts, decisions and case ownership

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 01 — Build shared harness interfaces and isolation contracts

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 02 — Implement HTTP baseline, login, refresh and limiter scenarios

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 03 — Implement persistent receiver cohorts and fan-out accounting

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 04 — Implement notification amplification and inbox correctness

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 05 — Implement message, thread, retry and mutation scenarios

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 06 — Implement presence, typing and recovery scenarios

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 07A — Implement consent and unique conversation creation

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 07B — Implement full-history copy and partial-expansion scenarios

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 07C — Implement membership, invitation and pin races

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 08 — Implement membership/archive changes during live traffic

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 09 — Implement shift-change lifecycle and transition races

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 10 — Implement dataset growth, query/pool and TTL experiments

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 11 — Implement search, Needl, lists and admin/support interference

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 12 — Implement upload, delivery, deletion and avatar scenarios

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 13 — Compose personas and sustained normal-load scenarios

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 14 — Implement owned dependency/process failure scenarios

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 15 — Implement transport impairment and slow-receiver scenarios

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 16 — Implement saturation, bursts and long-running stability envelopes

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 17 — Implement statistical comparison and evidence reports

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 18 — Implement separate validation and authorized orchestration design

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 19 — Implement vertical and cross-instance scaling scenarios

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

### Phase 20 — Implement device performance and lifecycle observers

- [ ] Upstream branch/source identity verified and drift recorded.
- [ ] Scoped modules and case variants implemented.
- [ ] Independent correctness oracles and finite budgets reviewed.
- [ ] Static checks actually performed and documented.
- [ ] Existing regression/security assertions unchanged.
- [ ] Implementing-agent completion report captured.
- [ ] Explicit execution approval captured separately.
- [ ] Authorized external execution evidence recorded, including failures/cleanup.
- [ ] Baseline/product threshold decisions recorded separately.

## Completion record template

Date; agent; phase; upstream branch/base/HEAD; created/modified files; implemented/deferred IDs and variants; static checks; tests executed with authorization or none; limitations/decisions; next interfaces; reviewer; artifact links; cleanup state. Never collapse implementation and execution into one checkbox.
