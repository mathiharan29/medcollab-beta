# Fix & enhancement checklist — from 2026-11-08

Branch: `fix/e2e-defects-20261108` (from `origin/master` @ `4c01dc2`), merged to `master`.
iOS/local feature work is preserved separately on local branch `wip/ios-support-local-20261108` (`eb696e3`) and is **not** merged.
Policy: where upstream and local both fixed the same issue, upstream wins.

Legend: ✅ done/pass · ⏳ pending · ➖ not applicable

## Verification environment

- Flutter **3.29.3** / Dart 3.7.2 (pinned by `master`: CI, `VOCLE_FUNCTIONAL_REGRESSION_DEVICE_RUNNER.md`, lockfile). Archive SHA-256 verified against Google's release manifest.
- Android emulator `Vocle_Pixel` (Pixel 6, API 35, x86_64), debug APK.
- Local backend = `master` backend + MongoDB Memory Server, `OTP_BYPASS=true` (OTP 123456). Production was not called.
- Machine-only Gradle override in `~/.gradle/gradle.properties` (project file pins an Android Studio JDK + Avast truststore that exist only on the upstream PC). No project build files changed.

## Local E2E defects (docs/E2E_FUNCTIONAL_REPORT.md) vs `origin/master`

| # | Defect | Upstream status | Action | Unit test | Emulator E2E |
|---|---|---|---|---|---|
| 1 | Add-members Invite button not painted | Feature not on master | Stays on iOS/local branch | ➖ | ➖ |
| 2 | Message-request dialog: controller used after dispose | Still present | Dialog owns its controller (`MessageRequestIntroDialog`), both call sites. Replaces local next-frame dispose (still raced exit animation) | ✅ | ✅ Back-dismiss and Send both clean; `POST /api/message-requests 201`, note delivered |
| 3 | Alerts list blank (Accept button in Row) | Inline Accept/Decline not on master | Stays on iOS/local branch | ➖ | ➖ |
| 4 | Accept/Decline buttons persist | Inline actions not on master | Stays on iOS/local branch | ➖ | ➖ |
| 5 | Accept message request → 500 | Fixed upstream (`memberPairKey` upsert) | Keep upstream; drop local `dmKey` | ➖ | ✅ accept 200, `direct` channel; re-accept returns same channel |
| 6 | Edit handoff crash on doctor dropdown | Still present | `handoffDoctorOptions` dedupes by id, selects matching instance | ✅ | ✅ Edit form shows "Dr Req Two"; Save draft `PUT 200`; no assertion |
| 7 | Rejected session stuck on splash | Still present | Swallow logout failure, still emit unauthenticated | ✅ | ✅ `/users/me 401`, `refresh 401`, `logout 401` → phone screen, no exception |
| 8 | OTP emit after handler completed | Upstream already awaits | None | ➖ | ✅ onboarded OTP login → Home, no emit error |

## New requirements

### REQ-1 — Back with Create group popup open (Messages → Groups) ✅

**Reported:** Back while the Create space dialog / Type dropdown is open jumps to Home and leaves the popup on screen.

**Root cause:** `AppNavigationBackHandler.didPopRoute` deliberately bypasses `Navigator` pop on shell tab roots (`/home`, `/messages`, `/handoffs`, `/notifications`) to drive tab history (FR-NAV-03). Dialogs, sheets and dropdown menus are not GoRouter pages, so the handler switched to Home underneath them and consumed back. Affected every popup opened from a tab root.

**Fix:**
- `core/router/popup_route_tracker.dart` — `PopupRouteTracker` observes `PopupRoute`s on the root navigator and every shell branch navigator.
- `AppNavigationBackHandler` — if a popup is open, back calls `maybePop` on its navigator (respects `PopScope`) and stops; tab logic runs only when no popup is open.
- `create_space_dialog.dart` — `StatefulWidget` owning its `TextEditingController` (old code disposed it during the exit animation, which back-dismiss exposes); Create disabled while saving (no double-create).

