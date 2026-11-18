# Beta round 11-18 — tester findings + enhancements (Vocle v35, app 1.0.0+35)

Base: tester's `master` 8b96ad1 (34 commits of new regression tests) fast-forwarded into
`fix/e2e-defects-20261108`, fixes on top, merged back to `master` for Railway.
Toolchain: **Flutter 3.29.3** (`dev-sdks\flutter-3.29.3`). `dev-sdks\flutter` is now 3.47 and
does not build the app — with it ~20 widget tests fail with shader errors that are not app bugs.

## Tester's failing regression cases (all were reproducing before the fix)

| ID | Problem | Fix | Proof |
|---|---|---|---|
| FR-AST-25 | Second Send tap ran the action twice | Cubit refuses a confirm while one runs or for a card no longer shown; button disabled while sending; **server idempotency**: `clientMessageId` (unique per sender+chat) → a retry/double tap returns the first message, no second push | Flutter FR-AST-25 ✅ · API 18.3 (concurrent + repeat → 1 stored) ✅ · device: 3 taps → exactly 1 message ✅ |
| FR-VCE-12 | Late history load wiped a live clip + transcript | History merges with clips that arrived live | ✅ |
| FR-VCE-15 | New clip took over a paused clip | A paused clip (position > 0) keeps the player; arrivals queue | ✅ |
| FR-VCE-16 | One failed clip stalled autoplay | Queue advances past a clip that fails to load (it stays listed) | ✅ |
| FR-HOF-02 | Invalid shift date accepted with "success" | Update validates the date (400, draft unchanged) | backend catalog ✅ |
| FR-NDL-28 | Two Adds at once → one request failed | Duplicate-key race joins the Needl the other request created; one activity line | backend catalog ✅ |
| FR-NDL-29 | History copy lost after a DB error + retry | Copy state on the Needl (`copying/failed/done`); retry resumes, removes partial copies, copies once | backend catalog ✅ |
| FR-NDL-39 | Older "Be" search reply cleared "Ze" results | Search generations; stale replies dropped (name + phone lookup) | ✅ |
| FR-NDL-53 | Members panel 91 px overflow | Panel sized to content, scrolls past 80 % of the screen | ✅ + device shot |

## Voice findings (tester report §1–9)

| # | Finding | What changed |
|---|---|---|
| 1 | Duplicate send | see FR-AST-25 |
| 2 | Wrong bed / summary in handoffs | Card lists **To / Shift / Beds / Summary** separately; beds only from "bed N" (spoken numbers ok, "at 12:00" never a bed); summary only after "saying / notes / , / –"; words after the name that match nobody ("the sky") are shown as *not used*, never put in the draft |
| 3 | Background speech triggers commands | Hold-to-talk on the mic (listens only while held); every voice result shows what was heard and needs a tap; "show my conversation with …" (background-style) still proposes nothing; 25 s hard cap per command. *The recogniser cannot tell speakers apart — honest limit.* |
| 4 | Names misrecognised | Recogniser biased to the doctor's colleague/chat names (Android 13+); up to 5 hypotheses — a hypothesis that names a colleague is used and the card says so; unknown name → **no guess**, "Choose from your colleagues" picker keeps the message/beds |
| 5 | Noise | Biasing + n-best help; no claim of hospital-grade accuracy; tester's noise corpus kept for comparison on physical phones |
| 6 | "General" needed clarification | `#general` alias counts as the chat's name; resolves when unique, asks when several |
| 7 | Rigid phrasing | "conversation with Dr Morgan", "take me to …", "change my status to …", "my status is …" understood; nothing guessed |
| 8 | Recogniser stalls | Native watchdog (8 s after speech ends, 25 s cap) + app watchdog; the session is retired, so a late result can never act |
| 9 | Real device / offline | On-device first; if no offline English pack, falls back to the phone's standard recogniser for commands only (Needl Voice clips stay on-device); clear messages for no network / no pack. *Physical-phone validation still needed.* |

## Enhancements requested 2026-11-18

| # | Request | Done |
|---|---|---|
| E1 | Assistant bottom-right overlay; mic permission prompt (no glitch) | Floating button bottom-right on every main tab (raised above Messages' own button); Android permission dialog requested by the app; "blocked" → Open settings |
| E2 | Unique medical chat design (not WhatsApp) | "Chart-note" bubbles (clipped corner, teal margin rule on incoming), petrol own bubble in dark (no messenger green), ECG-trace chat canvas, card-style composer with square action key |
| E3 | Faster page moves | 200 ms fade-slide transitions (was 300 ms zoom with page snapshots); directory loads in parallel; see timings |
| E4 | Remove non-working themes | Chat themes reduced to Clinical / Scrubs / Plain (all tuned for light + dark); removed ids fall back to Clinical |
| E5 | Needl Voice separate from text chat | Own entry (Messages → Needl Voice list), clips stored with `voiceMode` and served only by `?mode=voice`; text chat, previews and copies never show them; own `lastVoice`; notifications open the voice view |
| E6 | Assistant: context + general answers | Conversation memory (8 turns, kept 10 min) sent to the AI half with the current screen; new `reply` tool for questions; built-in answers (help, time, date, how-to) without AI; honest message when the AI key is not set |

## Verification

- **App tests:** 293/293 (Flutter 3.29.3), including the tester's 98-ID Flutter catalog (6 failures before → 0) and `test/beta_1118_voice_test.dart` (22 new).
- **Server:** tester's backend catalog — every module passes; FR-NDL-10 is still NEEDS_DECISION (archived-Needl expansion, product decision, unchanged). API suites 4/4: handoff-voice 11, needl-continue 6, privacy-views 22, voice-features 16 (4 new: voice separation, explicit chat voice notes, idempotent send, assistant history/context).
- **Contracts:** catalog/feature matrix regenerated, `npm run contracts` 23/23.
- **Emulator** (`integration_test/vocle_beta_1118_test.dart`, Pixel 6 API 35, profile build, real Android permission dialog + recogniser):
  assistant FAB bottom-right; mic prompt → granted → listening; built-in answers; handoff fields + "the sky" flagged;
  unknown name → picker; 3 rapid Send taps → exactly 1 stored message; "General" opens #general and the assistant closes;
  clinical chat light/dark; 3 themes, sub-pages cover the FAB; Needl Voice list → clip recorded → in voice history, not in chat; Needl members panel fits.
- **Page timings** (profile, emulator software GPU, push → first settled frame incl. data, median of 3): DM 305 ms, Needl 466 ms, Search 420 ms, Needl Voice list 405 ms; tab switches 325–715 ms (first visit builds the tab).
- **Defect found on device and fixed:** an assistant action that opened a chat left the assistant sheet open behind it (later covered other screens).

## Release

- `Vocle-v35.apk` — 1.0.0 (35), production API, launch smoke-tested on the emulator.
- Backend deploy: `master` → Railway (new unique index on messages is built by Mongoose at start-up).
- AI half of the assistant (general medical / free-form questions) needs `ANTHROPIC_API_KEY` on Railway; without it the built-in answers and commands work and the app says the AI is not switched on.
- Old v33 apps against this server: Needl Voice clips no longer appear in their text chats (by design); install v35.
