# Vocle functional regression testcase catalog

Design revision: 8 October 2026. Questions Q1–Q14 are defined in the [decision ledger](../tests/functional-regression/contracts/decisions.md). IDs are immutable. Cases are specifications, not executed results.

## How to implement each row

Each row specifies title/function, actions, observable expected result, tier/priority, coverage and clarification. The section's fixture/preconditions, dependencies and source references apply to **every row in that section**, unless overridden in the row. This inheritance avoids repeating setup and makes each specification complete. Ordered semicolon-separated actions are executed left to right. Each input boundary table is one case with named subchecks; reset the affected fixture between invalid variants.

**Universal assertions for NEW cases (retained sanity assertions remain frozen):** for every successful mutation, independently GET the affected resource/list and inspect DB where no read endpoint exists; compare IDs, field values and cardinalities, not only status. For rejected actions, snapshot affected collections before/after and assert no unintended mutation. Exceptions involving documented partial operations have a Q marker and do not assume atomicity. For socket expectations subscribe before mutation, await authentication/join acknowledgement, correlate resource and actor IDs, then poll persistence with a bounded deadline. No arbitrary sleeps, no retry-until-green mutations. Absence checks require a positive control and a bounded observation window after side-effect completion.

**Tier/feasibility:** B = real backend HTTP/Mongo/Socket automation, feasible with local fixtures; F = Flutter unit/widget/integration, feasible with fake repository/platform channels and controlled clocks; D = device automation requiring emulator/OS input harness. `Qn` marks an unresolved oracle: record current result separately and resolve before enforcing the disputed expectation. Unmarked cases require no product clarification. Priority P0 = core journey/data continuity, P1 = important regression, P2 = secondary behavior. NEW distinguishes added catalog cases from retained sanity; `partial:` names supporting existing coverage, not a duplicate completed test.

**Fixture profiles:**

- **U:** fresh database `vocle_regression_<run>_<module>` on isolated loopback, users A/B/C/D/E with reserved fictional phones +12025550101–105, OTP_BYPASS=false and captured fake SMS/widget responses. A owns S, B/C ordinary members; D unrelated and opts into requests only when stated; E unrelated/default opt-out. Users onboarded except authentication cases. Boundary group-size tests add synthetic users F–K. Use a separate S2 for lifecycle/destructive steps. No real patient/phone/provider data.
- **C:** U plus S default general/emergency/academics, custom public X, private Y with A only; pair DM A/B after accepted request; independent group A/B/C; two distinct roots r1/r2 and reply t1 with unique markers. Seed accepted prerequisite records only in independent component cases; journey cases must create through APIs.
- **H:** U+C plus draft A→B in S/general, fixed shift date 2030-01-02, night shift, patient `{bedNumber:'T1',ward:'Synthetic',clinicalAlias:'Case Alpha',status:'stable',notes:'review marker',pendingTasks:['check marker'],isFlagged:false}`, empty attachments. Create through POST /api/handoffs; retain returned patient/handoff IDs.
- **N:** C plus A and B sockets, B out of channel unless stated, notifications cleared only during fixture setup; stub push transport captures requests without network. Seed extra dated notifications for paging only.
- **M:** U plus valid tiny PNG, PDF and MP4 fixture bytes, unique filenames and SHA-256; local storage volume. Provider-path cases run a separate process with a test-owned SDK/transport fake, dummy config and no egress. Do not fetch inert Cloudinary URLs.
- **F0:** fresh Flutter dependencies, authenticated A, fake API/repositories/socket streams, isolated preferences/secure-storage doubles, deterministic IDs/times. Recreate service/widget to verify persistence. Real backend is required only for D journeys.
- **D0:** test build on emulator/device, local synthetic backend and seeded identities, injectable OS notification/picker events, no production configuration; record OS/build/device and backend SHA. Restart app without deleting storage for persistence checks.

Backend route files beside controllers are the authoritative method/path contracts. Exact boundary lengths below come from validators/models. Assertions of an intended invariant that conflicts with source are explicitly Q-marked; do not encode the defect as desired behavior.

## Retained sanity cases: 48 unchanged IDs

All rows below: coverage **EXISTING**, tier **B**, priority **P0**, feasible using existing harness; dependencies are their group fixture and earlier resources explicitly used in actions. Preserve existing source assertions verbatim, including failures. These rows summarize the existing executable definitions; adding stronger assertions belongs under new IDs. Each group links its exact implementation, which supplies literal request payloads and response assertions.

### Authentication and profiles — U; source tests/sanity/src/authentication-scenarios.js and B/features/auth, B/features/users

| ID | Title, ordered actions and expected business result |
|---|---|
| authentication-and-profiles-01 | Request OTP; inspect hashed record; verify captured code; assert new verified user, access/refresh tokens and persisted identity. |
| authentication-and-profiles-02 | Request/verify again for same phone; assert same user ID and isNewUser=false. |
| authentication-and-profiles-03 | Submit wrong code then correct captured code; first rejects, second yields token. |
| authentication-and-profiles-04 | Reuse consumed code; reject and do not create another user. |
| authentication-and-profiles-05 | Update onboarding name/institution; GET me; assert onboarded and exact profile values. |
| authentication-and-profiles-06 | Refresh with missing token then valid token; missing gives 401; use returned access token on me. |
| authentication-and-profiles-07 | Register device twice; DB has one token; logout removes it; fake widget-token exchange returns access token. |

### Spaces/channels — U, isolated S2; source tests/sanity/src/spaces-and-channels-scenarios.js and B/features/spaces, B/features/channels

