# Functional regression decision ledger

Founder decisions are recorded in `docs/PRODUCT_DECISIONS_2026-10-25.md`. The later release contracts for message deletion and Needl activity are recorded in `docs/FIX_CHECKLIST_2026-11-08.md`.

| Question | Decision needed | Status | Safe verified scope pending decision |
|---|---|---|---|
| Q1 | Whether edit/delete changes channel preview, quote snapshots and thread aggregates | RESOLVED | Quotes retain their snapshot on edit. Delete for everyone permanently removes the message, updates quoted text and the channel preview, and recalculates the aggregate when a reply is deleted. |
| Q2 | Expanded conversation copy graph, 500-item cap, timezone and source references | RESOLVED | Phone local `todayStart`; no 500-cap on expand all; remap thread/quote IDs; the newly appended member-added activity is the new Needl preview. |
| Q3 | Draft handoff visibility across received list, detail, history and search | RESOLVED | Draft handoffs are author-only. |
| Q4 | Stable cursor contract for space handoffs ordered by shiftDate and ID | RESOLVED | Sort by shiftDate with `_id` cursor; no duplicates. |
| Q5 | Supported local/provider media formats and complete upload-to-message pipeline | RESOLVED | Trust filename extension for octet-stream; video supported; full local upload→message; never surface raw Cloudinary URLs. |
| Q6 | Referenced media deletion, retention and dangling-reference UX | RESOLVED | Replace avatar auto-deletes old file; deleted media allowed; show Message/Image deleted. |
| Q7 | Idempotency/atomicity for concurrent creation, response loss and partial accept | RESOLVED | Accept recovers DM; one group DM per membership; lost send dedupes/waits for ack; 401 recoverable refresh. |
| Q8 | Availability note/until convergence in socket payload | RESOLVED | Socket presence note/until must match REST. |
| Q9 | Quiet-hour timezone and disabled-emergency push policy | RESOLVED | Quiet hours use server timezone. |
| Q10 | Immediate room eviction on membership removal | RESOLVED | Immediate room eviction; banner You left / Removed by; history readable, composer disabled. |
| Q11 | Draft/bookmark/recent/cache scope across logout and account switch | RESOLVED | Per-account isolation; clear local leftovers on logout/switch. |
| Q12 | Handoff acknowledgement wording and local-day overdue labels | RESOLVED | Phone local midnight labels; wording OK; server status unchanged. |
| Q13 | Forwarded message-link target and media forwarding contract | RESOLVED | Deep link opens chat/message when logged in; login when logged out. |
| Q14 | Pending approval/admin setting UX without management routes | RESOLVED | Join shows Pending; admin list + approve; approved user enters channels. |
