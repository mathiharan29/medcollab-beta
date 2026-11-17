# Vocle feature regression matrix

Generated from the functional catalog, the feature registry and the existing executor declarations.
To regenerate this file after updating the registry, run `node tests/functional-regression/scripts/feature-matrix.mjs` from the repository root.

## Feature summary

| Feature | Backend cases | Flutter cases | Security cases | Android cases | Total unique cases |
|---|---:|---:|---:|---:|---:|
| Authentication and sessions (`authentication`) | 19 | 4 | 0 | 4 | 27 |
| Profiles and preferences (`profile`) | 10 | 1 | 0 | 0 | 11 |
| Contact discovery (`contact-discovery`) | 7 | 8 | 0 | 0 | 15 |
| Direct messaging and consent (`direct-messaging`) | 27 | 7 | 0 | 1 | 35 |
| Group and channel messaging (`group-messaging`) | 35 | 2 | 0 | 0 | 37 |
| Voice messaging (`voice-messaging`) | 5 | 12 | 0 | 1 | 18 |
| Voice assistant (`voice-assistant`) | 2 | 28 | 0 | 1 | 31 |
| Voice Assistant — Live Audio (`voice-assistant-live-audio`) | 0 | 0 | 0 | 3 | 3 |
| Voice Assistant — Prerecorded File Recognition (`voice-assistant-prerecorded`) | 0 | 0 | 0 | 6 | 6 |
| Voice Assistant — Noise & Reliability (`voice-assistant-noise`) | 0 | 0 | 0 | 2 | 2 |
| Handoffs (`handoff`) | 24 | 15 | 0 | 2 | 41 |
| Handoff Voice (`handoff-voice`) | 3 | 11 | 0 | 1 | 15 |
| Needl (`needl`) | 47 | 33 | 0 | 0 | 80 |
| Threads and message actions (`message-actions`) | 28 | 5 | 0 | 0 | 33 |
| Media sharing (`media-sharing`) | 15 | 5 | 0 | 1 | 21 |
| Notifications (`notifications`) | 21 | 2 | 0 | 3 | 26 |
| Workspaces and invitations (`workspaces`) | 22 | 1 | 0 | 1 | 24 |
| Search (`search`) | 8 | 6 | 0 | 0 | 14 |
| Navigation and home (`navigation`) | 0 | 15 | 0 | 5 | 20 |
| Offline and recovery (`offline-recovery`) | 8 | 16 | 0 | 3 | 27 |
| Saved items and sharing links (`saved-and-shared`) | 1 | 8 | 0 | 1 | 10 |
| Realtime and availability (`realtime`) | 18 | 9 | 0 | 1 | 28 |
| Support and platform operations (`support-and-ops`) | 6 | 1 | 0 | 0 | 7 |
| Access and privacy (`access-and-privacy`) | 47 | 3 | 0 | 1 | 51 |

The catalog has **313 unique cases** and **582 feature assignments**. A test with several tags counts once in each feature and once in `all`.

The Security column counts dedicated security-suite IDs. The separate API and realtime, MongoDB, offline media and Cloudinary inventories use their existing workflows. Access and privacy checks inside this functional catalog keep their backend, Flutter or Android layer.

See the [voice coverage audit](VOICE-COVERAGE-AUDIT.md) for the baseline evidence, new voice cases and native test steps.

## Case assignments