| ID | Title, actions and expected result |
|---|---|
| spaces-and-invitations-01 | Create department space; assert owner membership and general/emergency/academics defaults. |
| spaces-and-invitations-02 | Preview invite as B; join; GET spaces/detail/members; assert B membership and returned channels. |
| spaces-and-invitations-03 | Repeat B join; expect 409 without duplicate membership. |
| spaces-and-invitations-04 | Rename S2 and rotate invite; reread name/new code; old invite preview gives 404. |
| spaces-and-invitations-05 | B leaves, owner removes C, owner tries leaving; final list only A, owner leave gives 400. |
| channels-01 | Create public channel, duplicate create gives 409, rename; mutation response contains new name. |
| channels-02 | Create private channel as A; GET creator detail returns same ID. |
| channels-03 | Send in custom channel, archive; messages retained in DB, message GET gives 403, active list excludes channel; default archive gives 400. |

### Messaging — C; source tests/sanity/src/messaging-scenarios.js and B/features/messages, B/features/channels, B/features/users/getNeedl

| ID | Title, actions and expected result |
|---|---|
| messaging-and-needl-01 | Send text A→general; B reads text/sender; detail contains matching lastMessage preview. |
| messaging-and-needl-02 | Send three roots; page limit=2 then before cursor; ordered roots have no overlap. |
| messaging-and-needl-03 | Quote prior message via replyToId; assert mutation response replyTo ID/text; independent persistence is added in FR-MSG-03. |
| messaging-and-needl-04 | Reply to root; immediately read root count/lastReply, thread and Needl; assert root/reply. This immediate read can race asynchronous updates. |
| messaging-and-needl-05 | Subscribe, edit text, delete it; assert update/delete events and soft-deleted DB state. |
| messaging-and-needl-06 | Toggle reaction on/off; pin/unpin; assert response reaction and pin arrays; independent persistence added under FR-SOC. |
| messaging-and-needl-07 | Empty text fails; send normal-priority text in emergency channel; stored priority is emergency. |

### Requests/conversations — U+C; source tests/sanity/src/message-requests-and-conversations-scenarios.js and B/features/message-requests, B/features/channels

| ID | Title, actions and expected result |
|---|---|
| message-requests-01 | Enable D requests; lookup, create/repeat A→D, read both directions/count; same request ID and recipient notification. Historical FAIL. |
| message-requests-02 | D accepts preceding request; assert accepted, DM listed for both, peer=A, sender acceptance notification names channel. Historical FAIL. |
| message-requests-03 | Create separate A→E eligible request; E declines; count decreases and repeated terminal action rejects. |
| direct-and-group-conversations-01 | Reopen accepted A/D DM from both sides; IDs identical. Historical BLOCKED by accept. |
| direct-and-group-conversations-02 | Send in accepted DM; recipient reads sender and lists peer/lastMessage. Historical BLOCKED. |
| direct-and-group-conversations-03 | Mark peer message read twice; one readBy; disable receipts and mark another; no new receipt. Historical BLOCKED. |
| direct-and-group-conversations-04 | Open self notes and send; create/reopen group with exact members; rename and assert membership/name. |
| direct-and-group-conversations-05 | Expand independent source DMs with none/all; verify new membership, zero/copied history and unchanged sources. Historical BLOCKED. |

### Handoffs — H; source tests/sanity/src/handoff-scenarios.js and B/features/handoffs

| ID | Title, actions and expected result |
|---|---|
| handoffs-01 | Create draft patient+attachment, edit summary, read; draft and attachment filename survive. |
| handoffs-02 | Empty draft submit gives 400; delete disposable draft; subsequent detail gives 404. |
| handoffs-03 | Submit populated draft; verify received list/space history, notification and submitted event; update/delete give 400. |
| handoffs-04 | B acknowledges with note; verify status/time/note, sender notification and event; duplicate acknowledgement rejects. |
| handoffs-05 | B adds note then reassigns to C; DB history has one entry and resets acknowledgement; C can acknowledge. |

### Media/notifications/realtime/search/support/runtime — M/N/U as appropriate

Sources: tests/sanity/src/media-scenarios.js, notification-scenarios.js, realtime-availability-scenarios.js, search-scenarios.js, support-scenarios.js, live-runner.js; corresponding B feature controllers/services/socket and app.js.

| ID | Title, actions and expected result |
|---|---|
| media-01 | Upload PNG, download exact bytes, delete, subsequent retrieval 404. |
| media-02 | Upload PDF, compare downloaded bytes; create handoff attachment and reread filename/MIME. |
| media-03 | Send inert image/ECG/document URL metadata; GET same URL/filename; final document sidebar label matches. No provider retrieval proof. |
| notifications-01 | Send ordinary message to non-viewing B; poll inbox/count, reference metadata and personal socket event. |
| notifications-02 | Mention B then emergency message; persisted type/priority match mention/emergency. |
| notifications-03 | Mark one read/unread, channel read, all read, delete; lists/counts match changes. |
| realtime-and-availability-01 | Authenticate two sockets, join, REST send, receive; disconnect/reconnect/rejoin. No second-message assertion exists in this retained case. |
| realtime-and-availability-02 | Start/stop typing; peer receives channel/user IDs. |
| realtime-and-availability-03 | REST/socket availability, room sync, final disconnect; assert stored state, broadcasts and offline presence. |
| search-01 | Known-user name query and phone lookup return intended colleague. |
| search-02 | Global marker search finds message/doctor/channel/attachment/handoff; nonmatching marker returns empty arrays. |
| support-01 | Submit bug, inspect ticket ID/author/type/title/description; missing title fails. |
| startup-01 | GET health; connected test DB and disabled Firebase/Cloudinary reported. |

## New cases

Columns: ID; title/function and ordered actions; expected behavior including persistence/realtime; tier/priority; coverage and clarification. Defaults: NEW, no clarification. Source aliases B/F are expanded in the master plan. Module ownership is the section heading; journeys have a separate accounting category.

### 1. Authentication/session

