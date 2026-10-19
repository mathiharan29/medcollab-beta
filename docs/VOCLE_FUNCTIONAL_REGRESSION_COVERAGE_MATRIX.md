# Vocle functional regression coverage matrix

Coverage inventory; execution must be established by each current report. Hosted coverage is 187 total / 179 hosted / 8 LOCAL_ONLY; Android remains unexecuted SKIP in PR reports. Count unit = stable parent testcase ID, including boundary subchecks once. **23 feature modules, 6 cross-feature journey cases, 187 total cases = 48 retained sanity + 139 new.** Existing Flutter tests support several new scenarios but do not satisfy their complete integration contracts.

## Reconciled totals

| Distribution | Count |
|---|---:|
| P0 | 96 |
| P1 | 81 |
| P2 | 10 |
| B: backend HTTP/DB/Socket/provider-contract | 147 |
| F: Flutter model/widget/state integration | 32 |
| D: device/platform and UI journeys | 8 |
| Retained sanity, all B/P0 | 48 |
| New B / F / D | 99 / 32 / 8 |

P0 assignment to retained sanity reflects its existing gating role; it does not imply a color or support feature is intrinsically as critical as a handoff. Each case has exactly one primary tier. Secondary observations (e.g. socket and persistence in one B case) do not add counts.

## Module ownership and gaps

Existing cases that span features are assigned once to their primary module for arithmetic. Authentication owns the combined device/widget case, notifications own mention behavior, conversations own the existing receipt case. The table's proposed tier totals include retained cases.

| Module / new ID prefix | Existing | New | Total | B/F/D | Main coverage added; remaining constraint |
|---|---:|---:|---:|---|---|
| Authentication AUTH | 6 | 7 | 13 | 13/0/0 | Resend, expiry, attempts, provider failure and refresh recovery |
| Profile PRO | 1 | 5 | 6 | 5/1/0 | Field boundaries, preference merge, populated views and form errors |
| Discovery DISC | 0 | 4 | 4 | 4/0/0 | Relationship combinations, normalization, filtered search cap |
| Spaces SPC | 5 | 6 | 11 | 11/0/0 | Pending approval, roles/settings, member ordering, leave/sync |
| Channels CH | 3 | 5 | 8 | 8/0/0 | List agreement, posting setting, default protection, archive/search |
| Requests REQ | 3 | 6 | 9 | 8/1/0 | Reverse collision, terminal states, partial acceptance, UI CTAs |
| Conversations DM | 5 | 9 | 14 | 14/0/0 | Membership cap/dedup, today/500-copy boundary, copied graph, races |
| Root messages MSG | 5 | 8 | 13 | 13/0/0 | Input/page boundaries, quote metadata, stale preview, response loss |
| Threads THR | 1 | 5 | 6 | 5/1/0 | Paging, Needl cap, deleted aggregate consistency, UI dedup |
| Reactions/pins/receipts SOC | 1 | 6 | 7 | 6/1/0 | Multi-user emoji replacement, five-pin cap, receipt batches/UI |
| Handoffs HOF | 5 | 13 | 18 | 15/3/0 | Patient fields, lifecycle races, filters/paging, repeated reassignment, form/clock |
| Media MED | 3 | 8 | 11 | 10/0/1 | Size/type/provider contract, end-to-end incompatibilities, OS picker/open |
| Inbox NOT | 3 | 6 | 9 | 8/1/0 | Viewer suppression, filter/count pages, notification failure and badge reconciliation |
| Push/tokens PUSH | 0 | 6 | 6 | 4/0/2 | Five-token cap, preference/quiet-hours, stale tokens, device grouping/reply |
| Realtime RT | 3 | 7 | 10 | 7/3/0 | Multi-device presence, room sync, recovered handler/replay, refresh |
| Global search SRCH | 2 | 4 | 6 | 5/1/0 | Type limits, literal matching, patient title, stale-response ordering |
| Support/dev SUP | 1 | 4 | 5 | 4/1/0 | Feature/feedback, truncation, dev seeds, form/help/legal paths |
| Startup/navigation NAV | 0 | 5 | 5 | 0/3/2 | Auth routes, refresh loops, back/tab history, OS restart/resume |
| Composer/offline OFF | 0 | 6 | 6 | 0/6/0 | Optimistic reconciliation, failure, local drafts/cache, account switch |
| Saved/recent SAVE | 0 | 3 | 3 | 0/3/0 | Local persistence, caps, corruption/missing target |
| Home HOME | 0 | 3 | 3 | 0/3/0 | Widget config, assigned responsibility, error recovery |
| Links/forward LINK | 0 | 4 | 4 | 0/3/1 | Forward payload, missing deep-link target, push routing, QR |
| Runtime RUN | 1 | 3 | 4 | 3/1/0 | Process restart, DB outage, transport/parse recovery |
| Cross-feature JRN (not a module) | 0 | 6 | 6 | 4/0/2 | Connected journeys below |
| **Total** | **48** | **139** | **187** | **147/32/8** | Source-grounded design; not a passing coverage claim |

## Existing coverage quality and evidence