| Feature tags | Regression ID | Test description | Test layer | Executor |
|---|---|---|---|---|
| authentication | `authentication-and-profiles-01` | Request OTP; inspect hashed record; verify captured code; assert new verified user, access/refresh tokens and persisted identity. | Backend | [authentication-scenarios.js](../../tests/sanity/src/authentication-scenarios.js) |
| authentication | `authentication-and-profiles-02` | Request/verify again for same phone; assert same user ID and isNewUser=false. | Backend | [authentication-scenarios.js](../../tests/sanity/src/authentication-scenarios.js) |
| authentication | `authentication-and-profiles-03` | Submit wrong code then correct captured code; first rejects, second yields token. | Backend | [authentication-scenarios.js](../../tests/sanity/src/authentication-scenarios.js) |
| authentication, access-and-privacy | `authentication-and-profiles-04` | Reuse consumed code; reject and do not create another user. | Backend | [authentication-scenarios.js](../../tests/sanity/src/authentication-scenarios.js) |
| authentication, profile | `authentication-and-profiles-05` | Update onboarding name/institution; GET me; assert onboarded and exact profile values. | Backend | [authentication-scenarios.js](../../tests/sanity/src/authentication-scenarios.js) |
| authentication | `authentication-and-profiles-06` | Refresh with missing token then valid token; missing gives 401; use returned access token on me. | Backend | [authentication-scenarios.js](../../tests/sanity/src/authentication-scenarios.js) |
| authentication, notifications | `authentication-and-profiles-07` | Register device twice; DB has one token; logout removes it; fake widget-token exchange returns access token. | Backend | [authentication-scenarios.js](../../tests/sanity/src/authentication-scenarios.js) |
| group-messaging, workspaces | `spaces-and-invitations-01` | Create department space; assert owner membership and general/emergency/academics defaults. | Backend | [spaces-and-channels-scenarios.js](../../tests/sanity/src/spaces-and-channels-scenarios.js) |
| workspaces | `spaces-and-invitations-02` | Preview invite as B; join; GET spaces/detail/members; assert B membership and returned channels. | Backend | [spaces-and-channels-scenarios.js](../../tests/sanity/src/spaces-and-channels-scenarios.js) |
| workspaces | `spaces-and-invitations-03` | Repeat B join; expect 409 without duplicate membership. | Backend | [spaces-and-channels-scenarios.js](../../tests/sanity/src/spaces-and-channels-scenarios.js) |
| workspaces | `spaces-and-invitations-04` | Rename S2 and rotate invite; reread name/new code; old invite preview gives 404. | Backend | [spaces-and-channels-scenarios.js](../../tests/sanity/src/spaces-and-channels-scenarios.js) |
| workspaces, access-and-privacy | `spaces-and-invitations-05` | B leaves, owner removes C, owner tries leaving; final list only A, owner leave gives 400. | Backend | [spaces-and-channels-scenarios.js](../../tests/sanity/src/spaces-and-channels-scenarios.js) |
| group-messaging, workspaces | `channels-01` | Create public channel, duplicate create gives 409, rename; mutation response contains new name. | Backend | [spaces-and-channels-scenarios.js](../../tests/sanity/src/spaces-and-channels-scenarios.js) |
| group-messaging, workspaces, access-and-privacy | `channels-02` | Create private channel as A; GET creator detail returns same ID. | Backend | [spaces-and-channels-scenarios.js](../../tests/sanity/src/spaces-and-channels-scenarios.js) |
| group-messaging, workspaces, access-and-privacy | `channels-03` | Send in custom channel, archive; messages retained in DB, message GET gives 403, active list excludes channel; default archive gives 400. | Backend | [spaces-and-channels-scenarios.js](../../tests/sanity/src/spaces-and-channels-scenarios.js) |
| group-messaging, message-actions, realtime | `messaging-and-needl-01` | Send text A→general; B reads text/sender; detail contains matching lastMessage preview. | Backend | [messaging-scenarios.js](../../tests/sanity/src/messaging-scenarios.js) |
| group-messaging, message-actions | `messaging-and-needl-02` | Send three roots; page limit=2 then before cursor; ordered roots have no overlap. | Backend | [messaging-scenarios.js](../../tests/sanity/src/messaging-scenarios.js) |
| group-messaging, message-actions | `messaging-and-needl-03` | Quote prior message via replyToId; assert mutation response replyTo ID/text; independent persistence is added in FR-MSG-03. | Backend | [messaging-scenarios.js](../../tests/sanity/src/messaging-scenarios.js) |
| group-messaging, needl, message-actions | `messaging-and-needl-04` | Reply to root; immediately read root count/lastReply, thread and Needl; assert root/reply. This immediate read can race asynchronous updates. | Backend | [messaging-scenarios.js](../../tests/sanity/src/messaging-scenarios.js) |
| group-messaging, message-actions, realtime | `messaging-and-needl-05` | Subscribe, edit text, delete it; assert update/delete events and permanent removal from MongoDB. | Backend | [messaging-scenarios.js](../../tests/sanity/src/messaging-scenarios.js) |
| group-messaging, message-actions | `messaging-and-needl-06` | Toggle reaction on/off; pin/unpin; assert response reaction and pin arrays; independent persistence added under FR-SOC. | Backend | [messaging-scenarios.js](../../tests/sanity/src/messaging-scenarios.js) |
| group-messaging, message-actions | `messaging-and-needl-07` | Empty text fails; send normal-priority text in emergency channel; stored priority is emergency. | Backend | [messaging-scenarios.js](../../tests/sanity/src/messaging-scenarios.js) |
| contact-discovery, direct-messaging, notifications | `message-requests-01` | Enable D requests; lookup, create/repeat A→D, read both directions/count; same request ID and recipient notification. Historical FAIL. | Backend | [message-requests-and-conversations-scenarios.js](../../tests/sanity/src/message-requests-and-conversations-scenarios.js) |
| direct-messaging, notifications | `message-requests-02` | D accepts preceding request; assert accepted, DM listed for both, peer=A, sender acceptance notification names channel. Historical FAIL. | Backend | [message-requests-and-conversations-scenarios.js](../../tests/sanity/src/message-requests-and-conversations-scenarios.js) |
| direct-messaging | `message-requests-03` | Create separate A→E eligible request; E declines; count decreases and repeated terminal action rejects. | Backend | [message-requests-and-conversations-scenarios.js](../../tests/sanity/src/message-requests-and-conversations-scenarios.js) |
| direct-messaging | `direct-and-group-conversations-01` | Reopen accepted A/D DM from both sides; IDs identical. Historical BLOCKED by accept. | Backend | [message-requests-and-conversations-scenarios.js](../../tests/sanity/src/message-requests-and-conversations-scenarios.js) |
| direct-messaging | `direct-and-group-conversations-02` | Send in accepted DM; recipient reads sender and lists peer/lastMessage. Historical BLOCKED. | Backend | [message-requests-and-conversations-scenarios.js](../../tests/sanity/src/message-requests-and-conversations-scenarios.js) |
| direct-messaging, message-actions, access-and-privacy | `direct-and-group-conversations-03` | Mark peer message read twice; one readBy; disable receipts and mark another; no new receipt. Historical BLOCKED. | Backend | [message-requests-and-conversations-scenarios.js](../../tests/sanity/src/message-requests-and-conversations-scenarios.js) |
| direct-messaging, group-messaging, needl, saved-and-shared | `direct-and-group-conversations-04` | Open self notes and send; create/reopen group with exact members; rename and assert membership/name. | Backend | [message-requests-and-conversations-scenarios.js](../../tests/sanity/src/message-requests-and-conversations-scenarios.js) |
| direct-messaging, group-messaging, needl | `direct-and-group-conversations-05` | Expand a source DM to two Needls with none/all; verify added membership, the member-added activity line, zero/copied source history and unchanged source. | Backend | [message-requests-and-conversations-scenarios.js](../../tests/sanity/src/message-requests-and-conversations-scenarios.js) |
| handoff | `handoffs-01` | Create draft patient+attachment, edit summary, read; draft and attachment filename survive. | Backend | [handoff-scenarios.js](../../tests/sanity/src/handoff-scenarios.js) |
| handoff | `handoffs-02` | Empty draft submit gives 400; delete disposable draft; subsequent detail gives 404. | Backend | [handoff-scenarios.js](../../tests/sanity/src/handoff-scenarios.js) |
| handoff, notifications, access-and-privacy | `handoffs-03` | Submit populated draft; verify received list/space history, notification and submitted event; recipient edit/withdraw give 403. | Backend | [handoff-scenarios.js](../../tests/sanity/src/handoff-scenarios.js) |
| handoff, notifications | `handoffs-04` | B acknowledges with note; verify status/time/note, sender notification and event; duplicate acknowledgement rejects. | Backend | [handoff-scenarios.js](../../tests/sanity/src/handoff-scenarios.js) |
| handoff | `handoffs-05` | B adds note then reassigns to C; DB history has one entry and resets acknowledgement; C can acknowledge. | Backend | [handoff-scenarios.js](../../tests/sanity/src/handoff-scenarios.js) |
| media-sharing | `media-01` | Upload PNG, download exact bytes, delete, subsequent retrieval 404. | Backend | [media-scenarios.js](../../tests/sanity/src/media-scenarios.js) |
| handoff, media-sharing | `media-02` | Upload PDF, compare downloaded bytes; create handoff attachment and reread filename/MIME. | Backend | [media-scenarios.js](../../tests/sanity/src/media-scenarios.js) |
| media-sharing | `media-03` | Send inert image/ECG/document URL metadata; GET same URL/filename; final document sidebar label matches. No provider retrieval proof. | Backend | [media-scenarios.js](../../tests/sanity/src/media-scenarios.js) |
| notifications | `notifications-01` | Send ordinary message to non-viewing B; poll inbox/count, reference metadata and personal socket event. | Backend | [notification-scenarios.js](../../tests/sanity/src/notification-scenarios.js) |
| notifications | `notifications-02` | Mention B then emergency message; persisted type/priority match mention/emergency. | Backend | [notification-scenarios.js](../../tests/sanity/src/notification-scenarios.js) |
| notifications | `notifications-03` | Mark one read/unread, channel read, all read, delete; lists/counts match changes. | Backend | [notification-scenarios.js](../../tests/sanity/src/notification-scenarios.js) |
| realtime | `realtime-and-availability-01` | Authenticate two sockets, join, REST send, receive; disconnect/reconnect/rejoin. No second-message assertion exists in this retained case. | Backend | [realtime-availability-scenarios.js](../../tests/sanity/src/realtime-availability-scenarios.js) |
| realtime | `realtime-and-availability-02` | Start/stop typing; peer receives channel/user IDs. | Backend | [realtime-availability-scenarios.js](../../tests/sanity/src/realtime-availability-scenarios.js) |
| profile, realtime | `realtime-and-availability-03` | REST/socket availability, room sync, final disconnect; assert stored state, broadcasts and offline presence. | Backend | [realtime-availability-scenarios.js](../../tests/sanity/src/realtime-availability-scenarios.js) |
| contact-discovery | `search-01` | Known-user name query and phone lookup return intended colleague. | Backend | [search-scenarios.js](../../tests/sanity/src/search-scenarios.js) |
| search | `search-02` | Global marker search finds message/doctor/channel/attachment/handoff; nonmatching marker returns empty arrays. | Backend | [search-scenarios.js](../../tests/sanity/src/search-scenarios.js) |
| support-and-ops | `support-01` | Submit bug, inspect ticket ID/author/type/title/description; missing title fails. | Backend | [support-scenarios.js](../../tests/sanity/src/support-scenarios.js) |
| offline-recovery | `startup-01` | GET health; connected test DB and disabled Firebase/Cloudinary reported. | Backend | [live-runner.js](../../tests/sanity/src/live-runner.js) |
| authentication | `FR-AUTH-01` | OTP format boundaries: missing phone, no plus, 6/7/15/16 digits; code missing, 5/6/7 digits and letters | Backend | [auth.mjs](../../tests/functional-regression/suites/auth.mjs) |
| authentication | `FR-AUTH-02` | Resend before consumption; verify old code then latest | Backend | [auth.mjs](../../tests/functional-regression/suites/auth.mjs) |
| authentication, access-and-privacy | `FR-AUTH-03` | Seed expiry just before/after controlled now; verify correct code; resend after expiry | Backend | [auth.mjs](../../tests/functional-regression/suites/auth.mjs) |
| authentication, access-and-privacy | `FR-AUTH-04` | Two wrong attempts then correct third; separate OTP three wrong then correct fourth; resend | Backend | [auth.mjs](../../tests/functional-regression/suites/auth.mjs) |
| authentication | `FR-AUTH-05` | Fake SMS provider timeout/rejection then success; request again and verify | Backend | [auth.mjs](../../tests/functional-regression/suites/auth.mjs) |
| authentication, access-and-privacy | `FR-AUTH-06` | Fake opaque widget accepted token with verified phone, rejected token, phone mismatch and explicit provider failure response | Backend | [auth.mjs](../../tests/functional-regression/suites/auth.mjs) |
| authentication | `FR-AUTH-07` | Expired refresh then newly logged-in refresh; access protected me | Backend | [auth.mjs](../../tests/functional-regression/suites/auth.mjs) |
| authentication, profile | `FR-PRO-01` | Save name+role for new user, read me, access spaces, relogin | Backend | [profile.mjs](../../tests/functional-regression/suites/profile.mjs) |
| profile | `FR-PRO-02` | Update name at 2/100/101, bio 300/301, institution 200/201, pgYear 1/6/0/7, invalid role | Backend | [profile.mjs](../../tests/functional-regression/suites/profile.mjs) |
| profile, notifications | `FR-PRO-03` | Set mentions=false; separately set handoffs=false; GET and relogin | Backend | [profile.mjs](../../tests/functional-regression/suites/profile.mjs) |
| profile | `FR-PRO-04` | Change title/speciality/avatar/bio; set username, reject a duplicate, remove avatar; reload peer views | Backend | [profile.mjs](../../tests/functional-regression/suites/profile.mjs) |
| profile | `FR-PRO-05` | Edit profile widget, cancel once; submit once with API error then success | Flutter | [profile_edit_test.dart](../../medcollab-app/test/functional_regression/profile_edit_test.dart) |
| contact-discovery, access-and-privacy | `FR-DISC-01` | Lookup self, shared-space colleague, strangers and accepted peer by phone and relationship API | Backend | [discovery.mjs](../../tests/functional-regression/suites/discovery.mjs) |
| contact-discovery, access-and-privacy | `FR-DISC-02` | Lookup absent/malformed/normalized phones; match a synthetic address book with duplicates and inactive entries | Backend | [discovery.mjs](../../tests/functional-regression/suites/discovery.mjs) |
| contact-discovery, search | `FR-DISC-03` | Search name/username/speciality/institution; test short, mixed-case and literal queries, full/partial numbers and space filtering | Backend | [discovery.mjs](../../tests/functional-regression/suites/discovery.mjs) |
| contact-discovery, search, access-and-privacy | `FR-DISC-04` | Search with 26 eligible users plus inactive/unonboarded fixtures | Backend | [discovery.mjs](../../tests/functional-regression/suites/discovery.mjs) |
| workspaces | `FR-SPC-01` | Create name 2/100/101, description 300/301, invalid type; read valid detail | Backend | [spaces.mjs](../../tests/functional-regression/suites/spaces.mjs) |
| workspaces | `FR-SPC-02` | Preview/join lowercase invite; rotate; repeat preview for member | Backend | [spaces.mjs](../../tests/functional-regression/suites/spaces.mjs) |
| workspaces | `FR-SPC-03` | Set requireApproval; B joins twice; inspect requests and UI response | Backend | [spaces.mjs](../../tests/functional-regression/suites/spaces.mjs) |
| workspaces, access-and-privacy | `FR-SPC-04` | Owner/admin update settings; member tries rename/remove/add; admin adds opted-in doctor | Backend | [spaces.mjs](../../tests/functional-regression/suites/spaces.mjs) |
| profile, workspaces, realtime | `FR-SPC-05` | Set availability for members in distinct priority ranks; GET members | Backend | [spaces.mjs](../../tests/functional-regression/suites/spaces.mjs) |
| workspaces, realtime, access-and-privacy | `FR-SPC-06` | B leaves/removal while online; reload spaces/search, sync rooms, reconnect | Backend | [spaces.mjs](../../tests/functional-regression/suites/spaces.mjs) |
| group-messaging, workspaces | `FR-CH-01` | Create channel name 1/80/81 and uppercase/space, description 200/201; GET list | Backend | [channels.mjs](../../tests/functional-regression/suites/channels.mjs) |
| group-messaging, workspaces, access-and-privacy | `FR-CH-02` | Read S/detail/channel lists as A and B with public X/private Y | Backend | [channels.mjs](../../tests/functional-regression/suites/channels.mjs) |
| group-messaging, workspaces, access-and-privacy | `FR-CH-03` | Set onlyAdminsCanPost; B sends then A sends; clear setting and B sends | Backend | [channels.mjs](../../tests/functional-regression/suites/channels.mjs) |
| group-messaging, workspaces | `FR-CH-04` | Update custom description/name; reload; try rename/archive each default | Backend | [channels.mjs](../../tests/functional-regression/suites/channels.mjs) |
| group-messaging, workspaces, access-and-privacy | `FR-CH-05` | Archive X containing root/pin; reload lists/search then try send | Backend | [channels.mjs](../../tests/functional-regression/suites/channels.mjs) |
| direct-messaging | `FR-REQ-01` | A requests D with default settings; D requests A before accepting; read both views | Backend | [requests.mjs](../../tests/functional-regression/suites/requests.mjs) |
| direct-messaging, access-and-privacy | `FR-REQ-02` | Try self, missing target, already accepted peer and blocked pair | Backend | [requests.mjs](../../tests/functional-regression/suites/requests.mjs) |
| direct-messaging | `FR-REQ-03` | Intro lengths 0/280/281; list sent/received/all, pending/accepted/declined | Backend | [requests.mjs](../../tests/functional-regression/suites/requests.mjs) |
| direct-messaging | `FR-REQ-04` | Recipient accepts/declines; repeat accept and opposite terminal action | Backend | [requests.mjs](../../tests/functional-regression/suites/requests.mjs) |
| direct-messaging | `FR-REQ-05` | Interrupt accept after request state write via DB fault; reload request and DM; retry | Backend | [requests.mjs](../../tests/functional-regression/suites/requests.mjs) |
| contact-discovery, direct-messaging | `FR-REQ-06` | Flutter lookup yields sent/received/accepted states; tap supported CTA; inject request error | Flutter | [message_request_lookup_test.dart](../../medcollab-app/test/functional_regression/message_request_lookup_test.dart) |
| direct-messaging, group-messaging, needl, access-and-privacy | `FR-DM-01` | Create/reopen group through both aliases; exercise legacy one-to-one DM and attempt to add a pending stranger | Backend | [conversations.mjs](../../tests/functional-regression/suites/conversations.mjs) |
| direct-messaging, group-messaging, needl | `FR-DM-02` | Create with 8 then 9 distinct other users | Backend | [conversations.mjs](../../tests/functional-regression/suites/conversations.mjs) |
| direct-messaging, group-messaging, needl | `FR-DM-03` | Rename to whitespace, 80 and 81 chars; GET from both members | Backend | [conversations.mjs](../../tests/functional-regression/suites/conversations.mjs) |
| direct-messaging | `FR-DM-04` | Send in two DMs in known sequence; GET list as each user | Backend | [conversations.mjs](../../tests/functional-regression/suites/conversations.mjs) |
| direct-messaging, group-messaging, needl | `FR-DM-05` | Expand today with messages before/at/after the supplied phone-local midnight | Backend | [conversations.mjs](../../tests/functional-regression/suites/conversations.mjs) |
| direct-messaging, group-messaging, needl | `FR-DM-06` | Expand all with 501 roots plus legacy soft-deleted record; inspect destination IDs/preview | Backend | [conversations.mjs](../../tests/functional-regression/suites/conversations.mjs) |
| direct-messaging, group-messaging, needl | `FR-DM-07` | Expand with root+thread+quote; open copied thread and quote target | Backend | [conversations.mjs](../../tests/functional-regression/suites/conversations.mjs) |
| direct-messaging, group-messaging, needl | `FR-DM-08` | Expand to membership already existing; repeat and compare counts | Backend | [conversations.mjs](../../tests/functional-regression/suites/conversations.mjs) |
| direct-messaging, group-messaging, needl | `FR-DM-09` | Concurrent pair/group reopen requests; inspect exact-membership records | Backend | [conversations.mjs](../../tests/functional-regression/suites/conversations.mjs) |
| message-actions | `FR-MSG-01` | Send missing/nonstring/whitespace text, 4000/4001 trimmed chars; valid Unicode/newlines | Backend | [messages.mjs](../../tests/functional-regression/suites/messages.mjs) |
| message-actions | `FR-MSG-02` | Page roots with 0/1/100/101 limit, malformed before, empty and exact full final page | Backend | [messages.mjs](../../tests/functional-regression/suites/messages.mjs) |
| message-actions, media-sharing | `FR-MSG-03` | Quote text >120 chars and image/document; read snapshot after reload | Backend | [messages.mjs](../../tests/functional-regression/suites/messages.mjs) |
| message-actions | `FR-MSG-04` | Edit text twice; attempt image edit; reload and observe event | Backend | [messages.mjs](../../tests/functional-regression/suites/messages.mjs) |
| group-messaging, message-actions, access-and-privacy | `FR-MSG-05` | Edit/delete newest message; delete for self and clear chat; reload preview, quote, search, timeline and thread for both viewers | Backend | [messages.mjs](../../tests/functional-regression/suites/messages.mjs) |
| group-messaging, message-actions, access-and-privacy | `FR-MSG-06` | Delete older messages as sender and space admin; exercise legacy DELETE, deny other sender and observe personal-room events | Backend | [messages.mjs](../../tests/functional-regression/suites/messages.mjs) |
| group-messaging, message-actions | `FR-MSG-07` | Send urgent in general and normal in emergency; reload message/notification | Backend | [messages.mjs](../../tests/functional-regression/suites/messages.mjs) |
| message-actions, offline-recovery | `FR-MSG-08` | Commit send then drop response at proxy; reopen chat before manual resend | Backend | [messages.mjs](../../tests/functional-regression/suites/messages.mjs) |
| needl, message-actions | `FR-THR-01` | A/B reply to one root; attempt replies to activity and nested replies; reload root/thread/Needl | Backend | [threads.mjs](../../tests/functional-regression/suites/threads.mjs) |
| message-actions | `FR-THR-02` | Three replies, limit=2 then before oldest returned; include deleted reply | Backend | [threads.mjs](../../tests/functional-regression/suites/threads.mjs) |
| needl, message-actions | `FR-THR-03` | Seed 41 active roots with distinct updatedAt; GET Needl, archive one channel | Backend | [threads.mjs](../../tests/functional-regression/suites/threads.mjs) |
| needl, message-actions | `FR-THR-04` | Edit and permanently delete the only reply; reload root/thread and Needl | Backend | [threads.mjs](../../tests/functional-regression/suites/threads.mjs) |
| message-actions, realtime | `FR-THR-05` | Deliver same reply socket twice and then HTTP page in Flutter thread/root views | Flutter | [chat_reconciliation_test.dart](../../medcollab-app/test/functional_regression/chat_reconciliation_test.dart) |
| message-actions | `FR-SOC-01` | A and B toggle same emoji; A removes; B uses another; reread/events | Backend | [social.mjs](../../tests/functional-regression/suites/social.mjs) |
| message-actions | `FR-SOC-02` | Submit invalid/empty emoji, then react to a permanently deleted message | Backend | [social.mjs](../../tests/functional-regression/suites/social.mjs) |
| message-actions | `FR-SOC-03` | Pin five distinct; sixth rejected; unpin one then pin sixth; reload detail | Backend | [social.mjs](../../tests/functional-regression/suites/social.mjs) |
| message-actions | `FR-SOC-04` | Re-pin same ID below cap and at cap; unpin absent ID | Backend | [social.mjs](../../tests/functional-regression/suites/social.mjs) |
| direct-messaging, group-messaging, message-actions | `FR-SOC-05` | B/C mark separate group-DM messages/read batches twice; opt out B for new record | Backend | [social.mjs](../../tests/functional-regression/suites/social.mjs) |
| message-actions | `FR-SOC-06` | Render pending/failed/sent/read messages and preference-disabled footer | Flutter | [social_receipts_test.dart](../../medcollab-app/test/functional_regression/social_receipts_test.dart) |
| handoff | `FR-HOF-01` | Draft two patients; replace/edit/remove one with explicit IDs; change date/shift and reload | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff | `FR-HOF-02` | Missing bed/alias, bed 20/21, alias 100/101, notes 2000/2001, summary 2000/2001, invalid status/date/shift | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff | `FR-HOF-03` | Submit same populated draft concurrently twice, then acknowledge concurrently twice | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff, notifications, access-and-privacy | `FR-HOF-04` | Check invalid draft transitions and recipient edits; creator edits an acknowledged handoff then withdraws it | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff, access-and-privacy | `FR-HOF-05` | Read draft through received status filter/detail/space/search as B/member/admin | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff | `FR-HOF-06` | List sent/received/all by status, S/S2 and date with records at day boundaries | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff | `FR-HOF-07` | Page space history with out-of-order IDs vs shiftDate; limit=2 | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff | `FR-HOF-08` | Add each note kind after submit, empty/1000/1001 text; reread | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff | `FR-HOF-09` | Reassign acknowledged B→C then C→B; inspect histories/inboxes/events | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff, access-and-privacy | `FR-HOF-10` | Reassign same assignee, nonmember, and draft; note at route limit | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff | `FR-HOF-11` | Flutter draft save succeeds then submit fails; retry submit | Flutter | [handoff_form_test.dart](../../medcollab-app/test/functional_regression/handoff_form_test.dart) |
| handoff | `FR-HOF-12` | Render yesterday/today/tomorrow submitted and acknowledged handoffs around local midnight | Flutter | [handoff_lifecycle_test.dart](../../medcollab-app/test/functional_regression/handoff_lifecycle_test.dart) |
| handoff, media-sharing | `FR-HOF-13` | Patient editor adds/removes tasks and attachment, flags patient, cancel then save | Flutter | [patient_editor_test.dart](../../medcollab-app/test/functional_regression/patient_editor_test.dart) |
| media-sharing | `FR-MED-01` | Upload missing file, supported PNG/PDF/MP4, unsupported TXT/DOC, 25MiB/25MiB+1 file | Backend | [media.mjs](../../tests/functional-regression/suites/media.mjs) |
| media-sharing | `FR-MED-02` | Upload octet-stream named .pdf/.mp4 then inspect returned metadata/open | Backend | [media.mjs](../../tests/functional-regression/suites/media.mjs) |
| media-sharing | `FR-MED-03` | Upload local PNG, send and independently fetch it, then delete for everyone | Backend | [media.mjs](../../tests/functional-regression/suites/media.mjs) |
| voice-messaging, media-sharing | `FR-MED-04` | Upload and send video and synthetic audio; try invalid audio metadata | Backend | [media.mjs](../../tests/functional-regression/suites/media.mjs) |
| media-sharing | `FR-MED-05` | Fake provider image/PDF/video upload responses and failure; inspect requests/output | Backend | [media.mjs](../../tests/functional-regression/suites/media.mjs) |
| media-sharing | `FR-MED-06` | Upload avatar A, save profile URL, replace B; delete A and reload profile | Backend | [media.mjs](../../tests/functional-regression/suites/media.mjs) |
| handoff, media-sharing | `FR-MED-07` | Delete referenced file and handoff-context/video file; reopen consuming view | Backend | [media.mjs](../../tests/functional-regression/suites/media.mjs) |
| media-sharing | `FR-MED-08` | Device pick/cancel image/PDF/video, deny permission then allow; open file via OS | Android (local) | [media_test.dart](../../medcollab-app/integration_test/functional_regression/media_test.dart) |
| notifications | `FR-NOT-01` | B joins viewed channel; A sends ordinary then emergency; B leaves and A sends ordinary | Backend | [notifications.mjs](../../tests/functional-regression/suites/notifications.mjs) |
| notifications | `FR-NOT-02` | Mention B and self while B viewing/not viewing; inspect records | Backend | [notifications.mjs](../../tests/functional-regression/suites/notifications.mjs) |
| notifications | `FR-NOT-03` | Seed read/unread types across 3 pages; query unreadOnly/type/limit/before | Backend | [notifications.mjs](../../tests/functional-regression/suites/notifications.mjs) |
| notifications | `FR-NOT-04` | Channel read with string/ObjectId metadata, unrelated channel, then repeat | Backend | [notifications.mjs](../../tests/functional-regression/suites/notifications.mjs) |
| notifications | `FR-NOT-05` | Inject notification DB failure after successful send, restore; read message and perform new send | Backend | [notifications.mjs](../../tests/functional-regression/suites/notifications.mjs) |
| group-messaging, notifications, realtime | `FR-NOT-06` | Socket notification then HTTP refresh, toggle unread/read and open a grouped chat in Flutter | Flutter | [notifications_test.dart](../../medcollab-app/test/functional_regression/notifications_test.dart) |
| notifications | `FR-PUSH-01` | Register t1–t6, re-register t3, logout t3 | Backend | [push-contracts.mjs](../../tests/functional-regression/suites/push-contracts.mjs) |
| profile, notifications | `FR-PUSH-02` | Disable each mapped preference; emit matching notification with fake push capture | Backend | [push-contracts.mjs](../../tests/functional-regression/suites/push-contracts.mjs) |
| profile, notifications | `FR-PUSH-03` | Controlled time at start/end for same-day/overnight/equal quiet hours, emergency preference on/off | Backend | [push-contracts.mjs](../../tests/functional-regression/suites/push-contracts.mjs) |
| notifications | `FR-PUSH-04` | Fake stale-token error for t1, temporary error t2, success t3 | Backend | [push-contracts.mjs](../../tests/functional-regression/suites/push-contracts.mjs) |
| notifications | `FR-PUSH-05` | Device injected background notification for same channel twice and other channel; tap/reply | Android (local) | [notifications_test.dart](../../medcollab-app/integration_test/functional_regression/notifications_test.dart) |
| authentication, notifications, access-and-privacy | `FR-PUSH-06` | Device deny notifications then grant; token refresh and logout/relogin | Android (local) | [notifications_test.dart](../../medcollab-app/integration_test/functional_regression/notifications_test.dart) |
| realtime | `FR-RT-01` | Connect two devices as A, disconnect first, then last; observe B and DB | Backend | [realtime.mjs](../../tests/functional-regression/suites/realtime.mjs) |
| workspaces, realtime, access-and-privacy | `FR-RT-02` | A joins new S while connected; sync/reconnect; receive space event | Backend | [realtime.mjs](../../tests/functional-regression/suites/realtime.mjs) |
| profile, realtime | `FR-RT-03` | Update availability via REST then socket with note/until; read me and peer payload | Backend | [realtime.mjs](../../tests/functional-regression/suites/realtime.mjs) |
| realtime | `FR-RT-04` | Two clients type/stop; duplicate events; leave/dispose Flutter chat; advance clock | Flutter | [chat_reconciliation_test.dart](../../medcollab-app/test/functional_regression/chat_reconciliation_test.dart) |
| offline-recovery, realtime | `FR-RT-05` | Disconnect B; A sends/edits; reconnect/rejoin and fetch | Flutter | [chat_reconciliation_test.dart](../../medcollab-app/test/functional_regression/chat_reconciliation_test.dart) |
| authentication, offline-recovery, realtime | `FR-RT-06` | Expire stored access token, resume and reconnect; refresh success then failure | Flutter | [resume_reconnect_test.dart](../../medcollab-app/test/functional_regression/resume_reconnect_test.dart) |
| offline-recovery, realtime | `FR-RT-07` | Preserve Socket.IO session/offset, interrupt transport briefly within configured 120 seconds, send while disconnected, reconnect; then type/join/update availability | Backend | [realtime.mjs](../../tests/functional-regression/suites/realtime.mjs) |
| search | `FR-SRCH-01` | Query each type and all, mixed case/whitespace/literal punctuation, q length 1/2 | Backend | [search.mjs](../../tests/functional-regression/suites/search.mjs) |
| search | `FR-SRCH-02` | 51 matching messages/attachments; limit=1/50; archive one channel | Backend | [search.mjs](../../tests/functional-regression/suites/search.mjs) |
| handoff, search | `FR-SRCH-03` | Search alias/ward/bed/diagnosis/notes vs summary in handoff | Backend | [search.mjs](../../tests/functional-regression/suites/search.mjs) |
| search | `FR-SRCH-04` | Flutter type query A then B; return B response before A; empty/error then retry | Flutter | [search_test.dart](../../medcollab-app/test/functional_regression/search_test.dart) |
| support-and-ops | `FR-SUP-01` | Submit feature and feedback; DB inspect each; blank title/description | Backend | [support.mjs](../../tests/functional-regression/suites/support.mjs) |
| support-and-ops | `FR-SUP-02` | Bug/feature lengths title 201, description 5001, steps/context 3001 | Backend | [support.mjs](../../tests/functional-regression/suites/support.mjs) |
| support-and-ops | `FR-SUP-03` | Dev enabled: seed notification/conversation/handoff; no-space then joined user | Backend | [support.mjs](../../tests/functional-regression/suites/support.mjs) |
| support-and-ops | `FR-SUP-04` | Flutter bug/feature/feedback error then success; open help/legal/contact | Flutter | [support_forms_test.dart](../../medcollab-app/test/functional_regression/support_forms_test.dart) |
| authentication, navigation | `FR-NAV-01` | Launch no session, valid incomplete session, valid onboarded session | Flutter | [launch_routing_test.dart](../../medcollab-app/test/functional_regression/launch_routing_test.dart) |
| authentication, navigation | `FR-NAV-02` | HTTP 401 refresh success, failure, repeated 401 and concurrent requests | Flutter | [auth_refresh_test.dart](../../medcollab-app/test/functional_regression/auth_refresh_test.dart) |
| navigation | `FR-NAV-03` | Open a chat from Messages and press system Back twice | Flutter | [tab_history_test.dart](../../medcollab-app/test/functional_regression/tab_history_test.dart) |
| navigation, offline-recovery | `FR-NAV-04` | Device background, offline, foreground, restore network | Android (local) | [lifecycle_test.dart](../../medcollab-app/integration_test/functional_regression/lifecycle_test.dart) |
| authentication, navigation, offline-recovery | `FR-NAV-05` | Device force-stop/relaunch with session then logout and relaunch | Android (local) | [lifecycle_test.dart](../../medcollab-app/integration_test/functional_regression/lifecycle_test.dart) |
| message-actions, offline-recovery | `FR-OFF-01` | Send text; deliver matching socket before HTTP and then reverse order | Flutter | [chat_reconciliation_test.dart](../../medcollab-app/test/functional_regression/chat_reconciliation_test.dart) |
| message-actions, offline-recovery | `FR-OFF-02` | Send transport error; reopen chat; successful subsequent send | Flutter | [chat_reconciliation_test.dart](../../medcollab-app/test/functional_regression/chat_reconciliation_test.dart) |
| offline-recovery, saved-and-shared | `FR-OFF-03` | Save root/thread drafts separately; recreate service; clear one; list draft channels | Flutter | [storage_test.dart](../../medcollab-app/test/functional_regression/storage_test.dart) |
| offline-recovery | `FR-OFF-04` | Cached transcript then offline load, reconnect fetch changed content | Flutter | [chat_reconciliation_test.dart](../../medcollab-app/test/functional_regression/chat_reconciliation_test.dart) |
| media-sharing, offline-recovery | `FR-OFF-05` | Start attachment upload, fail then retry/cancel; double-tap send while busy | Flutter | [chat_reconciliation_test.dart](../../medcollab-app/test/functional_regression/chat_reconciliation_test.dart) |
| offline-recovery, saved-and-shared, access-and-privacy | `FR-OFF-06` | Logout A, login B on same storage, inspect drafts/bookmarks/recent/cache | Flutter | [account_switch_test.dart](../../medcollab-app/test/functional_regression/account_switch_test.dart) |
| saved-and-shared | `FR-SAVE-01` | Save message/thread/handoff bookmarks, re-save same ID, restart service, toggle off | Flutter | [storage_test.dart](../../medcollab-app/test/functional_regression/storage_test.dart) |
| saved-and-shared | `FR-SAVE-02` | Corrupt bookmark JSON and missing target on navigation | Flutter | [bookmark_recovery_test.dart](../../medcollab-app/test/functional_regression/bookmark_recovery_test.dart) |
| saved-and-shared | `FR-SAVE-03` | Visit 9 channels and pin 13 items; revisit/re-pin duplicate; recreate service | Flutter | [storage_test.dart](../../medcollab-app/test/functional_regression/storage_test.dart) |
| navigation | `FR-HOME-01` | Hide/reorder widgets, save/recreate, reset; older/corrupt stored config | Flutter | [home_test.dart](../../medcollab-app/test/functional_regression/home_test.dart) |
| handoff, navigation | `FR-HOME-02` | Submitted assigned handoff, acknowledge/reassign through fake refreshed responses | Flutter | [home_handoffs_test.dart](../../medcollab-app/test/functional_regression/home_handoffs_test.dart) |
| workspaces, navigation | `FR-HOME-03` | Empty dashboard then mixed hospital/department announcements/emergency channels; partial API failure | Flutter | [home_handoffs_test.dart](../../medcollab-app/test/functional_regression/home_handoffs_test.dart) |
| media-sharing, saved-and-shared | `FR-LINK-01` | Forward text and media to chosen existing chat; fake failure then retry | Flutter | [forwarding_test.dart](../../medcollab-app/test/functional_regression/forwarding_test.dart) |
| navigation, saved-and-shared | `FR-LINK-02` | Copy source link, attempt router resolution | Flutter | [forwarding_test.dart](../../medcollab-app/test/functional_regression/forwarding_test.dart) |
| authentication, notifications, navigation, saved-and-shared | `FR-LINK-03` | Push channel/DM/handoff/missing target; rapid taps; logged-out then login | Flutter | [push_routing_test.dart](../../medcollab-app/test/functional_regression/push_routing_test.dart) |
| workspaces, saved-and-shared | `FR-LINK-04` | Device scan invite QR/raw code/link, deny camera, cancel; preview then join | Android (local) | [invites_test.dart](../../medcollab-app/integration_test/functional_regression/invites_test.dart) |
| offline-recovery | `FR-RUN-01` | Persist profile/space/message/handoff; restart backend against same disposable DB; reconnect/read | Backend | [runtime.mjs](../../tests/functional-regression/suites/runtime.mjs) |
| offline-recovery | `FR-RUN-02` | Stop DB during read, restore and request again | Backend | [runtime.mjs](../../tests/functional-regression/suites/runtime.mjs) |
| offline-recovery | `FR-RUN-03` | Flutter fake timeout/5xx/malformed response then success across list and detail | Flutter | [runtime_recovery_test.dart](../../medcollab-app/test/functional_regression/runtime_recovery_test.dart) |
| authentication, group-messaging, handoff, workspaces | `FR-JRN-01` | Register A/B, onboard, A creates S, B joins, exchange text, A submits H, B acknowledges, relogin and reload | Backend | [journeys.mjs](../../tests/functional-regression/suites/journeys.mjs) |
| contact-discovery, direct-messaging, message-actions, access-and-privacy | `FR-JRN-02` | Lookup opted-in D, send request, D accepts, exchange DM, mark read, reopen from both users | Backend | [journeys.mjs](../../tests/functional-regression/suites/journeys.mjs) |
| handoff, notifications | `FR-JRN-03` | Submit H to B; B cant_cover note; reassign C; C acknowledges; A refreshes inbox/history | Backend | [journeys.mjs](../../tests/functional-regression/suites/journeys.mjs) |
| needl, workspaces, search, realtime, access-and-privacy | `FR-JRN-04` | B leaves S, reloads spaces/search/Needl and syncs socket; rejoins current invite | Backend | [journeys.mjs](../../tests/functional-regression/suites/journeys.mjs) |
| authentication, navigation, offline-recovery, realtime | `FR-JRN-05` | Device compose draft, background/offline, resume, send when online, receive peer reply, logout/relogin | Android (local) | [journeys_test.dart](../../medcollab-app/integration_test/functional_regression/journeys_test.dart) |
| authentication, handoff, notifications, navigation | `FR-JRN-06` | Device receive injected handoff notification cold-start; login if needed; open, acknowledge, inspect sender | Android (local) | [journeys_test.dart](../../medcollab-app/integration_test/functional_regression/journeys_test.dart) |
| needl | `FR-NDL-01` | Create separate Needls with overlapping member sets | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-02` | Reject malformed group creation on both route aliases | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-03` | Reject nonexistent participant without partial Needl | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, access-and-privacy | `FR-NDL-04` | Respect unrelated colleague request opt-out | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, access-and-privacy | `FR-NDL-05` | List Needls for every member and exclude outsiders | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, access-and-privacy | `FR-NDL-06` | Deny outsider detail and members access | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, access-and-privacy | `FR-NDL-07` | Deny outsider rename without changing name | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-08` | Ignore membership and identity mass assignment on rename | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, access-and-privacy | `FR-NDL-09` | Project group members without private credential fields | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, access-and-privacy | `FR-NDL-10` | Verify archived Needl read-only behavior and record expansion policy | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-11` | Validate expansion payload before writes | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-12` | Reject missing or space-channel expansion source | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, access-and-privacy | `FR-NDL-13` | Deny outsider expansion of a private Needl | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-14` | Reject additions containing only existing participants | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, access-and-privacy | `FR-NDL-15` | Reject nonexistent or ineligible new participant atomically | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-16` | Normalize mixed existing and duplicate new participants | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-17` | Enforce expansion nine-person boundary | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-18` | Omitted history creates a fresh conversation | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-19` | Copy today using explicit phone-local midnight | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-20` | Handle today with no qualifying messages | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, media-sharing | `FR-NDL-21` | Copy heterogeneous history and deletion state | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| group-messaging, needl, realtime | `FR-NDL-22` | Deliver Needl messages to all participants | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| group-messaging, needl, notifications, realtime, access-and-privacy | `FR-NDL-23` | Keep expanded conversation traffic out of original and outsider audiences | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, access-and-privacy | `FR-NDL-24` | Require authentication for all Needl endpoints | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, message-actions | `FR-NDL-25` | Edit and delete Needl messages with independent reload | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| group-messaging, needl, message-actions, access-and-privacy | `FR-NDL-26` | Persist group pins and per-member receipts | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, offline-recovery | `FR-NDL-27` | Restore Needl identity after backend restart | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl | `FR-NDL-28` | Converge concurrent expansion on one destination | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| needl, offline-recovery | `FR-NDL-29` | Recover history copy after a database write failure | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| direct-messaging, needl, access-and-privacy | `FR-NDL-30` | Keep group participation distinct from accepted pair consent | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| direct-messaging, needl | `FR-NDL-31` | Classify and label Needls consistently | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl | `FR-NDL-32` | Create group through real client repository | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl | `FR-NDL-33` | Use legacy creation alias only for not-found | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl | `FR-NDL-34` | Serialize all history modes and device midnight | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl | `FR-NDL-35` | Parse list detail member and rename contracts | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| direct-messaging, needl, navigation | `FR-NDL-36` | Separate Needl tab from Direct and space channels | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl, navigation | `FR-NDL-37` | Show Needl empty and error states with recovery | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| contact-discovery, needl | `FR-NDL-38` | Preload only distinct Vocle colleague suggestions | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| contact-discovery, needl, search | `FR-NDL-39` | Debounce name search and discard stale responses | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| contact-discovery, needl, search | `FR-NDL-40` | Distinguish search failure and restore suggestions | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| direct-messaging, needl, navigation | `FR-NDL-41` | Create Needl from exact selected colleagues | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl | `FR-NDL-42` | Retain selected colleagues after create failure | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl | `FR-NDL-43` | Create multiple Needls without selection leakage | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| contact-discovery, needl | `FR-NDL-44` | Preload add-people suggestions safely | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| contact-discovery, needl, search | `FR-NDL-45` | Discard stale add-people search responses | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| contact-discovery, needl, search | `FR-NDL-46` | Normalize add-people phone lookup and filter forbidden selections | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| contact-discovery, needl, search | `FR-NDL-47` | Expose add-people search failures and recover | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl | `FR-NDL-48` | Maintain selected chips across queries | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl | `FR-NDL-49` | Select history options and cancel safely | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl, navigation | `FR-NDL-50` | Recover add-people submission and block double taps | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl | `FR-NDL-51` | Cancel or save rename with bounded trimmed input | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl | `FR-NDL-52` | Show rename error without claiming success | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| needl | `FR-NDL-53` | Display Needl members in stable self-first order | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| group-messaging, needl, message-actions | `FR-NDL-54` | Render group chat identity and group-only menu | Flutter | [needl_test.dart](../../medcollab-app/test/functional_regression/needl_test.dart) |
| group-messaging, needl, realtime, access-and-privacy | `FR-NDL-55` | Subscribe as the three original Needl members, add a fourth with history, then reload both conversations | Backend | [needl.mjs](../../tests/functional-regression/suites/needl.mjs) |
| voice-messaging, handoff, support-and-ops, access-and-privacy | `FR-ADM-01` | Compare ops voice metrics before and after synthetic message and handoff records | Backend | [admin.mjs](../../tests/functional-regression/suites/admin.mjs) |
| support-and-ops, access-and-privacy | `FR-ADM-02` | Compare ops overview and feedback after adding active and archived conversation fixtures, availability and an open ticket | Backend | [admin.mjs](../../tests/functional-regression/suites/admin.mjs) |
| authentication, voice-assistant, access-and-privacy | `FR-AST-01` | Try assistant routes before onboarding, then interpret a synthetic command and the exact length boundary with no provider configured | Backend | [assistant.mjs](../../tests/functional-regression/suites/assistant.mjs) |
| direct-messaging, voice-messaging, media-sharing, realtime | `FR-VCE-01` | Record peer typing then send and transcribe audio in a consented DM | Backend | [voice.mjs](../../tests/functional-regression/suites/voice.mjs) |
| voice-messaging, needl, search, access-and-privacy | `FR-VCE-02` | Find a Needl transcript after it is written and hide the clip for one member | Backend | [voice.mjs](../../tests/functional-regression/suites/voice.mjs) |
| authentication, direct-messaging, voice-messaging, offline-recovery, access-and-privacy | `FR-VCE-03` | Expire the clip sender token and try unauthorized and invalid transcript edits | Backend | [voice.mjs](../../tests/functional-regression/suites/voice.mjs) |
| voice-messaging | `FR-VCE-04` | Load the voice view from mixed chat history | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| voice-messaging | `FR-VCE-05` | Send a recording and attach the on-device transcript to the server ID | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| voice-messaging | `FR-VCE-06` | Send voice when speech recognition returns no text | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| voice-messaging, offline-recovery | `FR-VCE-07` | Reject a voice send after the upload | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| voice-messaging, needl, realtime | `FR-VCE-08` | Receive recording and transcript updates for a voice peer | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| voice-messaging, needl, realtime | `FR-VCE-09` | Autoplay two incoming clips, then record and disable autoplay | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| voice-messaging, media-sharing, offline-recovery | `FR-VCE-10` | Fail a voice upload, then record again | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| voice-messaging, needl | `FR-VCE-11` | Pause and resume a clip with another clip queued | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| voice-messaging, needl, offline-recovery, realtime | `FR-VCE-12` | Receive a live clip and transcript before old history returns | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| voice-messaging, navigation | `FR-VCE-13` | Leave the voice view while recording | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| direct-messaging, voice-messaging, navigation | `FR-VCE-14` | Deny microphone permission, slide to discard, then hold and send in a DM | Android (local) | [voice_test.dart](../../medcollab-app/integration_test/functional_regression/voice_test.dart) |
| voice-messaging, needl, realtime | `FR-VCE-15` | Receive another clip while voice playback is paused | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| voice-messaging, needl, offline-recovery | `FR-VCE-16` | Fail an audio load with another incoming clip queued | Flutter | [needl_voice_cubit_test.dart](../../medcollab-app/test/functional_regression/needl_voice_cubit_test.dart) |
| handoff, handoff-voice, media-sharing, realtime, access-and-privacy | `FR-HOF-14` | Submit a handoff with uploaded shift and patient audio | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff, handoff-voice, media-sharing | `FR-HOF-15` | Reject invalid handoff audio, then replace and remove the patient note | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff, handoff-voice, realtime | `FR-HOF-16` | Race two audio edits on an acknowledged handoff and recover the stale edit | Backend | [handoffs.mjs](../../tests/functional-regression/suites/handoffs.mjs) |
| handoff, handoff-voice | `FR-HOF-17` | Save and remove shift audio in a versioned form | Flutter | [handoff_voice_test.dart](../../medcollab-app/test/functional_regression/handoff_voice_test.dart) |
| handoff, handoff-voice, offline-recovery | `FR-HOF-18` | Reload the latest shift audio after a form edit conflict | Flutter | [handoff_voice_test.dart](../../medcollab-app/test/functional_regression/handoff_voice_test.dart) |
| handoff, handoff-voice | `FR-HOF-19` | Save while a voice upload is pending | Flutter | [handoff_voice_test.dart](../../medcollab-app/test/functional_regression/handoff_voice_test.dart) |
| handoff, handoff-voice | `FR-HOF-20` | Record and upload in the handoff voice field, then keep or remove | Flutter | [handoff_voice_test.dart](../../medcollab-app/test/functional_regression/handoff_voice_test.dart) |
| handoff, handoff-voice | `FR-HOF-21` | Stop a short recording and deny microphone access in the handoff field | Flutter | [handoff_voice_test.dart](../../medcollab-app/test/functional_regression/handoff_voice_test.dart) |
| handoff, handoff-voice | `FR-HOF-22` | Decode and clear handoff voice notes | Flutter | [handoff_voice_test.dart](../../medcollab-app/test/functional_regression/handoff_voice_test.dart) |
| handoff, handoff-voice, media-sharing, offline-recovery | `FR-HOF-23` | Fail to upload a replacement patient recording, then record again | Flutter | [handoff_voice_test.dart](../../medcollab-app/test/functional_regression/handoff_voice_test.dart) |
| handoff, handoff-voice | `FR-HOF-24` | Record and save a shift note and patient note on an existing handoff | Android (local) | [voice_test.dart](../../medcollab-app/integration_test/functional_regression/voice_test.dart) |
| authentication, voice-assistant, access-and-privacy | `FR-AST-02` | Interpret a command against a loopback provider with rate-limit, outage and success responses | Backend | [assistant.mjs](../../tests/functional-regression/suites/assistant.mjs) |
| voice-assistant | `FR-AST-03` | Turn streamed speech into an edited confirmation and execute once | Flutter | [voice_bot_cubit_test.dart](../../medcollab-app/test/functional_regression/voice_bot_cubit_test.dart) |
| voice-assistant | `FR-AST-04` | Disambiguate same-name doctors before sending | Flutter | [voice_bot_cubit_test.dart](../../medcollab-app/test/functional_regression/voice_bot_cubit_test.dart) |
| voice-assistant | `FR-AST-05` | Use AI for an unrecognized command only | Flutter | [voice_bot_cubit_test.dart](../../medcollab-app/test/functional_regression/voice_bot_cubit_test.dart) |
| voice-assistant | `FR-AST-06` | Submit a command unsupported by the local parser without AI | Flutter | [voice_bot_cubit_test.dart](../../medcollab-app/test/functional_regression/voice_bot_cubit_test.dart) |
| voice-assistant | `FR-AST-07` | Report denied speech permission | Flutter | [voice_bot_cubit_test.dart](../../medcollab-app/test/functional_regression/voice_bot_cubit_test.dart) |
| voice-assistant | `FR-AST-08` | Type a request while the recognizer is listening | Flutter | [voice_bot_cubit_test.dart](../../medcollab-app/test/functional_regression/voice_bot_cubit_test.dart) |
| voice-assistant | `FR-AST-09` | Report a missing speech language pack | Flutter | [voice_bot_cubit_test.dart](../../medcollab-app/test/functional_regression/voice_bot_cubit_test.dart) |
| voice-assistant | `FR-AST-10` | Dismiss a proposed action | Flutter | [voice_bot_cubit_test.dart](../../medcollab-app/test/functional_regression/voice_bot_cubit_test.dart) |
| voice-assistant | `FR-AST-11` | Parse voice message phrases with varied names and punctuation | Flutter | [voice_command_parser_test.dart](../../medcollab-app/test/functional_regression/voice_command_parser_test.dart) |
| direct-messaging, voice-assistant, needl | `FR-AST-12` | Say a person's name that also appears in a Needl name | Flutter | [voice_command_parser_test.dart](../../medcollab-app/test/functional_regression/voice_command_parser_test.dart) |
| voice-assistant, needl | `FR-AST-13` | Speak multiple names to identify an existing Needl | Flutter | [voice_command_parser_test.dart](../../medcollab-app/test/functional_regression/voice_command_parser_test.dart) |
| voice-assistant | `FR-AST-14` | Ask a same-name doctor to act | Flutter | [voice_command_parser_test.dart](../../medcollab-app/test/functional_regression/voice_command_parser_test.dart) |
| voice-assistant | `FR-AST-15` | Use speciality to distinguish two doctors with the same name | Flutter | [voice_command_parser_test.dart](../../medcollab-app/test/functional_regression/voice_command_parser_test.dart) |
| voice-assistant | `FR-AST-16` | Name a doctor absent from the available directory | Flutter | [voice_command_parser_test.dart](../../medcollab-app/test/functional_regression/voice_command_parser_test.dart) |
| voice-assistant, handoff, handoff-voice | `FR-AST-17` | Parse a patient handoff command with multiple bed numbers | Flutter | [voice_command_parser_test.dart](../../medcollab-app/test/functional_regression/voice_command_parser_test.dart) |
| voice-assistant, handoff, handoff-voice | `FR-AST-18` | Try to hand off a patient to a chat | Flutter | [voice_command_parser_test.dart](../../medcollab-app/test/functional_regression/voice_command_parser_test.dart) |
| voice-assistant, navigation | `FR-AST-19` | Parse navigation, alert, availability and search commands | Flutter | [voice_command_parser_test.dart](../../medcollab-app/test/functional_regression/voice_command_parser_test.dart) |
| voice-assistant | `FR-AST-20` | Parse a free-form question and empty input | Flutter | [voice_command_parser_test.dart](../../medcollab-app/test/functional_regression/voice_command_parser_test.dart) |
| voice-assistant | `FR-AST-21` | Decode server assistant proposal types | Flutter | [voice_command_parser_test.dart](../../medcollab-app/test/functional_regression/voice_command_parser_test.dart) |
| voice-assistant, handoff, handoff-voice, offline-recovery | `FR-AST-22` | Fail a configured provider call and recover with a local command | Flutter | [voice_bot_cubit_test.dart](../../medcollab-app/test/functional_regression/voice_bot_cubit_test.dart) |
| direct-messaging, voice-assistant, needl, access-and-privacy | `FR-AST-23` | Confirm actions for an unconsented DM, a consented DM and a Needl | Flutter | [voice_action_executor_test.dart](../../medcollab-app/test/functional_regression/voice_action_executor_test.dart) |
| voice-assistant, handoff, handoff-voice, navigation, access-and-privacy | `FR-AST-24` | Confirm a voice handoff with and without a shared group | Flutter | [voice_action_executor_test.dart](../../medcollab-app/test/functional_regression/voice_action_executor_test.dart) |
| direct-messaging, voice-assistant | `FR-AST-25` | Tap confirm again while a bot message write is pending | Flutter | [voice_bot_cubit_test.dart](../../medcollab-app/test/functional_regression/voice_bot_cubit_test.dart) |
| voice-assistant | `FR-AST-26` | Inject final chat commands with varied wording, casing and recognition-like name variants | Flutter | [voice_action_executor_test.dart](../../medcollab-app/test/functional_regression/voice_action_executor_test.dart) |
| voice-assistant | `FR-AST-27` | Inject unknown and ambiguous chat names, cancel one proposal and confirm another | Flutter | [voice_action_executor_test.dart](../../medcollab-app/test/functional_regression/voice_action_executor_test.dart) |
| voice-assistant | `FR-AST-28` | Inject incomplete commands, cancel an active session, then observe timeout and duplicate finals | Flutter | [voice_action_executor_test.dart](../../medcollab-app/test/functional_regression/voice_action_executor_test.dart) |
| voice-assistant | `FR-AST-29` | Inject search, tab, status and read-all commands | Flutter | [voice_action_executor_test.dart](../../medcollab-app/test/functional_regression/voice_action_executor_test.dart) |
| voice-assistant | `FR-AST-30` | Confirm chat with an expired session, then denied consent, then an authorized session | Flutter | [voice_action_executor_test.dart](../../medcollab-app/test/functional_regression/voice_action_executor_test.dart) |
| voice-assistant-live-audio | `FR-AST-31` | Replay Bala chat variants into the Android virtual microphone from Home | Android (local) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
| voice-assistant-live-audio | `FR-AST-32` | Replay Priya handoff commands into the Android virtual microphone from Home | Android (local) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
| voice-assistant-live-audio | `FR-AST-33` | Replay unknown, ambiguous and incomplete speech commands from Home | Android (local) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
| voice-assistant-prerecorded | `FR-AST-34` | Recognize a prerecorded WAV through Android digital file input and confirm the resulting chat proposal | Android (hosted and local) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
| voice-assistant | `FR-AST-35` | Inject final speech events on Android Home and confirm Bala's chat and Priya's handoff | Android (local) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
| voice-assistant-prerecorded | `FR-AST-36` | Recognize digital chat WAVs for distinct people, similar names, an existing Needl and a space channel | Android (hosted) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
| voice-assistant-prerecorded | `FR-AST-37` | Recognize digital handoff WAVs with and without bed details | Android (hosted) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
| voice-assistant-prerecorded | `FR-AST-38` | Recognize digital audio with missing, unknown, ambiguous, denied or cancelled commands and silence | Android (hosted) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
| voice-assistant-prerecorded | `FR-AST-39` | Recognize digital navigation and Search commands | Android (hosted) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
| voice-assistant-prerecorded | `FR-AST-40` | Recognize digital message, availability and alert commands | Android (hosted) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
| voice-assistant-noise | `FR-AST-41` | Characterize repeated clean and controlled-noise speech on the hosted Android recognizer | Android (hosted) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
| voice-assistant-noise | `FR-AST-42` | Observe recognition under competing speech, background-only input, silence and ambiguous or incomplete commands | Android (hosted) | [voice_assistant_test.dart](../../medcollab-app/integration_test/functional_regression/voice_assistant_test.dart) |