Preconditions U, unregistered phone per subcheck; dependency local SMS/widget fake and controllable OTP expiry. Sources B/features/auth/auth.controller.js, otp.model.js; B/services/otp.service.js, msg91Widget.service.js; B/middleware/validate.js; F/features/auth/data/repositories/auth_repository.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-AUTH-01 | OTP format boundaries: missing phone, no plus, 6/7/15/16 digits; code missing, 5/6/7 digits and letters | Validator accepts supported E164/6-digit shapes; invalid requests 400 and no user/session | B/P1 | NEW |
| FR-AUTH-02 | Resend before consumption; verify old code then latest | Old invalidated; latest usable; one identity | B/P0 | NEW |
| FR-AUTH-03 | Seed expiry just before/after controlled now; verify correct code; resend after expiry | Expired rejected independently of TTL deletion; fresh code works | B/P0 | NEW |
| FR-AUTH-04 | Two wrong attempts then correct third; separate OTP three wrong then correct fourth; resend | Third valid attempt succeeds; exhausted OTP fails; resend resets usable attempts | B/P1 | partial: authentication-and-profiles-03 |
| FR-AUTH-05 | Fake SMS provider timeout/rejection then success; request again and verify | 503 for transport failure; no authenticated user from failed send; subsequent request usable; record superseded OTP state | B/P1 | NEW |
| FR-AUTH-06 | Fake opaque widget accepted token with verified phone, rejected token, phone mismatch and explicit provider failure response | Valid identity/tokens only for verified matching phone; failure returns error without creating wrong user | B/P0 | partial: authentication-and-profiles-07 |
| FR-AUTH-07 | Expired refresh then newly logged-in refresh; access protected me | Expired refresh rejects; new login restores functional session | B/P0 | partial: authentication-and-profiles-06 |

### 2. Profiles/preferences

U; dependency authenticated unonboarded A for first case. Sources B/features/users/user.controller.js/updateMe,getMe; user.model.js; B/middleware/validate.js; F/features/profile/presentation/widgets/profile_details_form.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-PRO-01 | Save name+role for new user, read me, access spaces, relogin | Onboarding persists and protected app routes become available; same ID | B/P0 | partial: authentication-and-profiles-05 |
| FR-PRO-02 | Update name at 2/100/101, bio 300/301, institution 200/201, pgYear 1/6/0/7, invalid role | Supported endpoints accept exact limits, reject out-of-range with unchanged profile | B/P1 | NEW |
| FR-PRO-03 | Set mentions=false; separately set handoffs=false; GET and relogin | Partial preference updates retain both values and other defaults | B/P1 | NEW |
| FR-PRO-04 | Change title/speciality/avatar/bio then view peer in DM and member list | Fresh populated views use updated fields; no assumption stored historical sender snapshots update | B/P1 | NEW |
| FR-PRO-05 | Edit profile widget, cancel once; submit once with API error then success | Cancel no request; error retains inputs; successful reload renders saved profile | F/P1 | NEW |

### 3. Discovery/lookup

U plus pair acceptance and shared-space relationships independently prepared. Sources B/utils/knownUsers.js; B/features/users/user.controller.js/searchUsers,lookupByPhone; F/features/messages/data/models/user_lookup_result.dart; start_dm_page.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-DISC-01 | Lookup self, shared-space B, stranger D opt-in, stranger E opt-out, accepted peer | Self canMessage/no request; shared space enables request rather than new DM; accepted peer opens DM; opt-in affects request eligibility | B/P0 | partial: search-01 |
| FR-DISC-02 | Lookup valid absent phone and valid normalized variants; malformed input | Absent 404, malformed 400, equivalent supported formats resolve same ID | B/P1 | NEW |
| FR-DISC-03 | Search name/title/speciality, mixed case, spaces and literal punctuation; q length 1/2; filter S2 | Short q rejected; trimmed literal case-insensitive matches; S2 filter intersects known users | B/P1 | NEW |
| FR-DISC-04 | Search with 21 matching known users plus inactive/unonboarded fixture | At most 20 eligible results, no duplicates; inactive/incomplete omitted; do not assume unspecified order | B/P2 | NEW |

### 4. Spaces/invitations/membership

U/S2; admin role may be model-seeded because no promotion endpoint. Sources B/features/spaces/space.controller.js, space.model.js, space.routes.js; F/features/spaces/presentation/pages/join_invite_page.dart; B/socket/spaceRooms.js.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-SPC-01 | Create name 2/100/101, description 300/301, invalid type; read valid detail | Valid values/defaults persisted; invalid creates leave no partial space/channels | B/P1 | NEW |
| FR-SPC-02 | Preview/join lowercase invite; rotate; repeat preview for member | Case normalization works; alreadyMember true after join; new code usable | B/P1 | partial: spaces-and-invitations-02,-04 |
| FR-SPC-03 | Set requireApproval; B joins twice; inspect requests and UI response | One pending request, no membership; UI must not assume channels/join success; approval completion unsupported | B/P1 | Q14 |
| FR-SPC-04 | Owner/admin update settings; member tries rename/remove owner; reread | Supported admin actions persist; ordinary member rejected; owner remains | B/P1 | NEW |
| FR-SPC-05 | Set availability for members in distinct priority ranks; GET members | on_call before in_ot/on_rounds/in_icu before available before DND before off_duty; ties not specified | B/P2 | NEW |
| FR-SPC-06 | B leaves/removal while online; reload spaces/search, sync rooms, reconnect | Lists no longer include S; room membership after sync reflects current DB; immediate eviction guarantee needs decision | B/P0 | Q10 |

### 5. Channels

C; dependency owner A and member B. Sources B/features/channels/channel.controller.js/createChannel,getSpaceChannels,updateChannel,archiveChannel; B/utils/channelAccess.js; B/features/messages/message.controller.js/sendMessage.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-CH-01 | Create channel name 1/80/81 and uppercase/space, description 200/201; GET list | Limits/format enforced; accepted entry appears once and exact fields persist | B/P1 | partial: channels-01 |
| FR-CH-02 | Read S/detail/channel lists as A and B with public X/private Y | Public X in both; private Y in creator lists only; compare IDs across three list surfaces | B/P1 | partial: channels-02 |
| FR-CH-03 | Set onlyAdminsCanPost; B sends then A sends; clear setting and B sends | B rejected while enabled, A stored; B succeeds after reset; no rejected message/preview mutation | B/P1 | NEW |
| FR-CH-04 | Update custom description/name; reload; try rename/archive each default | Custom persisted; general/emergency/academics keep names and cannot archive | B/P1 | partial: channels-01,-03 |
| FR-CH-05 | Archive X containing root/pin; reload lists/search then try send | Active surfaces omit X, send rejected, DB messages retained; pin data not silently destroyed | B/P1 | partial: channels-03 |

