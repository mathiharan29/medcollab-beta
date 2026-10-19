# Functional regression decision ledger

No product approval is inferred from existing behavior. Safe subassertions may
execute while disputed expectations retain NEEDS_DECISION. Current execution
determines outcomes; archived observations are not current evidence. Changing a
decision requires product approval and updates the harness fingerprint.

| Question | Decision needed | Status | Safe verified scope pending decision |
|---|---|---|---|
| Q1 | Whether edit/delete changes channel preview, quote snapshots and thread aggregates | NEEDS_DECISION | Assert primary message persistence, edited/deleted state and events; record derived views. |
| Q2 | Expanded conversation copy graph, 500-item cap, timezone and source references | NEEDS_DECISION | Assert source records unchanged, destination membership and independently observed copy IDs. |
| Q3 | Draft handoff visibility across received list, detail, history and search | NEEDS_DECISION | Assert draft owner and patient persistence; capture each audience response. |
| Q4 | Stable cursor contract for space handoffs ordered by shiftDate and ID | NEEDS_DECISION | Assert source handoffs and ordered first page; capture repeated/missing IDs. |
| Q5 | Supported local/provider media formats and complete upload-to-message pipeline | NEEDS_DECISION | Assert exact upload bytes and metadata; report send incompatibility as observed, not supported success. |
| Q6 | Referenced media deletion, retention and dangling-reference UX | NEEDS_DECISION | Assert deletion endpoint effect on stored bytes and separately capture references. |
| Q7 | Idempotency/atomicity for concurrent creation, response loss and partial accept | NEEDS_DECISION | Assert persisted identities/resources after each operation; capture duplicates or partial state. |
| Q8 | Availability note/until convergence in socket payload | NEEDS_DECISION | Assert persisted availability and record peer event fields. |
| Q9 | Quiet-hour timezone and disabled-emergency push policy | NEEDS_DECISION | Assert fake push decision at controlled server time; record boundary and preference ordering. |
| Q10 | Immediate room eviction on membership removal | NEEDS_DECISION | Assert DB membership and post-sync/reconnect rooms; record pre-sync events. |
| Q11 | Draft/bookmark/recent/cache scope across logout and account switch | NEEDS_DECISION | Assert stored values for the active identity and capture cross-account visibility. |
| Q12 | Handoff acknowledgement wording and local-day overdue labels | NEEDS_DECISION | Assert persisted handoff status and controlled-clock client labels separately. |
| Q13 | Forwarded message-link target and media forwarding contract | NEEDS_DECISION | Assert copied link string and submitted forwarding payload; capture route handling. |
| Q14 | Pending approval/admin setting UX without management routes | NEEDS_DECISION | Assert pending request persists without membership and capture client state. |
