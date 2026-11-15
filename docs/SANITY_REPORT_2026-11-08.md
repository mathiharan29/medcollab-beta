# Vocle sanity report — 2026-11-08

**Build:** debug, `fix/e2e-defects-20261108` @ `8441dd6` (= `origin/master` 4c01dc2 + REQ-1 + ported E2E fixes), Flutter 3.29.3
**Device:** Android emulator `Vocle_Pixel` (Pixel 6, API 35), fresh install
**Backend:** `master` backend, local, in-memory MongoDB, OTP bypass (123456). Firebase and Cloudinary off. Production not called.
**Users:** Dr Asha Rao `+91 91000 00001` (driven in the app) · Dr Vikram Shah `+91 91000 00002` (driven via API as the second phone)

## Results

| # | Area | Steps | Result |
|---|---|---|---|
| S1 | Sign-in | Phone → wrong OTP → correct OTP → profile setup → Home | ✅ wrong OTP shows "Incorrect OTP" (400); correct → Home |
| S2 | Bottom tabs | Home, Messages, Handoffs, Alerts, Profile render; Back from each → Home | ✅ |
| S3 | Groups | Home → Browse/create → Create "Medicine Unit 3" → detail (3 default channels, invite code) | ✅ |
| S4 | Channel chat | Send in #general (201); other doctor posts → appears live; long-press → Reply in thread → reply posted, "1 reply" in channel | ✅ realtime works |
| S5 | Join by code | 2nd doctor joins via invite code | ✅ |
| S6 | Direct messages | Name search → message icon → request dialog → send → other accepts → chat both ways, live | ✅ chat works · ❌ **F1**, **F2** |
| S7 | Handoffs | New handoff → assignee → add patient → Submit (201/200) → other acknowledges → shows Active | ✅ · ⚠️ **F3**, **F7** |
| S8 | Alerts | "Handoff acknowledged", "Request accepted" listed; tapping opens handoff / DM | ✅ |
| S9 | Search | "potassium" finds channel message; "zzqx" → "No results" | ✅ |
| S10 | Profile | Edit institution → save (200) → shown; Help & FAQ | ✅ · ⚠️ **F4**, **F9** |
| S11 | Back in popups (REQ-1 regression) | Back on message action sheet closes only the sheet | ✅ |
| S12 | Session | Kill + relaunch restores session; Sign out → login; Back on login does not re-enter; sign in again | ✅ · ⚠️ **F8** |
| — | App errors (logcat) during whole run | | ✅ none |

## Findings

| ID | Severity | Finding | Evidence / cause | Related REQ |
|---|---|---|---|---|
| F1 | **High** | Messages hub lists go stale: after a DM request is accepted, the sender's **Direct** tab stays "No direct messages yet"; a group created elsewhere doesn't appear under **Groups** ("No channels yet"); DM preview stays "No messages yet" after messages. Only an app restart fixes it. | `messages_hub_page.dart` loads once in `initState`; shell keeps the tab alive; empty states (`:395`, `:833`) are not wrapped in `RefreshIndicator`, so pull-to-refresh does nothing; no reload on socket events. Backend returns the DM correctly. | REQ 2, REQ 5 |
| F2 | Medium | Start DM by **name**: after sending a request, the screen shows "Enter a valid mobile number" and the result disappears. | `start_dm_page.dart` refreshes with `_lookupPhone(searchText)` even for name searches. | REQ 5 |
| F3 | Medium | Add patient → **Attachment** chip shows only a paperclip; its "Add attachment" label is invisible. | Seen on screen; label present in UI tree. | REQ 9 |
| F4 | Low–Med | Every avatar shows **"D"** (initial taken from the "Dr" title), so doctors are indistinguishable. | Profile, DM list, search results. | — |
| F5 | Low | OTP: after a wrong code, typing into a filled box does nothing (must backspace first); wrong code is not cleared. | Backspace itself works. | — |
| F6 | Low | Icon-only buttons (send, attach, search, compose, header back/menu) expose no accessibility label. | uiautomator shows empty labels. | REQ 12 (chat UI) |
| F7 | Low | Leaving Create handoff with entered data discards it without a "Discard changes?" prompt. | | REQ 10 |
| F8 | Low | Sign out has no confirmation. | | — |
| F9 | Low | Profile footer shows "1.0.0 (15)"; app is build 27/28. | Hard-coded in `app_constants.dart:7`; display only. | — |

## Not covered in this run

Push notifications (Firebase off locally), media/attachment upload (Cloudinary off), QR scan, emergency channel, bookmarks, availability, notification settings, dark mode (→ REQ 6), iOS.