### 6. Message requests/consent

U; D opt-in, E opt-out; fresh pair per terminal transition. Sources B/features/message-requests/messageRequest.controller.js and routes/model; B/utils/knownUsers.js; F/features/messages/presentation/widgets/message_request_prompt.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-REQ-01 | A requests D; D requests A before accepting; read both views | Same pending ID, incoming action accept_incoming; one record/count; peer and direction correct | B/P0 | partial: message-requests-01 |
| FR-REQ-02 | Try self, missing target, already accepted peer, opt-out E | Specific ordinary business rejection; no pending request/count/notification increase | B/P1 | NEW |
| FR-REQ-03 | Intro lengths 0/280/281; list sent/received/all, pending/accepted/declined | Route validation limit enforced; exact intro and peer serialization; filter results/count independent of outgoing | B/P1 | NEW |
| FR-REQ-04 | Recipient accepts/declines; repeat accept and opposite terminal action | Only first valid transition; persisted terminal state and count remain stable | B/P0 | partial: message-requests-02,-03 |
| FR-REQ-05 | Interrupt accept after request state write via DB fault; reload request and DM; retry | Record partial accepted-without-DM possibility; desired recovery/atomicity must be agreed, never count initial 2xx alone | B/P0 | Q7 |
| FR-REQ-06 | Flutter lookup yields sent/received/accepted states; tap supported CTA; inject request error | Correct send/wait/accept/open state; errors preserve retry UI; acceptance navigates returned channel | F/P1 | NEW |

### 7. Direct/group conversations

C plus F–K users eligible via shared S. Sources B/features/channels/channel.controller.js/createOrGetDM,createGroupDM,expandDM,enrichDM; channel.model.js; F/features/messages/presentation/widgets/needl_manage_sheets.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-DM-01 | Create group through both aliases with reordered/duplicate/self IDs; reopen | Exact deduplicated membership reuses group ID; one other delegates pair rules; self-only rejected | B/P0 | partial: direct-and-group-conversations-04 |
| FR-DM-02 | Create with 8 then 9 distinct other users | 9 total accepted, 10 total rejected with no partial group | B/P1 | NEW |
| FR-DM-03 | Rename to whitespace, 80 and 81 chars; GET from both members | Empty returns fallback display name, stored custom name trimmed/truncated to 80; members unchanged | B/P1 | partial: direct-and-group-conversations-04 |
| FR-DM-04 | Send in two DMs in known sequence; GET list as each user | Most recent lastMessage first; peer is opposite user; self notes isSelfNotes=true and group isNeedl=true | B/P1 | partial: direct-and-group-conversations-02 |
| FR-DM-05 | Expand today with messages before/at/after midnight, fixed server TZ | Current code selects >= server midnight; agree intended timezone before gate; source untouched | B/P1 | Q2 |
| FR-DM-06 | Expand all with 501 roots plus deleted record; inspect destination IDs/preview | Characterize oldest-500 cap and excluded deleted records; require decision on cap and source-ID preview mismatch | B/P1 | Q2 |
| FR-DM-07 | Expand with root+thread+quote; open copied thread/quote target | Source graph unchanged; destination graph behavior needs decision because threadId not copied and quote IDs reference source | B/P0 | Q2 |
| FR-DM-08 | Expand to membership already existing; repeat and compare counts | Existing destination reused, no second history import; all source records retained | B/P1 | NEW |
| FR-DM-09 | Concurrent pair/group reopen requests; inspect exact-membership records | Pair intent one conversation; group concurrency guarantee unresolved; classify target-specific failure without copying fork fix | B/P0 | Q7 |

### 8. Root messaging

C; sources B/features/messages/message.controller.js/model/routes; B/middleware/validate.js; F/features/messages/data/models/message_model.dart and message_repository.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-MSG-01 | Send missing/nonstring/whitespace text, 4000/4001 trimmed chars; valid Unicode/newlines | Invalid 400 no message; supported text persists without unexpected content loss | B/P1 | partial: messaging-and-needl-07 |
| FR-MSG-02 | Page roots with 0/1/100/101 limit, malformed before, empty and exact full final page | Invalid bounds rejected; hasMore uses extra row; no duplicate roots or thread leakage | B/P1 | partial: messaging-and-needl-02 |
| FR-MSG-03 | Quote text >120 chars and image/document; read snapshot after reload | Correct source ID/sender/type and 120-char text or Photo/filename fallback | B/P1 | partial: messaging-and-needl-03 |
| FR-MSG-04 | Edit text twice; attempt image edit; reload and observe event | Text isEdited/editedAt/content persisted; nontext edit 400; event identifies changed message | B/P1 | partial: messaging-and-needl-05 |
| FR-MSG-05 | Edit/delete newest message; reload channel list, quote, search and chat | Message state verified; preview/snapshot propagation policy unresolved; capture mismatches | B/P0 | Q1 |
| FR-MSG-06 | Delete older message as sender and space admin; reload DB and pages | Soft deletion, deletion placeholder text, cleared media/reactions and deleted event; unrelated messages intact | B/P1 | partial: messaging-and-needl-05 |
| FR-MSG-07 | Send urgent in general and normal in emergency; reload message/notification | General preserves urgent; emergency overrides to emergency; notification priority follows | B/P0 | partial: messaging-and-needl-07 |
| FR-MSG-08 | Commit send then drop response at proxy; reopen chat before manual resend | Fetch reveals committed record; automatic exactly-once resend not assumed; product decision on duplicate prevention | B/P0 | Q7 |

