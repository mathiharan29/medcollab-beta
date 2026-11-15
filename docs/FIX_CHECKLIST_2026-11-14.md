# Beta round 11-14 — fix & feature checklist (app 1.0.0+33)

Branch: `fix/e2e-defects-20261108` → merged to `master` for Railway.
Legend: ✅ verified · ⚠️ verified with a noted limit

## Verification environment

- Flutter 3.29.3 (pinned). Emulator `Vocle_Pixel` (Pixel 6, API 35), **profile** build.
- Local backend = this branch + MongoDB Memory Server, `OTP_BYPASS=true`. Production never called by tests.
- Device journey: `integration_test/vocle_beta_1114_test.dart` + `test_driver/integration_test.dart`
  (exact-frame screenshots → `$VOCLE_SHOTS`) + `scripts/device-watch.ps1` (network delay, real notification shade).
  Seed: `medcollab-backend/tests/device/seed-1114.mjs`.
- API suites: `medcollab-backend/tests/api/run.ps1` (privacy-views, needl-continue, handoff-voice, voice-features).

## Results

| # | Issue | Fix (main files) | Unit/widget | API | Device |
|---|---|---|---|---|---|
| 1 | Theme switch jumps; dark looks off | One ThemeData builder for both modes (same geometry), snapshot crossfade, neutral graphite dark palette; chat wallpaper dark = near-black (`app_theme.dart`, `app_colors.dart`, `theme_switch_transition.dart`, `chat_wallpaper.dart`) | ✅ theme_switch_consistency | – | ✅ row 411.4×72.0 and labels identical light↔dark |
| 2 | Messages / Needl / Groups slow | `ChatPrefetcher` warms top chats, targeted hub reloads, `spaceById` cache, gzip JSON, `{channelId,threadId,_id}` index | ✅ chat_prefetcher | ✅ | ✅ see timings below |
| 3 | Back always went Home | One level up (`logicalParentOf`), Home asks before exit | ✅ tab_history (FR-NAV-03 updated) | – | ✅ chat→Messages, settings→Profile |
| 4 | Uneven composer, poor placeholder | `ComposerShell` (48 px pill, 24 px icons), hint "Message"/"Reply" | ✅ composer_layout | – | ✅ |
| 5 | Voice note in handoffs | Shift + per-patient voice notes, trusted URLs, `contentVersion` optimistic concurrency (409 + reload banner), discard prompt | ✅ handoff_voice | ✅ 11/11 | ✅ play, record, discard prompt |
| 6 | Alerts count not dropping | Read-epoch guard, `serverChanged()` on new alerts, chat-on-screen alerts read on arrival, foreground-aware tracker; **+ chat load race** (live message dropped by an older snapshot) | ✅ alerts_badge_race, chat_load_race | – | ✅ 3 → 0, badge == server |
| 7 | Reply from notification stuck | **Root cause: `ActionBroadcastReceiver` was never declared in the manifest, so Android dropped every Reply / Mark-as-read** (found on device). Plus: background isolate registers plugins, always re-posts the notification, 25 s budget + one retry | ✅ notification_reply_refresh (9), android_manifest | – | ✅ real shade Reply delivered |
| 8 | Needl add not live | `needl_continued` system line + live member events; "Open new Needl" | – | ✅ 6/6 | ✅ adder + other member |
| 9 | @mention can't tell people apart | Panel with avatar colour, @username · speciality · role | ✅ mention_suggestions | – | ✅ two "Asha Rao"s distinct |
| 10 | Delete-for-me preview | Per-viewer `lastMessage` fallback | – | ✅ privacy 22/22 | ✅ |
| 11 | Clear chat leaks | Pre-clear previews hidden; old thread → "unavailable" | ✅ thread unavailable | ✅ | ✅ |
| 12 | White box behind loading logo | Transparent logo, Android 12+ splash colours light/dark | ✅ splash_logo | – | ✅ |
| 13 | Needl Voice | Hold-to-talk voice-only view, auto-play queue, on-device transcript (long-press / double-tap), Copy / Read aloud, language-pack fallback | ✅ needl_voice_cubit | ✅ voice-features 12/12 | ✅ |
| 14 | Voice Bot | Hybrid: private on-device parser + optional Claude (`/api/assistant`, propose-only), confirm card before every action | ✅ parser + cubit | ✅ | ✅ send + status |

### Issue 2 — page-open timings (profile, emulator, 200–400 ms simulated latency, median of 3)

| Open | Before (cold) | After (prefetched) |
|---|---|---|
| DM | 1319 ms | 200 ms |
| Needl | 1193 ms | 214 ms |
| Group | 1247 ms | 279 ms |
| Messages tab | — | 87 ms |

## Defects found during verification (fixed)

- Shade Reply never reached the app: missing `ActionBroadcastReceiver` manifest entry (issue 7 root cause).
- Appearance sheet overflowed by 252 px on a phone (now scrollable).
- Alerts badge stuck after a burst of messages (1.5 s shared cache).
- Chat: a message arriving while the chat was loading vanished; one deleted meanwhile came back.
- Voice bot: a late recognizer error replaced the confirm card; "tell Arjun …, BP 120/80" read the comma as the end of the name; "#general" chats not matched by voice.
- On-device recognizer error 13 (en-IN pack missing) → falls back to the phone's English / en-US and requests the pack.
- Needl Voice header showed "Chat" when opened before the chat had loaded.

## Deploy notes

- Railway: set `ANTHROPIC_API_KEY` (optional `ASSISTANT_MODEL`) to enable the AI half of the voice bot; without it the built-in parser is used.
