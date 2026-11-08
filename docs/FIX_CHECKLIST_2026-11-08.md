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

## Release

- [x] Version bumped `1.0.0+27` → `1.0.0+28`
- [x] Release APK (production API, MSG91 widget, FCM config from hand-off) built with Flutter 3.29.3
- [x] Commit + push to `master`