### 9. Threads/Needl

C with multiple roots/replies. Sources B/features/messages/message.controller.js/getThread,replyToThread,sendMessage; B/features/users/user.controller.js/getNeedl; F/features/messages/presentation/cubit/thread_cubit.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-THR-01 | A/B reply to one root; await side effects; reload root/thread/Needl | Count equals replies, lastReply correct sender/100-char preview, reply IDs not main roots | B/P0 | partial: messaging-and-needl-04 |
| FR-THR-02 | Three replies, limit=2 then before oldest returned; include deleted reply | Ascending presentation within page; no overlap, correct hasMore; deleted omitted | B/P1 | NEW |
| FR-THR-03 | Seed 41 active roots with distinct updatedAt; GET Needl, archive one channel | At most 40 newest qualifying roots; metadata channel/root IDs correct; archived excluded | B/P1 | NEW |
| FR-THR-04 | Delete/edit most recent reply then read root and Needl | Thread content reflects action; aggregate correction policy Q1 required | B/P1 | Q1 |
| FR-THR-05 | Deliver same reply socket twice and then HTTP page in Flutter thread/root views | One rendered reply and one increment; refresh converges to server counts | F/P0 | NEW |

### 10. Reactions/pins/read receipts

C with six distinct live messages. Sources B/features/messages/message.model.js/toggleReaction; message.controller.js/markAsRead; B/features/channels/channel.controller.js/pinMessage,unpinMessage; F/features/messages/presentation/widgets/read_receipt_footer.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-SOC-01 | A and B toggle same emoji; A removes; B uses another; reread/events | One emoji per user; switching replaces B's prior emoji; removal leaves other users intact; event matches stored set | B/P1 | partial: messaging-and-needl-06 |
| FR-SOC-02 | React to deleted message; submit invalid/empty emoji per route validation | Reject supported invalid forms and deleted reaction; old reactions unchanged | B/P1 | NEW |
| FR-SOC-03 | Pin five distinct; sixth rejected; unpin one then pin sixth; reload detail | At most five, populated message/sender and pinnedBy/time retained, freed slot reusable | B/P1 | partial: messaging-and-needl-06 |
| FR-SOC-04 | Re-pin same ID below cap and at cap; unpin absent ID | Re-pin below cap returns 409; at cap returns 400 (cap checked first); absent unpin succeeds; cardinality unchanged | B/P2 | NEW |
| FR-SOC-05 | B/C mark separate group-DM messages/read batches twice; opt out B for new record | One readBy per user/message, timestamps stable on duplicate, C independent; opt-out no added B receipt | B/P1 | partial: direct-and-group-conversations-03 |
| FR-SOC-06 | Render pending/failed/sent/read messages and preference-disabled footer | UI labels reflect model; no claim sent=delivered; opt-out hides receipt UI | F/P1 | NEW |

### 11. Handoffs/patients

H; sources B/features/handoffs/handoff.controller.js/model/routes; F/features/handoffs/data/models/handoff_model.dart; presentation/cubit/handoff_form_cubit.dart and pages/handoff_detail_page.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-HOF-01 | Draft two patients; replace/edit/remove one with explicit IDs; change date/shift and reload | Remaining patient fields/tasks/flags/attachments exact, draft status and sender preserved | B/P0 | partial: handoffs-01 |
| FR-HOF-02 | Missing bed/alias, bed 20/21, alias 100/101, notes 2000/2001, summary 2000/2001, invalid status/date/shift | Valid schema boundaries save; invalid reject without replacing previous draft | B/P1 | NEW |
| FR-HOF-03 | Submit same populated draft concurrently twice, then acknowledge concurrently twice | One successful transition each, timestamps set once; exactly one transition notification/event by resource after quiescence | B/P0 | partial: handoffs-03,-04 |
| FR-HOF-04 | Draft acknowledge/note/reassign; submit empty draft; attempt update/delete after submit | Invalid lifecycle operations rejected; no state or patient loss | B/P0 | partial: handoffs-02,-03 |
| FR-HOF-05 | Read draft through received status filter/detail/space/search as B/member/admin | Record cross-view difference; Q3 decides accepted audience before gate | B/P0 | Q3 |
| FR-HOF-06 | List sent/received/all by status, S/S2 and date with records at day boundaries | Correct participant/date filters; populated users; draft visibility handled under Q3 | B/P1 | NEW |
| FR-HOF-07 | Page space history with out-of-order IDs vs shiftDate; limit=2 | Intended no missing/repeated items needs cursor/sort decision; save ordered IDs to demonstrate gap | B/P1 | Q4 |
| FR-HOF-08 | Add each note kind after submit, empty/1000/1001 text; reread | Valid trimmed text/author/kind/time append, blank/oversize rejected; handoff patient/status unchanged | B/P1 | partial: handoffs-05 |
| FR-HOF-09 | Reassign acknowledged B→C then C→B; inspect histories/inboxes/events | Two ordered history entries, new assignee/submitted, ack reset, patients retained, correct new notification | B/P0 | partial: handoffs-05 |
| FR-HOF-10 | Reassign same assignee, nonmember, and draft; note at route limit | Rejected invalid transition, history/ack unchanged; supported note limit follows route and model | B/P1 | NEW |
| FR-HOF-11 | Flutter draft save succeeds then submit fails; retry submit | Existing draft ID reused; input retained, no duplicate draft; submit only after save success | F/P0 | NEW |
| FR-HOF-12 | Render yesterday/today/tomorrow submitted and acknowledged handoffs around local midnight | Client lifecycle label changes per model, backend status unchanged; timezone/wording Q12 | F/P1 | Q12 |
| FR-HOF-13 | Patient editor adds/removes tasks and attachment, flags patient, cancel then save | Cancel leaves form unchanged; save updates selected patient only; validation shown before submit | F/P1 | NEW |

### 12. Media

