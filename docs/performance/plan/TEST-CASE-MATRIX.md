# Test-case matrix and coverage reconciliation

[README](README.md) · [Original master](ORIGINAL-MASTER-REPORT.md) · [Progress](IMPLEMENTATION-PROGRESS.md)

**Original catalog: 45 cases (34 detailed feature cases + 11 system-level cases). Assigned: 45. Independent duplicate owners: 0. Unassigned: 0. New cases: 0.**

Every row remains PLANNED / NOT IMPLEMENTED / NOT EXECUTED. Dependencies are execution prerequisites, not permission to run. Source paths and exact handlers are preserved in the linked case and its phase architecture; full 87-route inventory is preserved in shared architecture. Priorities copied from the original, never inferred from implementation order.

| Original case ID | Title | Owner phase | Priority | Execution dependencies | Source/evidence | Status |
|---|---|---|---|---|---|---|
| [PERF-API-001](PHASE-02-HTTP-AUTHENTICATION.md#perf-api-001) | Route-family baseline | [PHASE-02-HTTP-AUTHENTICATION](PHASE-02-HTTP-AUTHENTICATION.md) | P0 | Foundation | all inventory routes; especially `protect`:37–79, message feed:49, notifications:14. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-AUTH-001](PHASE-02-HTTP-AUTHENTICATION.md#perf-auth-001) | Login computation and account races | [PHASE-02-HTTP-AUTHENTICATION](PHASE-02-HTTP-AUTHENTICATION.md) | P0 | PERF-API-001 | AUTH-01–03; OTP model:81–144; `issueAuthTokensForPhone`:24. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-AUTH-002](PHASE-02-HTTP-AUTHENTICATION.md#perf-auth-002) | Session expiry and multi-device contention | [PHASE-02-HTTP-AUTHENTICATION](PHASE-02-HTTP-AUTHENTICATION.md) | P0 | PERF-API-001, SCALE-RT-001 | AUTH-04/05, USER-04; JWT generation:123–136; mobile refresh:274–307. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-AUTH-003](PHASE-02-HTTP-AUTHENTICATION.md#perf-auth-003) | Limiter-constrained capacity | [PHASE-02-HTTP-AUTHENTICATION](PHASE-02-HTTP-AUTHENTICATION.md) | P0 | PERF-AUTH-001, PERF-AUTH-002 | `rateLimiter.js`:27–105; `app.js`:99 and trust-proxy setting. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-MSG-001](PHASE-05-MESSAGING.md#perf-msg-001) | Send throughput and hot-channel contention | [PHASE-05-MESSAGING](PHASE-05-MESSAGING.md) | P0 | PERF-API-001, SCALE-RT-002, PERF-NOT-001 | MSG-02; `sendMessage`:208–288. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-MSG-002](PHASE-05-MESSAGING.md#perf-msg-002) | Hot threads and reply aggregation | [PHASE-05-MESSAGING](PHASE-05-MESSAGING.md) | P0 | PERF-MSG-001 | MSG-03/04; replyCount update:255–267; `getThread`:295. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-MSG-003](PHASE-05-MESSAGING.md#perf-msg-003) | Lost response, duplicate events, and retry ambiguity | [PHASE-05-MESSAGING](PHASE-05-MESSAGING.md) | P0 | PERF-MSG-001, SCALE-RT-002 | MSG-02; socket emission:223–231; client `_replaceLocalMessage`:527 and `_messagesMatch`:660. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-MSG-004](PHASE-05-MESSAGING.md#perf-msg-004) | Reactions, edits, deletes, and read receipts | [PHASE-05-MESSAGING](PHASE-05-MESSAGING.md) | P0 | PERF-MSG-001, PERF-MSG-002 | MSG-05–08; model `toggleReaction`:260–291; deletion quote/preview repair:395–428. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [SCALE-RT-001](PHASE-03-SOCKET-COHORTS.md#scale-rt-001) | Connection establishment and persistent capacity | [PHASE-03-SOCKET-COHORTS](PHASE-03-SOCKET-COHORTS.md) | P0 | PERF-AUTH-001 | RT-01/02; server setup:93–161. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [SCALE-RT-002](PHASE-03-SOCKET-COHORTS.md#scale-rt-002) | Audience fan-out and delivery accounting | [PHASE-03-SOCKET-COHORTS](PHASE-03-SOCKET-COHORTS.md) | P0 | SCALE-RT-001 | RT-11, `resolveMessageAudienceIds`:120, `emitNewMessage`:198. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [SCALE-RT-003](PHASE-06-PRESENCE-RECOVERY.md#scale-rt-003) | Presence and room synchronization amplification | [PHASE-06-PRESENCE-RECOVERY](PHASE-06-PRESENCE-RECOVERY.md) | P1 | SCALE-RT-001, PERF-AUTH-002 | RT-03/04/09/10/21; presence snapshot:191; room sync:78. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [SCALE-RT-004](PHASE-06-PRESENCE-RECOVERY.md#scale-rt-004) | Typing cache and distinct-channel churn | [PHASE-06-PRESENCE-RECOVERY](PHASE-06-PRESENCE-RECOVERY.md) | P1 | SCALE-RT-001, SCALE-RT-003 | message handler:29–40,111–150. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [SCALE-RT-005](PHASE-06-PRESENCE-RECOVERY.md#scale-rt-005) | Recovery window, token expiry, and revocation | [PHASE-06-PRESENCE-RECOVERY](PHASE-06-PRESENCE-RECOVERY.md) | P0 | SCALE-RT-002, SCALE-RT-003, PERF-AUTH-002 | recovery config:83–86; recovered identity:116–153; client recovery:239–327. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [SCALE-RT-006](PHASE-08-MEMBERSHIP-EVICTION.md#scale-rt-006) | Membership and archive changes during traffic | [PHASE-08-MEMBERSHIP-EVICTION](PHASE-08-MEMBERSHIP-EVICTION.md) | P0 | SCALE-RT-002, SCALE-RT-003, SCALE-RT-005, PERF-SOC-004 | SPC-03/10/11/12, CH-10; `leaveUserFromSpaceRoom`:49; channel access. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [SCALE-RT-007](PHASE-15-NETWORK-SLOW-CONSUMERS.md#scale-rt-007) | Slow consumers and outbound pressure | [PHASE-15-NETWORK-SLOW-CONSUMERS](PHASE-15-NETWORK-SLOW-CONSUMERS.md) | P0 | SCALE-RT-002 | room/user emits and recovery configuration; no application backpressure policy found. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-SOC-001](PHASE-07A-REQUESTS-CONVERSATIONS.md#perf-soc-001) | Message-request creation and acceptance | [PHASE-07A-REQUESTS-CONVERSATIONS](PHASE-07A-REQUESTS-CONVERSATIONS.md) | P0 | PERF-API-001, PERF-NOT-001 | REQ-01–05; request controller:52–318. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-SOC-002](PHASE-07A-REQUESTS-CONVERSATIONS.md#perf-soc-002) | DM/group/self-note creation races | [PHASE-07A-REQUESTS-CONVERSATIONS](PHASE-07A-REQUESTS-CONVERSATIONS.md) | P0 | PERF-SOC-001 | CH-04–06; unique index/model hook:155–169. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-SOC-003](PHASE-07B-HISTORY-EXPANSION.md#perf-soc-003) | Conversation expansion and history-copy failure | [PHASE-07B-HISTORY-EXPANSION](PHASE-07B-HISTORY-EXPANSION.md) | P0 | PERF-SOC-002, PERF-DATA-001 | CH-07; `expandDM`:423–618. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-SOC-004](PHASE-07C-SPACES-PINS.md#perf-soc-004) | Spaces, approvals, invites, and channel mutation | [PHASE-07C-SPACES-PINS](PHASE-07C-SPACES-PINS.md) | P0 | PERF-API-001, SCALE-RT-003 | SPC-01/03/06/07/09/10; CH-01/09. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-SOC-005](PHASE-07C-SPACES-PINS.md#perf-soc-005) | Pin cap and concurrent pin/unpin | [PHASE-07C-SPACES-PINS](PHASE-07C-SPACES-PINS.md) | P1 | PERF-API-001 | CH-12/13; pin handler:661–705. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-HAND-001](PHASE-09-HANDOFFS.md#perf-hand-001) | Shift-change handoff workload | [PHASE-09-HANDOFFS](PHASE-09-HANDOFFS.md) | P0 | PERF-API-001, PERF-NOT-001, SCALE-RT-002 | HND-01–03/05/06/10; notify handoff functions. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-HAND-002](PHASE-09-HANDOFFS.md#perf-hand-002) | Competing handoff transitions | [PHASE-09-HANDOFFS](PHASE-09-HANDOFFS.md) | P0 | PERF-HAND-001 | HND-04–09; conditional submit/ack versus read-modify-save reassign/edit. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-DATA-001](PHASE-10-DATABASE-GROWTH.md#perf-data-001) | Query plans and collection growth | [PHASE-10-DATABASE-GROWTH](PHASE-10-DATABASE-GROWTH.md) | P0 | PERF-API-001 | model/index table; MSG-01/03, HND-10, NOT-01, CH-03, admin list. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-DATA-002](PHASE-10-DATABASE-GROWTH.md#perf-data-002) | Pool competition and hidden writes | [PHASE-10-DATABASE-GROWTH](PHASE-10-DATABASE-GROWTH.md) | P0 | PERF-MSG-001, PERF-NOT-001, PERF-DATA-001 | DB config:57–61; auth activity:77; notification fan-out. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-DATA-003](PHASE-10-DATABASE-GROWTH.md#perf-data-003) | Retention, TTL, and storage growth | [PHASE-10-DATABASE-GROWTH](PHASE-10-DATABASE-GROWTH.md) | P1 | PERF-DATA-001, PERF-NOT-002, PERF-MED-002 | OTP TTL:70; notification TTL:142; soft-delete message hook. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [RES-DATA-001](PHASE-14-RESILIENCE.md#res-data-001) | Database interruption and recovery | [PHASE-14-RESILIENCE](PHASE-14-RESILIENCE.md) | P0 | PERF-DATA-002, PERF-MSG-001 | DB timeouts/reconnect listeners; unawaited writes; health route. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-SEARCH-001](PHASE-11-DISCOVERY-OPERATIONS.md#perf-search-001) | Search and discovery selectivity | [PHASE-11-DISCOVERY-OPERATIONS](PHASE-11-DISCOVERY-OPERATIONS.md) | P1 | PERF-DATA-001 | SRC-01, USER-05/06; `resolveKnownUserIds`:49–87. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-SEARCH-002](PHASE-11-DISCOVERY-OPERATIONS.md#perf-search-002) | Dashboard, Needl, and unpaginated lists | [PHASE-11-DISCOVERY-OPERATIONS](PHASE-11-DISCOVERY-OPERATIONS.md) | P1 | PERF-DATA-001, SCALE-RT-003 | USER-08, SPC-02/05/08, CH-02/03/11, HND-02. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-NOT-001](PHASE-04-NOTIFICATIONS.md#perf-not-001) | Notification and push amplification | [PHASE-04-NOTIFICATIONS](PHASE-04-NOTIFICATIONS.md) | P0 | SCALE-RT-002 | notification service:44–211,282–370. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-NOT-002](PHASE-04-NOTIFICATIONS.md#perf-not-002) | Inbox reads and concurrent clearing | [PHASE-04-NOTIFICATIONS](PHASE-04-NOTIFICATIONS.md) | P1 | PERF-NOT-001, PERF-DATA-001 | NOT-01–07; channel clear uses raw collection update:121. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-MED-001](PHASE-12-MEDIA.md#perf-med-001) | Upload buffering and downstream stalls | [PHASE-12-MEDIA](PHASE-12-MEDIA.md) | P0 | PERF-API-001, PERF-MSG-001 | media route memoryStorage:42, limit:70; backend constant:130–131; upload controller:34. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-MED-002](PHASE-12-MEDIA.md#perf-med-002) | Fetch, deletion, avatar replacement, and references | [PHASE-12-MEDIA](PHASE-12-MEDIA.md) | P1 | PERF-MED-001, PERF-DATA-001 | static uploads; `deleteStoredMedia`:190; attachment cleanup:205; `updateMe`:100–114. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-OPS-001](PHASE-11-DISCOVERY-OPERATIONS.md#perf-ops-001) | Admin analytics and support interference | [PHASE-11-DISCOVERY-OPERATIONS](PHASE-11-DISCOVERY-OPERATIONS.md) | P1 | PERF-DATA-001, PERF-MSG-001 | ADM-01–10, SUP-01–03, SYS-06. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [PERF-MIX-001](PHASE-13-MIXED-LOAD.md#perf-mix-001) | Multi-user clinical communication journeys | [PHASE-13-MIXED-LOAD](PHASE-13-MIXED-LOAD.md) | P0 | PERF-MSG-001, PERF-MSG-002, PERF-SOC-001, PERF-SOC-002, PERF-SOC-004, PERF-HAND-001, PERF-NOT-001, PERF-NOT-002, PERF-MED-001, PERF-SEARCH-001, PERF-SEARCH-002, SCALE-RT-005 | preceding operation inventory and mobile repository calls. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [LOAD-SYS-001](PHASE-13-MIXED-LOAD.md#load-sys-001) | Sustained normal-load stability | [PHASE-13-MIXED-LOAD](PHASE-13-MIXED-LOAD.md) | P0 | PERF-MIX-001 | Original system row and pinned source context in owner phase; shared architecture B/C. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [STRESS-SYS-001](PHASE-16-STRESS-SPIKE-SOAK.md#stress-sys-001) | Saturation and failure thresholds | [PHASE-16-STRESS-SPIKE-SOAK](PHASE-16-STRESS-SPIKE-SOAK.md) | P1 | LOAD-SYS-001 | Original system row and pinned source context in owner phase; shared architecture B/C. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [SPIKE-SYS-001](PHASE-16-STRESS-SPIKE-SOAK.md#spike-sys-001) | Shift-change demand spikes | [PHASE-16-STRESS-SPIKE-SOAK](PHASE-16-STRESS-SPIKE-SOAK.md) | P0 | PERF-AUTH-003, SCALE-RT-003, LOAD-SYS-001 | Original system row and pinned source context in owner phase; shared architecture B/C. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [SOAK-SYS-001](PHASE-16-STRESS-SPIKE-SOAK.md#soak-sys-001) | Long-running resource stability | [PHASE-16-STRESS-SPIKE-SOAK](PHASE-16-STRESS-SPIKE-SOAK.md) | P1 | LOAD-SYS-001, SCALE-RT-004, PERF-DATA-003 | Original system row and pinned source context in owner phase; shared architecture B/C. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [SCALE-SYS-001](PHASE-19-ADVANCED-SCALING.md#scale-sys-001) | Vertical scalability | [PHASE-19-ADVANCED-SCALING](PHASE-19-ADVANCED-SCALING.md) | P1 | STRESS-SYS-001 | Original system row and pinned source context in owner phase; shared architecture B/C. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [SCALE-SYS-002](PHASE-19-ADVANCED-SCALING.md#scale-sys-002) | Horizontal correctness and scalability | [PHASE-19-ADVANCED-SCALING](PHASE-19-ADVANCED-SCALING.md) | P0 | SCALE-RT-005, SCALE-RT-006, PERF-MSG-001 | Original system row and pinned source context in owner phase; shared architecture B/C. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [RES-SYS-001](PHASE-14-RESILIENCE.md#res-sys-001) | Backend restart and shutdown | [PHASE-14-RESILIENCE](PHASE-14-RESILIENCE.md) | P0 | PERF-MSG-003, PERF-SOC-003 | Original system row and pinned source context in owner phase; shared architecture B/C. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [RES-SYS-002](PHASE-14-RESILIENCE.md#res-sys-002) | Provider degradation | [PHASE-14-RESILIENCE](PHASE-14-RESILIENCE.md) | P0 | PERF-AUTH-001, PERF-NOT-001, PERF-MED-001 | Original system row and pinned source context in owner phase; shared architecture B/C. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [NET-SYS-001](PHASE-15-NETWORK-SLOW-CONSUMERS.md#net-sys-001) | Network impairment | [PHASE-15-NETWORK-SLOW-CONSUMERS](PHASE-15-NETWORK-SLOW-CONSUMERS.md) | P1 | SCALE-RT-005, PERF-MSG-003 | Original system row and pinned source context in owner phase; shared architecture B/C. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [MOBILE-SYS-001](PHASE-20-MOBILE-PERFORMANCE.md#mobile-sys-001) | Client performance and lifecycle | [PHASE-20-MOBILE-PERFORMANCE](PHASE-20-MOBILE-PERFORMANCE.md) | P1 | NET-SYS-001, PERF-SEARCH-002, PERF-MED-002 | Original system row and pinned source context in owner phase; shared architecture B/C. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |
| [REG-SYS-001](PHASE-17-REPORTING-REGRESSION.md#reg-sys-001) | Performance regression comparison | [PHASE-17-REPORTING-REGRESSION](PHASE-17-REPORTING-REGRESSION.md) | P0 | PERF-API-001, PERF-MSG-001, SCALE-RT-002, LOAD-SYS-001 | Original system row and pinned source context in owner phase; shared architecture B/C. | PLANNED / NOT IMPLEMENTED / NOT EXECUTED |

## Original feature-to-risk-to-case traceability

## G. Traceability and completeness review

### G1. Feature → source → risk → case → metric → environment

| Feature | Source anchor | Risk | Cases | Primary metric/oracle | Environment |
|---|---|---|---|---|---|
| OTP/widget auth | auth:24/53/99; OTP model:81 | R06/R09/R18/R19 | AUTH-001/003 | unique user/OTP claims; attempts/token latency | E1/E2 |
| Refresh/multi-device | auth:141; user model:284 | R08/R09/R14 | AUTH-002, RT-005 | refresh amplification/token/presence state | E1/E2/E4 |
| Message persistence | messages:208–238 | R01/R04/R05 | MSG-001/003 | accepted/persisted unique IDs | E2 |
| Delivery/fan-out | socket:198; audience:120 | R02/R03 | RT-002/007 | unique recipient coverage and tail | E2/E3 |
| Threads | messages:255/295 | R01/R05/R12 | MSG-002, DATA-001 | counter convergence/page coverage | E1/E2 |
| Edits/reactions/receipts | messages:345–490 | R09 | MSG-004 | state consistency and loss | E1/E2 |
| Invitations/membership | spaces:149/218/374 | R08/R09 | SOC-004, RT-006 | unique members/eviction latency | E1/E2/E3 |
| DM/group creation | channels:241/325 | R09 | SOC-002 | unique membership-key channel | E1/E2 |
| Expansion | channels:423 | R07 | SOC-003 | graph completeness/peak memory | E2 |
| Message requests | requests:52/197 | R09/R18 | SOC-001 | state/DM repair/notification count | E1/E2 |
| Handoffs | handoffs:192/215/277/382 | R01/R09/R11 | HAND-001/002 | valid transition/history/visibility | E1/E2 |
| Search/discovery | search:46; knownUsers:49 | R12/R13 | SEARCH-001 | scanned/returned and result scope | E2 |
| Needl/lists | users:347; channels:219 | R11/R13 | SEARCH-002 | queries/list, bytes, latency | E2/E4 |
| Inbox/push | notifications:14; service:44 | R02/R18 | NOT-001/002 | eligibility/completion/count | E1/E2/E5 |
| Presence/sync | presence:38/191 | R03/R14 | RT-003 | queries/events per sync | E2/E3 |
| Typing | message handler:29/111 | R15 | RT-004 | cache cardinality/event cost | E2/E4 |
| Media lifecycle | media:34/190/205 | R10/R18 | MED-001/002 | buffer/fetch/delete/orphan metrics | E2/E4/E5 |
| DB/TTL | config database:57; model indexes | R06/R12 | DATA-001–003, RES-DATA-001 | query/pool/TTL/recovery | E2/E3 |
| Admin/support | admin:34/362; support:45 | R11 | OPS-001 | collateral latency/cohort memory | E2 |
| Startup/shutdown | server:82/123; health:142 | R01/R16/R17 | RES-SYS-001 | usable recovery/unfinished work | E2 |
| Mobile | socket client:232; cache:7; chat cubit:633 | R04/R14/R20 | NET-SYS-001, MOBILE-SYS-001 | UI state, jank, memory, amplification | E4 |
| Aggregate operation | all above | combined | LOAD/STRESS/SPIKE/SOAK/SCALE/REG | stable useful throughput | E2/E3 |

### G2. Second-pass findings incorporated

The second pass explicitly checked routes, model indexes, side-effect scheduling, deployment configuration, provider calls, client recovery, and existing product decisions.

It added or sharpened coverage for:

- Self notes and both group-DM route aliases.
- Full-history expansion and partial copy recovery.
- Needl’s per-candidate access queries.
- Pending approval and invite regeneration.
- Handoff notes, reassignment, history filters, and draft visibility conflict.
- Admin retention and infrastructure-estimate endpoints.
- Support tickets.
- Attachment deletion scans and old-avatar cleanup.
- FCM token cleanup and per-user token cap.
- Global limiter bypass in `NODE_ENV=test`.
- TTL activity.
- Recovered identity and skipped middleware.
- Separate channel-room/user-room duplicate delivery.
- Mobile duplicate readiness/synchronization paths.
- Read receipts being limited to direct channels.
- Dormant constants/helpers that must not be mistaken for active flows.

For example, a handoff system-message helper is defined, but the inspected submit/acknowledge handlers do not invoke it. The harness must not assume those transitions create a chat message merely because the helper exists.

### G3. Explicit exclusions and limitations

- **Voice/video calls, WebRTC, SFU/TURN capacity:** no implemented calling pipeline identified. Uploaded video files are covered.
- **Queue-worker scaling:** no queue/worker architecture found. In-process side effects are covered.
- **Redis/cache-cluster testing:** no such deployment found.
- **Mongo sharding capacity:** not supported by observed configuration; defer until an actual topology/design exists.
- **Unlimited group-DM fan-out:** contradicts the nine-member handler limit.
- **Developer seeding endpoints as user workload:** excluded; they do not represent normal production activity.
- **Real SMS/FCM/Cloudinary saturation:** excluded from bulk testing. Use doubles; real-provider tests require separate authorization and provider limits.
- **Complete mobile performance certification:** cannot be obtained with protocol clients or repository inspection.

This is a complete enumeration of the inspected backend feature-router surface, **not a claim that every runtime behavior or deployment condition has been proven covered**.

---

## Reconciliation invariants

- Each of 45 original IDs has exactly one owner heading in a phase document.
- Cross-references and composed workloads do not count as duplicate implementation ownership.
- Phases 00, 01 and 18 own shared infrastructure/contracts, not invented test cases.
- Every original P0 risk is assigned below; unsupported horizontal architecture and provider/device cases remain explicit.
- Metrics, workload hypotheses, F1–F3 contracts, safety requirements and source inventory remain in the shared document and original report.
- Original report is preserved in full, not replaced by this matrix.

## Architectural risk ownership

| Original risk | Owner/consumer phases | Coverage state |
|---|---|---|
| R01 | 05, 09, 14 | Planned; no runtime result |
| R02 | 03, 04, 10, 15 | Planned; no runtime result |
| R03 | 06, 08, 19 | Planned; no runtime result |
| R04 | 05, 15, 20 | Planned; no runtime result |
| R05 | 05, 10 | Planned; no runtime result |
| R06 | 02, 04, 10, 14 | Planned; no runtime result |
| R07 | 07B, 14 | Planned; no runtime result |
| R08 | 06, 08, 19 | Planned; no runtime result |
| R09 | 05, 07A, 07C, 09 | Planned; no runtime result |
| R10 | 12, 15 | Planned; no runtime result |
| R11 | 10, 11 | Planned; no runtime result |
| R12 | 10, 11 | Planned; no runtime result |
| R13 | 11 | Planned; no runtime result |
| R14 | 06, 16, 20 | Planned; no runtime result |
| R15 | 06, 16 | Planned; no runtime result |
| R16 | 14 | Planned; no runtime result |
| R17 | 14 | Planned; no runtime result |
| R18 | 04, 12, 14 | Planned; no runtime result |
| R19 | 02, 13, 16 | Planned; no runtime result |
| R20 | 20 | Planned; no runtime result |


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