| Existing coverage | What it proves | Gap / new cases |
|---|---|---|
| authentication-and-profiles-01..07 | OTP identity/tokens, profile GET, refresh usability, device DB removal | No expiry/resend/exhaustion boundary or widget failure matrix; AUTH, PRO, PUSH |
| spaces-and-invitations-01..05 | Core invite/member lifecycle | Pending joins/settings/room convergence absent; SPC |
| channels-01 | Create/duplicate and mutation-response rename | Rename lacks independent read; FR-CH-01/04 add reload |
| channels-02 | Private creator can read detail | Does not prove private list rendering agrees across list/detail surfaces; FR-CH-02 |
| messaging-and-needl-03 | Quote mutation-response ID/text | No independent quote persistence or media fallback; FR-MSG-03 |
| messaging-and-needl-04 | Thread/read/Needl on small sample | Immediately reads after setImmediate side effects; race risk, not demonstrated flake rate; FR-THR-01 uses bounded polling |
| messaging-and-needl-05/06 | Soft-delete DB flag, edit/event and reaction/pin response arrays | Does not prove every independent reload/derived preview; MSG/SOC |
| message-requests-01/02 | Requires notification and functioning accepted DM | Historical failures remain failures; do not downgrade to HTTP success or use fork repair in target |
| direct-and-group-conversations-01/02/03/05 | Pair message/receipt/expansion once request succeeds | Historical blocked chain; independent component fixtures needed while journey preserves dependency failure |
| handoffs-01..05 | Meaningful draft/submit/ack/reassign lifecycle and some DB/event checks | No dates/cursor, two concurrent transitions, repeated reassignment, UI state or broad patient boundary coverage |
| media-01..03 | Exact local PNG/PDF bytes and inert message metadata | No local-upload-to-message proof, real cloud rendering, video send or platform opener |
| notifications-01..03 | Persistence/type/count/read lifecycle | Sparse dataset and no viewing/quiet-hours/token/overlapping event checks |
| realtime-and-availability-01 | First message plus fresh reconnect/rejoin | No second message after reconnect; no recovered-session or multi-device behavior |
| realtime-and-availability-03 | Status broadcast/DB check and offline event | note/until omitted from assertions; lastSeenAt persistence and recovered presence absent |
| search/support/startup | Positive aggregate results, one bug ticket and health | Type filters/caps, other ticket types, outages and UI absent |

Saved run 37361869623 is **42 passed / 2 failed / 4 blocked**, not 48 passing. All runtime hypotheses in this design are unexecuted. Existing test deadlines (five-second eventual polling in some modules and 60-second process caps), shared cached identities, serial state dependence, asynchronous immediate reads and room/user duplicate fan-out are reliability risks. No measured flake rate is asserted. Increase diagnosis quality and event correlation before increasing timeouts.

## Flutter and device baseline

`medcollab-app/test/` has **8 test files with 33 statically declared `test`/`testWidgets` calls**: active-chat/offline enum (2), chat model/request parsing (7), dashboard preferences (5), handoff colors (3), app colors (4), phone/QR helpers (6), launch splash (1), drafts (5). This is a declaration count, not a test-run result. These are supporting helper/model/widget tests, not 33 end-to-end scenarios. No checked-in device integration suite was identified in the inspected tree. Existing backend `tests/knownUsers.test.js` and `rateLimiter.test.js` are supporting focused tests, not the 48-scenario functional registry; security test counts are excluded.

Local drafts and dashboard preferences have useful partial coverage. Critical Flutter gaps are auth/navigation, optimistic send reconciliation, listener cleanup, stale response races, handoff forms, badge consistency, saved-item navigation and account switching. Device gaps include process death, secure storage, camera/media permission, external opening, notification grouping/taps/replies. Injected notifications prove local handling, not FCM/APNs delivery.

## Journey coverage

| Journey | Catalog | Why component success is insufficient |
|---|---|---|
| First login → onboard → join → chat → handoff → acknowledge → relogin | FR-JRN-01 | Exposes stale identity, member, notification and responsibility state across modules |
| Lookup → consent → DM → receipt → reopen | FR-JRN-02 | Acceptance may persist before failed DM creation; lists/CTA/notification must converge |
| Cannot cover → note → reassign → acknowledge | FR-JRN-03 | Must preserve patient payload and history while clearing prior acknowledgement |
| Leave → reload/sync → rejoin | FR-JRN-04 | Membership changes interact with search, Needl and realtime rooms |
| Offline draft → resume → send → reply → relogin | FR-JRN-05 | Device-local persistence and reconciliation cannot be proven by HTTP |
| Cold notification → auth → handoff → acknowledgement | FR-JRN-06 | Tests queued routing, correct target and durable acknowledgement together |

## Clarification and exclusions

Q1–Q14 in the master plan map to explicit catalog rows. Highest priority decisions: preview/aggregate updates, conversation history graph, handoff audience/pagination, retry/partial-write semantics, media pipeline, socket convergence and account-local data. Preserve verified assertions while disputed subassertions remain NEEDS_DECISION. Do not claim full success with blocked or undecided cases.

Unsupported roster/approval/ownership-transfer/calls/scheduled-send/synced-bookmarks features are exclusions, not covered scenarios. No estimate of 100% assurance is made. This matrix measures planned meaningful behavior coverage, not deployed behavior, branch coverage, or all possible concurrency schedules.