M+C/H as needed; sources B/features/media/media.routes.js/controller; B/constants/index.js/MEDIA; B/utils/localMediaStorage.js; F/features/media/data/services/media_picker_service.dart, document_open_service.dart; F/features/profile/presentation/pages/avatar_crop_page.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-MED-01 | Upload missing file, supported PNG/PDF/MP4, unsupported TXT/DOC, 25MiB/25MiB+1 file | Missing/unsupported/oversize reject; supported bytes/metadata retained; exact limit from MEDIA.MAX_FILE_SIZE_BYTES | B/P1 | partial: media-01,-02 |
| FR-MED-02 | Upload octet-stream named .pdf/.mp4 then inspect returned metadata/open | Extension fallback accepted by filter; MIME-derived format mismatch characterized; Q5 decides normalized type contract | B/P1 | Q5 |
| FR-MED-03 | Upload local PNG then use returned URL in image message | Current local URL rejected by send policy; Q5 must resolve full pipeline, never substitute inert URL and call E2E passed | B/P0 | Q5 |
| FR-MED-04 | Upload video then submit type=video | Upload supported but validator rejects; Q5 required to enable successful send expectation | B/P1 | Q5 |
| FR-MED-05 | Fake provider image/PDF/video upload responses and failure; inspect requests/output | image/raw/video resource type, folders, filename/size, thumbnail/delivery mapping; provider error returns upload failure, no message created | B/P1 | NEW |
| FR-MED-06 | Upload avatar A, save profile URL, replace B; delete A and reload profile | Profile points to B; old-file lifecycle and dangling references Q6; no invented automatic deletion | B/P1 | Q6 |
| FR-MED-07 | Delete referenced file and handoff-context/video file; reopen consuming view | Local bytes removed when supported; references not auto-cleared; Q6 defines retention/error UX and missing video destroy support | B/P1 | Q6 |
| FR-MED-08 | Device pick/cancel image/PDF/video, deny permission then allow; open file via OS | Cancel sends nothing; denial recoverable; supported selected file preview and external opener work; unsupported formats clearly fail | D/P1 | NEW; Q5 only for unsupported pipeline |

### 13. Notification inbox

N; sources B/features/notifications/notification.controller.js/model; B/services/notification.service.js/notifyNewMessage,notifyMention; B/socket/channelViewers.js; F/features/notifications/presentation/cubit/notifications_cubit.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-NOT-01 | B joins viewed channel; A sends ordinary then emergency; B leaves and A sends ordinary | Ordinary suppressed while viewing; emergency still stored; later ordinary stored; sender excluded | B/P0 | partial: notifications-01,-02 |
| FR-NOT-02 | Mention B and self while B viewing/not viewing; inspect records | Self mention excluded; viewed B mention suppressed; non-viewed B gets mention; ordinary and mention may both exist by type | B/P1 | partial: notifications-02 |
| FR-NOT-03 | Seed read/unread types across 3 pages; query unreadOnly/type/limit/before | Filtered pages no overlap, correct hasMore; returned unreadCount is total user unread, not filtered page length | B/P1 | partial: notifications-03 |
| FR-NOT-04 | Channel read with string/ObjectId metadata, unrelated channel, then repeat | Both representations read, unrelated unchanged, repeat modifiedCount=0; count reconciles | B/P1 | partial: notifications-03 |
| FR-NOT-05 | Inject notification DB failure after successful send, restore; read message and perform new send | First message persists despite side-effect failure; next send notification works; no automatic replay promise | B/P1 | NEW |
| FR-NOT-06 | Socket notification then HTTP refresh then mark unread/read in Flutter | Dedupe by ID, badge/list consistent; mutation failure restores or refreshes correct state | F/P0 | NEW |

### 14. Push/device-token lifecycle

N; fake messaging transport only. Sources B/features/users/user.model.js/addFcmToken; B/features/auth/auth.controller.js/logout; B/services/notification.service.js; F/core/notifications/fcm_service.dart, grouped_message_notification.dart, notification_reply_sender.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-PUSH-01 | Register t1–t6, re-register t3, logout t3 | Most recent five unique tokens retained; t3 moved to front then removed; other device tokens stay | B/P1 | partial: authentication-and-profiles-07 |
| FR-PUSH-02 | Disable each mapped preference; emit matching notification with fake push capture | Inbox/socket still persist; disabled type sends no push; enabled control does send | B/P1 | NEW |
| FR-PUSH-03 | Controlled time at start/end for same-day/overnight/equal quiet hours, emergency preference on/off | start inclusive/end exclusive, equal disabled; current emergency bypass only after preference check; timezone Q9 | B/P1 | Q9 |
| FR-PUSH-04 | Fake stale-token error for t1, temporary error t2, success t3 | t1 eventually removed; t2/t3 retained; persisted inbox unaffected; string metadata and routing fields correct | B/P1 | NEW |
| FR-PUSH-05 | Device injected background notification for same channel twice and other channel; tap/reply | Correct channel grouping, navigation and local reply dispatch; successful reply stored once in local backend; no real FCM proof | D/P0 | NEW |
| FR-PUSH-06 | Device deny notifications then grant; token refresh and logout/relogin | App remains usable; refreshed token registration and logout removal verified locally; no platform delivery guarantee | D/P1 | NEW |

### 15. Realtime/presence