| Check | Result |
|---|---|
| Widget tests `test/functional_regression/back_closes_popup_test.dart` (5) | ✅ |
| Full suite (82 tests incl. FR-NAV-*) on Flutter 3.29.3 | ✅ all pass |
| `flutter analyze` | ✅ 0 errors; 1 pre-existing warning (`profile_edit_test.dart` unused import) |
| E2E A: New group → Back | ✅ dialog closed, stayed on Messages → Groups |
| E2E B: open Type dropdown → Back → Back (with name typed) | ✅ 1st closes menu only, 2nd closes dialog, stays on Groups |
| E2E C: Create "Ward Five" | ✅ appears in Groups; exactly one `POST /api/spaces 201` |
| E2E D: Back with nothing open | ✅ Messages → Home (unchanged) |
| Logcat Flutter exceptions during A–D | ✅ none |

### REQ 2–12 — received 2026-11-08 (plan)

Sanity findings (docs/SANITY_REPORT_2026-11-08.md) are folded in where they overlap.

| REQ | Summary | App | Backend | Order | Status |
|---|---|---|---|---|---|
| 2 | Chats open at latest message; system messages (added/removed/left/renamed); chat theme/wallpaper; add members with history; fix stale Messages lists (F1) | ✅ | ✅ new `system` message type + events | 1 | ✅ (part 2 on 11-09) |
| 3 | Back from any page/chat → Home (popups still close first); edge-swipe back works | ✅ | — | 2 (with 8) | ✅ (+ exit-arm fix 11-09) |
| 8 | Swipe left/right between main tabs | ✅ | — | 2 (with 3) | ✅ |
| 9 | Handoff patient attachment adds a second paperclip; label invisible (F3) | ✅ | — | 3 | ✅ |
| 7 | Remove profile photo | ✅ | check `avatarUrl: null` | 3 | ✅ |
| 10 | Creator can edit/delete own handoffs (incl. submitted) + discard prompt (F7) | ✅ | ✅ permissions | 4 | ✅ |
| 11 | "Could not start a conversation" for one specific person | ✅ | ✅ DM rules | 5 (with 5) | ✅ (root cause in code; confirm on prod with the doctor's name) |
| 5 | Unique username ↔ Vocle ID; search all users + synced contacts; full contact sync; requests default open (privacy only guards group adds); request→accept→message instant (F2) | ✅ | ✅ schema, search, privacy, realtime | 5 | ✅ |
| 6 | Dark mode consistency (headers, footers, status/nav bar icons) | ✅ | — | 6 | ✅ (all 28 screens checked) |
| 4 | Notification reply/actions like WhatsApp; in-app banner for new messages | ✅ | ✅ FCM payload | 7 | 🟡 app side ✅ · real push needs beta check |
| 12 | Voice notes + WhatsApp-level chat features (emoji, etc.) | ✅ | ✅ audio type/media | 8 (largest) | ✅ (record/play on a real phone in beta) |
| 13 | App slow; every page < 1 s; no glitches; all APIs/functions checked | ✅ | — | ongoing | ✅ every screen ≤ 0.63 s on emulator |

#### REQ 2 — part 1 done: chats open at latest + live Messages lists

- **Reproduced first** on the old build: a chat with images reopened on "Xray view 72–75" with the newest messages below the screen (images load after the jump-to-bottom and push content down). Text-only chats on a fast local network did not reproduce it.
- **Fix:** `channel_chat_page.dart` message list is now `reverse: true` (offset 0 = newest), no `PageStorageKey` (old offsets were restored on reopen). New messages follow you only when you're at the bottom; while reading history the view stays put (anchored on a laid-out row — first attempt using scroll extents over-corrected by ~138 px and was replaced). Pinned-message jump adjusted for the reversed list. Thread page re-pins to the latest reply for a few frames while images lay out.
- **F1 fix:** Messages hub reloads (debounced) on new message / notification / member joined-left socket events, when the Messages tab is shown (tap, back or swipe) and when a chat is closed; lists stay visible during refresh; empty Direct/Groups states are pull-to-refreshable.

| Check | Result |
|---|---|
| Emulator, new build: image-heavy chat first open | ✅ newest ("Text after image 76") at bottom |
| Message arrives while at bottom | ✅ follows ("Live at bottom 77") |
| Message arrives while reading history | ✅ visible rows identical before/after (pixel-equal) |
| Scroll up → leave → 10 new msgs → reopen | ✅ opens at newest |
| Messages → Direct updates live when a DM arrives | ✅ preview + unread 3→4 without refresh |
| Widget tests `chat_opens_at_latest_test.dart` (2) | ✅ — note: they guard the reversed-list implementation; on the old code only the structural assertion failed, so device E2E above is the behavioural proof |
| Full suite | ✅ 84/84; analyzer 0 errors |

Remaining REQ 2: system messages (member added/removed/left), add members with history, chat theme/wallpaper.

#### REQ 3 + REQ 8 — done (app-only)

- **Back (REQ 3):** `AppNavigationBackHandler` rewritten: popup closes first → `BackGuard` (dirty screens may ask "Discard?") → on Home, "Swipe back again to exit" → anywhere else `router.go(Home)`. Sign-in screens unchanged. Supersedes FR-NAV-03 (tab-history back); test rewritten.
- **Swipe (REQ 8):** shell uses `SwipeableShellContainer` (PageView over the branch navigators, kept alive). Inner tab bars (Messages 3, Handoffs 5) swipe first and hand off to the neighbouring main tab at their edge; bottom bar stays in sync; taps still work.

| Check | Result |
|---|---|
| Tests `tab_history_test.dart` (6 new: chat→Home, tab→Home + exit prompt, BackGuard veto/allow, popup-first, swipe + state kept, inner-edge hand-off) | ✅ |
| Full suite | ✅ 89/89; analyzer 0 errors |
| Emulator swipe L: Home → Messages(Direct→Needl→Groups) → Handoffs(5 inner) → Alerts → Profile; swipe R all the way back | ✅ bottom bar follows every step; edges stop |
| Emulator back → Home from: Alerts tab, Profile › Edit profile, DM chat, #general, thread, Search | ✅ (Search: 1st back closes keyboard — standard Android — 2nd goes Home) |
| Back on Home | ✅ "Swipe back again to exit Vocle", app stays open |
| Flutter errors during run | ✅ none |

#### REQ 9 — done: handoff patient attachments (+ sanity F3)

- **Cause:** "Add attachment" was a placeholder — it only appended a fake "Attachment N" paperclip chip (never picked, uploaded or saved); chip labels used a theme style that made text invisible.
- **Fix:** Camera / Photo / Document chooser → upload (`context: handoff`) → chip with the real file name; remove; 5-file cap; Add/Save disabled while uploading; failure message instead of a fake chip. `HandoffPatientModel.attachments` (backend schema already had it) round-trips; patient card shows tappable attachments (opens via `DocumentOpenService`). Strips image_picker's `scaled_` prefix.
- **Verified:** 5 widget/unit tests ✅ · emulator: picked `chest_xray_bed7.png` from the system picker → `POST /api/media/upload 200` → one readable chip "Attachments (1/5)" → handoff `201` + submit `200` → receiving doctor's handoff has the attachment ✅

#### REQ 7 — done: remove profile photo (+ sanity F4)

- Profile photo sheet: **Remove photo** (only when a photo exists) → confirm → `PUT /api/users/me {avatarUrl:null}` (server also deletes the stored image). `UserRepository.removeAvatar()`.
- **F4:** avatar initials now skip titles and use first+last ("Dr Asha Rao" → **AR**), so doctors are distinguishable without photos.
- **Verified:** unit tests (initials, removeAvatar request) ✅ · emulator: sheet shows Remove → dialog → `PUT 200` → avatar "AR"; without a photo the option is hidden; server `avatarUrl` empty ✅

#### REQ 13 — speed (done for app-side causes)

| Cause found | Fix |
|---|---|
| Push setup awaited before first frame; permission dialog interrupted OTP | FCM init deferred to sign-in |
| Access token decrypted from Keystore before **every** request; login waited for 3 sequential encrypted writes | In-memory token cache + serial background write queue; one `readAll` warm-up on cold start |
| After a token refresh every request waited ~0.6 s for the socket to reconnect | Socket reconnect runs alongside the retried request |
| Tabs kept alive by swipe each fetched the same lists (handoffs ×4, spaces ×3, DMs ×2 per sign-in) | `SharedFetch`: one in-flight request per list, 1.5 s reuse, cleared on any write (POST/PUT/PATCH/DELETE) and on any realtime event |
| Badge cubit fetched unread count + list separately; polled while signed out (401s) | One shared notifications request; no polling when signed out |
| `emit` after close (send then leave a chat) | `SafeEmit` mixin on all cubits |
| 1.1 MB unused image in APK | Removed |

| Measurement (profile build, emulator) | Before | After |
|---|---|---|
| Sign-in → Home | 3519 ms | ~1060 ms |
| Group chat messages visible | 1385 ms | 133 ms |
| Handoff detail | 1028 ms | 170–289 ms |
| Search results | 908 ms | 270–342 ms |
| Every one of 28 screens × 4 variants, real content incl. skeletons | — | ≤ 633 ms |

Tests: `shared_fetch_test.dart` (5), suite 109/109.

#### REQ 6 + UI audit — screen tour (2026-11-09)

New `integration_test/vocle_screen_tour_test.dart` opens all 28 signed-in screens + sign-in/OTP in **light, dark, dark 1.3× text, light 1.3× text** on the emulator, records load time and any Flutter error (overflow, layout, build) and screenshots each (114 shots, reviewed by eye).

| Glitch found | Fix |
|---|---|
| Group › Handoffs filter wrapped mid-word ("Pendi/ng", "Activ/e") | Shared `HandoffFilterPills` — same pills as the Handoffs tab, scroll instead of wrap, grow with text size |
| Status-bar icons invisible on sign-in/OTP (white on white) and handoff detail (dark on navy) | `AnnotatedRegion` per screen background |
| Shift dropdown showed raw API values "morning"/"night" | "Morning"/"Night" |
| Dark: unread alert card stayed pale mint with white text (unreadable); emergency/mention colours fixed-light | Theme-aware alert colours |
| Dark: every handoff status badge (Active/Pending/Draft) dark text on dark tint | `handoffBadgeColors` text follows theme |
| Dark: "reassign" write-back note light blue | Theme-aware |
| Dark: selected filter pill navy on navy page | Teal when selected in dark mode (Handoffs + Alerts) |
| Back on Home armed "exit"; leaving Home and coming back let one back press close the app silently | Leaving Home disarms it (test fails without the fix) |

Result after fixes: 0 Flutter errors in all 4 variants; no overflow at 1.3× text; fixed screens re-checked visually.

#### REQ 4 — app side done

- **Reply after 15 min failed:** shade reply used the stored access token without refreshing → now refreshes on 401, saves, retries once (3 tests: expired/valid/revoked).
- **Mark as read** action added next to Reply (clears the chat's alerts on the server + removes the notification).
- **Opening a chat clears its notification**; stored lines no longer pile up (old read lines used to re-appear under each new message).
- In-app: a message for a chat you are not viewing already shows a heads-up banner (system), suppressed for the chat you are in.
- ⚠️ Needs a real-push check on the beta APK (Firebase server credentials are not on this machine).

### Server-side requirements — 2026-11-09/10 (access granted)

All verified against the local backend (master backend + in-memory MongoDB, OTP bypass). API suites live in `C:\Users\user\vocle-dev\*.test.mjs` (outside the repo; run with `run-suites.ps1`, one fresh server per suite).

#### REQ 11 — "Could not start conversation"

| Cause found | Fix |
|---|---|
| Search → doctor: **any** error (incl. the normal "send a request first" 403) showed "Could not start conversation — you can only message known colleagues". Everyone you hadn't chatted with yet hit this dead end. | One `startConversation` flow for Search, Start DM and Group members: open chat → else ask the server why (`GET /api/users/:id/relationship`) → send request / "request already sent" / accept theirs and open. New `ForbiddenException` for 403. |
| DMs created before `memberPairKey` existed were not found → a second, empty chat | Old DM is adopted (gets its key) and reused with its history |
| Parsing errors anywhere showed the same dead-end text | "Could not open the chat. Please try again." + log |

Archived 1:1 DMs still need a fresh request (security suite rule). Tests: API 9/9, widget 6/6.

#### REQ 10 — creator edits / deletes own handoffs

- Edit after submit: allowed for the sender; each edit is recorded (`editHistory`), a visible write-back note is added, an **acknowledged** handoff goes back to *Submitted* so the receiver re-acknowledges, receiver gets "Handoff updated". Assigned doctor can't be changed by edit (use Reassign — audited). A sent handoff can't be emptied of patients.
- Delete: drafts removed; submitted/acknowledged are **soft-deleted** (hidden from every list/detail/search, kept for audit), receiver told "Handoff withdrawn" (alert has no open link).
- F7: "Discard changes?" on back (system and app-bar) when the form is dirty. Lists refresh live (`handoff_updated` / `handoff_deleted`).
- Tests: API 9/9, form cubit 5/5.

#### REQ 2 part 2 — group activity, add members, chat theme

- `system` messages (server-generated only; can't be sent, deleted, reacted to, threaded or searched): created group, joined via code, joined (approved), **X added Y**, **X removed Y**, **X left**, group/channel/Needl renamed, Needl "X added Y · earlier messages shared". Shown as a centred chip; break sender grouping.
- **Add members** (admins): `POST /api/spaces/:id/members`; picker screen with suggestions + search; new members read the full history; "Added to <group>" alert. Privacy: people who know you (shared group / chat) can add you; others only if you allow it (see REQ 5).
- **Chat wallpaper**: Vocle doodle (default), Plain, Mint, Sky, Sand, Blush — light and dark variants; Profile › Chat wallpaper and chat menu › Wallpaper; remembered on the phone.
- Tests: API 14/14, widget 6/6.

#### REQ 5 — Vocle ID, search everyone, contacts, open requests

- **Vocle ID** = unique `@username`, auto-assigned at onboarding ("asharao", "asharao2"…), existing doctors backfilled once at startup; editable with live "available / taken" check; reserved names blocked. Shown on Profile and in results.
- **Search** covers every active doctor (name, @username, speciality, institution); people you know first (`isKnown`). Phone: full number finds anyone; partial digits only people you know (no enumeration). Phone numbers are never returned.
- **Contact sync** (opt-in, `READ_CONTACTS` asked only on tap): `POST /api/users/contacts/match`, ≤3000 numbers/call, matched in memory and not stored; "In your contacts as …"; Invite a colleague.
- **Requests open by default**: any active doctor can be asked; chat still opens only after accept. Privacy now guards **group adds** (Settings › "Let anyone add me to groups").
- F2 fixed: after a request from a *name* search the list no longer turns into "Enter a valid mobile number".
- Tests: API 11/11, contact sync 4/4.

#### Needl (group DM) + threads — end-to-end (user request 11-09)

Hardening found while testing:
- **Consent hole closed**: with requests open to all, the old rule would have let anyone drop a stranger into a Needl. Adding someone to a Needl/group now needs an existing chat/accepted request or a shared group (or their opt-in). Unaccepted/pending requests don't count.
- In the app, a Needl with someone not yet connected now offers **"Send message requests?"** (pending ones listed) instead of an error.
- Thread reply count is written before the reply returns (reopening never shows a stale "N replies"); no threads on activity lines or on replies.
- Live edits arrived as `{messageId, content}` and were parsed as a new message → stray empty row, edit not shown. Now merged in place. Same for deletes of thread replies (stray "deleted" row). Open threads now update live on edit/delete.
- Renaming a Needl now refreshes the header for every member.

| Check | Result |
|---|---|
| API suite (strangers refused, pending ≠ consent, create, idempotent, 1 other → DM, lists, send/read order, outsider 403, alerts, quote, rename, threads in Needl/DM/group, count immediate, guards, inbox, expand with/without history, size limit) | ✅ 22/22 |
| App: create Needl, request offer (only never-asked person gets a request) | ✅ 2/2 |
| App: live edit/delete never adds stray rows; reply counts exact; open thread live | ✅ 5/5 |
| **Emulator journey** (`integration_test/vocle_needl_thread_test.dart`), run twice | ✅ 14/14 steps both runs |

Emulator timings (profile): open Start DM 107 ms · create Needl 307 ms · send 51 ms · other doctor's message live 71 ms · open thread 158 ms · reply 92 ms · other doctor's thread reply live 65 ms · back shows "2 replies →" 54 ms · rename + activity line 128 ms · request offer 172 ms · group-channel thread count live 36 ms.

#### REQ 12 — voice notes + chat features

- Mic replaces Send when the box is empty; recording bar (timer, live waveform, cancel, send); AAC mono 32 kbps; <0.7 s discarded; 15 min cap; temp file deleted; one note plays at a time; tap waveform to seek; 1×/1.5×/2×. Server: `audio` type, `durationMs` + `waveform` validated, audio upload types, previews "🎤 Voice message (0:12)", alerts.
- Emoji: tabbed picker (Clinical, Smileys, Gestures, Symbols + Recent) for the composer and for reactions (any emoji).
- F6: spoken labels for icon-only buttons (send/mic, back, clear, dismiss, edit/remove patient, remove bookmark).
- Plugins: `record` 6.0.0 (5.2.1's Linux part broke every build), `just_audio` 0.9.46.
- Tests: API 8/8, widget 9/9. Recording/playback on a real phone is a beta check.

#### Small sanity fixes

- F5 OTP: typing over a filled box replaces the digit; a rejected code clears the boxes (test 1/1).
- F8: Sign out asks for confirmation.
- F9: version shown from the installed app (`package_info_plus`), not a hard-coded "1.0.0 (15)".

#### Security regression suite (`scripts/security-api-discovery.js`, 691 cases)

Run locally exactly like the GitHub workflow (local MongoDB 7 on 27017, fixtures, auth smoke, manifest check). Baseline on untouched `origin/master`: 644 passed / 47 observations, exit 0.
- Manifest unchanged (626 verified cases intact).
- One setup step (`consent-handoffs.js`) assumed request opt-in allows group adds; now uses the explicit group-add opt-in for that case only (restored afterwards). The check it guards is unchanged.
- Final run on this branch: **691/691 executed, exit 0** (626 passed, 65 observations vs 47 on master). The username backfill is skipped in `NODE_ENV=test` (it changed fixture rows mid-run and tripped a "state unchanged" check).
- The 19 observations not on master are the intended product changes: REQ 5 (search beyond known colleagues, requests open by default), REQ 10 (edit/delete submitted handoffs), and two "group DM with request-eligible peers" cases that are now refused (the suite itself flags that path as a consent concern). These need a deliberate expectation update by the security owner.
- `package-lock.json` was missing the `socket.io-client` packages already listed in `devDependencies` (CI's `npm ci` would fail); `npm install` filled them in, no version changes to existing packages.

### Beta feedback on 1.0.0+30 (2026-11-10) and production deploy

**Root cause of the "Something went wrong" reports:** the 1.0.0+30 APK talks to production, which was still on `master` 4c01dc2 (server half not deployed). Replaying the app's calls against that exact code: relationship + contact-match endpoints 404, stranger request 403 (old rule), voice upload 400 "File type not allowed", audio message 400. Gap on my side: contact sync and voice recording had only been tested with simulated device parts, never on a device.

| # | Report | Fix | Verified on device (emulator, local server = deployed code) |
|---|---|---|---|
| 1 | DM after search / request → error; Find contacts not syncing | Server deployed; app falls back to "send request" if an older server lacks the endpoint; leftover snackbar no longer covers the new chat's message box (chat open 4 s → 0.18 s) | Real address-book contact "Bala ICU" → "In your contacts as Bala ICU" (232 ms); stranger → request offered → sent |
| 2 | Needl voice note "Failed to send" | Server deployed (audio type + uploads); release unchanged; debug/profile allow local http media | Real microphone recording 2.9 s → uploaded → other doctor receives `audio` (29-bar waveform) → plays back |
| 3 | Auto-read OTP from SMS | Android SMS User Consent ("Allow Vocle to read the message…?"), no SMS permission; fills and verifies | Real SMS sent to the emulator → system prompt → Allow → signed in without typing |
| 4 | Theme had no Save; "wallpaper" | **Chat theme**: background + own-bubble colour, live preview, **Save**, *This chat only* / *All chats*; leaving without Save changes nothing | Pick Mint → This chat only → Save → "Theme saved for this chat"; widget tests 3/3 |
| 5 | Home alerts pill misaligned | Actions in one centred row; pill 24 px centred | Screenshot: pill centred on the icons' line |

Device journeys (all pass): Needl + threads 14/14 steps (run 3×), contacts/request/voice/theme 11/11, OTP auto-read 1/1. App tests 147/147.

**Production deploy:** `addde78` pushed to GitHub `master` → Railway; `/health` reports `version: addde78`, database connected, Firebase + Cloudinary on. First start backfills Vocle IDs for existing doctors.

**Constraints**
- Backend changes reach phones only after deploy to Railway (from GitHub `master`; `sanjaybabu2210` currently has read-only access). Until then they are verified against the local backend; a release APK pointing at production will not show backend-dependent features.
- REQ 4 real push (background/killed app, reply from shade) needs Firebase server credentials, which are not in this machine's hand-off; local verification covers in-app/local notifications and the reply code path.

## Release

- [x] Version bumped `1.0.0+27` → `1.0.0+28`
- [x] Release APK (production API, MSG91 widget, FCM config from hand-off) built with Flutter 3.29.3
- [x] Commit + push to `master`