C/N; sources B/socket/index.js, spaceRooms.js, handlers; F/core/socket/socket_client.dart; F/core/realtime/typing_presence.dart; F/core/presence/presence_cubit.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-RT-01 | Connect two devices as A, disconnect first, then last; observe B and DB | First disconnect leaves online; last emits offline and lastSeenAt persists | B/P0 | partial: realtime-and-availability-03 |
| FR-RT-02 | A joins new S while connected; sync/reconnect; receive space event | New space room included, sync acknowledgement count correct; presence snapshot IDs unique | B/P1 | partial: realtime-and-availability-01,-03 |
| FR-RT-03 | Update availability via REST then socket with note/until; read me and peer payload | Persistence matches; socket note/until broadcast discrepancy Q8 must resolve | B/P1 | Q8 |
| FR-RT-04 | Two clients type/stop; duplicate events; leave/dispose Flutter chat; advance clock | Correct peer/channel typing state; no self indicator; timeout clears stale typing; disposed listeners do not update closed state | F/P1 | partial: realtime-and-availability-02 |
| FR-RT-05 | Disconnect B; A sends/edits; reconnect/rejoin and fetch | HTTP recovers persisted state for fresh connection; limited Socket.IO recovery is tested separately; Flutter duplicate events do not duplicate messages | F/P0 | partial: realtime-and-availability-01 |
| FR-RT-06 | Expire stored access token, resume and reconnect; refresh success then failure | Valid refresh reconnects with new token; failure yields session recovery UI without endless connection loop | F/P0 | NEW |
| FR-RT-07 | Preserve Socket.IO session/offset, interrupt transport briefly within configured 120 seconds, send while disconnected, reconnect; then type/join/update availability | Configured recovery restores missed events/rooms; recovered connection must still have functional handlers and presence; compare fresh reconnect control. Source skips handler registration when recovered, so flag any runtime failure rather than assuming listeners survive | B/P0 | NEW |

### 16. Global search

C/H with unique markers and fixed timestamps; sources B/features/search/search.controller.js/globalSearch; F/features/search/presentation/pages/global_search_page.dart and data/repositories/search_repository.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-SRCH-01 | Query each type and all, mixed case/whitespace/literal punctuation, q length 1/2 | Correct populated arrays only, query trimmed; q<2 rejected; literal matching | B/P1 | partial: search-02 |
| FR-SRCH-02 | 51 matching messages/attachments; limit=1/50; archive one channel | Max 50 per category, newest first where sorted; archived results omitted | B/P1 | NEW |
| FR-SRCH-03 | Search alias/ward/bed/diagnosis/notes vs summary in handoff | Patient-specific title assembled when matched; otherwise summary; detail navigation visibility Q3 tracked separately | B/P1 | partial: search-02 |
| FR-SRCH-04 | Flutter type query A then B; return B response before A; empty/error then retry | Latest visible query owns results, no stale overwrite; error state recoverable; correct result route selected | F/P1 | NEW |

### 17. Support/developer tools

U/F0; sources B/features/support/support.controller.js/routes; B/features/dev/dev.routes.js; F/features/support/presentation/pages and features/dev/presentation/pages/developer_mode_page.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-SUP-01 | Submit feature and feedback; DB inspect each; blank title/description | Correct distinct type/author/open status; required blanks rejected | B/P2 | partial: support-01 |
| FR-SUP-02 | Bug/feature lengths title 201, description 5001, steps/context 3001 | Controller trims/truncates to 200/5000/3000; accepted ticket data exact | B/P2 | NEW |
| FR-SUP-03 | Dev enabled: seed notification/conversation/handoff; no-space then joined user | No-space gives actionable error; joined fixtures created with correct IDs/content; disabled mode rejects seed | B/P2 | NEW |
| FR-SUP-04 | Flutter bug/feature/feedback error then success; open help/legal/contact | Input retained on error, success acknowledgement matches ticket; routes and bundled content render; external contact intent captured only | F/P2 | NEW |

### 18. Startup/navigation/lifecycle

F0/D0; sources F/features/auth/presentation/bloc/auth_bloc.dart; F/core/router/app_router.dart, shell_tab_history.dart, app_navigation_back_handler.dart; F/core/lifecycle/app_lifecycle_handler.dart; F/core/network/auth_interceptor.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-NAV-01 | Launch no session, valid incomplete session, valid onboarded session | Login/profile setup/home respectively, no transient wrong destination; stored identity loaded | F/P0 | partial: widget_test.dart splash only |
| FR-NAV-02 | HTTP 401 refresh success, failure, repeated 401 and concurrent requests | Success retries request with new token; failure clears session; bounded retry desired, recursion/concurrency behavior recorded for clarification | F/P0 | Q7 |
| FR-NAV-03 | Switch tabs, open nested detail, Back repeatedly | Detail then documented tab history restored; no duplicate route stack or lost selected tab | F/P1 | NEW |
| FR-NAV-04 | Device background, offline, foreground, restore network | Resume invokes connection restoration; current chat can refetch; input survives supported draft storage | D/P0 | NEW |
| FR-NAV-05 | Device force-stop/relaunch with session then logout and relaunch | Secure session restoration routes correctly; logout removes local session even if API logout errors | D/P0 | NEW |

### 19. Composer/offline state

F0; sources F/features/messages/presentation/cubit/channel_chat_cubit.dart/thread_cubit.dart; F/core/storage/draft_message_service.dart; F/core/chat/chat_transcript_cache.dart; F/features/messages/presentation/pages/channel_chat_page.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-OFF-01 | Send text; deliver matching socket before HTTP and then reverse order | Optimistic row reconciled to one server ID, isSending cleared; text/quote retained | F/P0 | NEW |
| FR-OFF-02 | Send transport error; reopen chat; successful subsequent send | Failed row visibly failed, composer usable; no invented durable queue or automatic resend | F/P0 | NEW |
| FR-OFF-03 | Save root/thread drafts separately; recreate service; clear one; list draft channels | Exact text restored; thread keys separate/excluded from channel badges; unrelated draft retained | F/P1 | partial: draft_message_service_test.dart |
| FR-OFF-04 | Cached transcript then offline load, reconnect fetch changed content | Cache offers prior messages in process; recovery replaces stale state; app restart does not promise disk transcript | F/P1 | NEW |
| FR-OFF-05 | Start attachment upload, fail then retry/cancel; double-tap send while busy | No text-message success before upload/send success; error visible, no duplicate busy submission | F/P1 | NEW |
| FR-OFF-06 | Logout A, login B on same storage, inspect drafts/bookmarks/recent/cache | Decide retained/account-scoped data Q11; capture leak/stale UX without presuming implemented cleanup | F/P0 | Q11 |

### 20. Saved/recent items

F0; sources F/core/storage/bookmark_service.dart, recent_items_service.dart; F/features/bookmarks/presentation/pages/bookmarks_page.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-SAVE-01 | Save message/thread/handoff bookmarks, re-save same ID, restart service, toggle off | One item per ID, newest savedAt first, routes carry correct IDs; remove persists | F/P1 | NEW |
| FR-SAVE-02 | Corrupt bookmark JSON and missing target on navigation | Corrupt data returns empty safely; unavailable target shows recoverable error, not crash | F/P2 | NEW |
| FR-SAVE-03 | Visit 9 channels and pin 13 items; revisit/re-pin duplicate; recreate service | Recent channels cap 8, pins cap 12; dedup/order preserved; independent recent-space behavior not assumed capped | F/P2 | NEW |

### 21. Home/dashboard

F0 with fake assigned handoffs and two spaces; sources F/features/home/data/dashboard_preferences_service.dart; presentation/cubit/home_dashboard_cubit.dart; widgets/doctor_workspace_widgets.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-HOME-01 | Hide/reorder widgets, save/recreate, reset; older/corrupt stored config | Order/visibility survive, defaults restored, missing new widgets merged; corruption safe defaults | F/P1 | partial: dashboard_preferences_service_test.dart |
| FR-HOME-02 | Submitted assigned handoff, acknowledge/reassign through fake refreshed responses | Assigned/shift/task cards reflect current assignee/status; no separate roster state fabricated | F/P0 | NEW |
| FR-HOME-03 | Empty dashboard then mixed hospital/department announcements/emergency channels; partial API failure | Appropriate empty/action cards, correct target navigation; DM-load failure falls back to empty DMs; required repository failure sets dashboard error and retry restores data | F/P1 | NEW |

### 22. Forwarding/invites/deep links

F0/D0+C; sources F/features/messages/presentation/widgets/forward_message_sheet.dart; F/features/spaces/presentation/pages/join_invite_page.dart, scan_invite_qr_page.dart; F/core/utils/qr_decode_utils.dart; F/core/notifications/push_notification_router.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-LINK-01 | Forward text and media to chosen existing chat; fake failure then retry | Text payload includes attribution/source link/body/media URL; one successful destination message; failure retains sheet | F/P1 | NEW; native media forwarding not promised |
| FR-LINK-02 | Copy source link, attempt router resolution | Copied vocle://c/<id>/m/<id> string exact; opening target currently incomplete, Q13 required | F/P2 | Q13 |
| FR-LINK-03 | Push channel/DM/handoff/missing target; rapid taps; logged-out then login | Latest debounced route wins; auth queues intended destination; missing target falls back to notification/handoff list | F/P0 | NEW |
| FR-LINK-04 | Device scan invite QR/raw code/link, deny camera, cancel; preview then join | Supported code extracted, no accidental join on cancel, permission recovery; join reflects actual member/pending response | D/P1 | partial: phone_utils_test.dart parsing; Q14 pending UI |

### 23. Runtime/error recovery

U+C; isolated process lifecycle; sources B/app.js/server.js/middleware/errorHandler.js; F/core/network/api_client.dart; F/shared/data/repositories/base_repository.dart.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-RUN-01 | Persist profile/space/message/handoff; restart backend against same disposable DB; reconnect/read | Same IDs/content/status available; ephemeral presence rebuilt from new sockets | B/P0 | NEW |
| FR-RUN-02 | Stop DB during read, restore and request again | Bounded error/no fabricated empty success; recovery permits fresh read; no automatic failed-write replay assumed | B/P1 | NEW |
| FR-RUN-03 | Flutter fake timeout/5xx/malformed response then success across list and detail | Error state distinct from empty result; loading terminates; retry restores correct data | F/P1 | NEW |

## Cross-feature journeys (not extra feature modules)

U+C+H through public APIs for B; D0 uses actual UI and local backend. Dependencies are explicit chain order; failures block later steps, while independent component cases still run. Sources are the participating module anchors above. No model seeding may substitute the operation validated by the journey.

| ID | Title and actions | Expected result | Tier/priority | Coverage / question |
|---|---|---|---|---|
| FR-JRN-01 | Register A/B, onboard, A creates S, B joins, exchange text, A submits H, B acknowledges, relogin and reload | Stable identities/membership/messages/handoff status and notifications across sessions; no invented handoff system message | B/P0 | NEW integrated journey |
| FR-JRN-02 | Lookup opted-in D, send request, D accepts, exchange DM, mark read, reopen from both users | Consent changes ability to message, one DM ID, exact messages/receipt and notification route | B/P0 | partial: request/DM sanity chain |
| FR-JRN-03 | Submit H to B; B cant_cover note; reassign C; C acknowledges; A refreshes inbox/history | Responsibility moves without losing patients/tasks; history/notes/ack reset/new ack and alerts consistent | B/P0 | partial: handoffs-05 |
| FR-JRN-04 | B leaves S, reloads spaces/search/Needl and syncs socket; rejoins current invite | Supported lists recover membership; no stale active rooms after sync; immediate transition semantics Q10 | B/P0 | Q10 |
| FR-JRN-05 | Device compose draft, background/offline, resume, send when online, receive peer reply, logout/relogin | Draft and committed content survive their supported storage scope; exactly one displayed committed message after refetch | D/P0 | NEW |
| FR-JRN-06 | Device receive injected handoff notification cold-start; login if needed; open, acknowledge, inspect sender | Right handoff/assignee displayed; one acknowledgement; sender sees local backend update; no real provider proof | D/P0 | NEW |

## Guardrails for implementation

Do not treat question-marked rows as expected failures or accept source bugs as desired contracts. Split verified subassertions from unresolved ones in reports, keeping this stable parent ID. Preserve the 48 existing IDs and existing failure gates. Existing Flutter unit coverage is credited as partial, not as completed widget/device proof. No route count, successful upload alone, or healthy backend proves a mobile workflow.
