# Beta round 11-26 — 8 fixes (Vocle v36, app 1.0.0+36)

| # | Report | Cause | Fix |
|---|---|---|---|
| 1 | Keep Needl Voice inside the chat, but don't mix its clips into the chat | v35 moved it to a separate list under Messages | Needl Voice button back in every chat header; list removed. Clips are still stored and shown only in Needl Voice (`?mode=voice`), never in the text chat or its preview |
| 2 | Forward shows `vocle://c/…/m/…` and storage links | Forward sent a text message: "Forwarded from X" + link + text + media URL | A forward is now a server-side copy of the original (text, photo, file, voice note) tagged **Forwarded from …**; tapping the tag opens the original when the reader can see that chat; forwarding a forward keeps the original author; retry stores once. Old link-style forwards (and quotes / chat-list previews of them) are shown cleanly without the link |
| 3 | "Something went wrong" banner while chatting | Reaction taps: the server loaded, changed and saved the whole message; two taps at once → version conflict → HTTP 500; the banner never cleared | Atomic reaction updates (no conflict possible); the app shows taps at once, sends them in order with the intended state, undoes a failed one with a clear message; chat banners can be dismissed and clear after 6 s |
| 4 | No voice note option in the handoff | Replies (write-back) were text only | "Voice reply" recorder in **Add note / reply**: voice, text, or both; both doctors can play it |
| 5 | Notification missed while mobile data was off | The server skipped the push for anyone whose phone still looked connected to that chat; a phone that just lost data looks connected for up to ~85 s. Pushes were also collapsible per chat (FCM keeps only 1 per chat and 4 chats per offline phone) | Push is always sent (no Alerts entry while really viewing; the app hides the banner if the chat is on screen); pushes are no longer collapsible and are kept for 24 h |
| 6 | Double tap on an emoji → vanished → "Something went wrong" | Tapping your own reaction chip removed it; the second tap collided on the server (see 3) | Tapping your own reaction opens who-reacted with a **Remove** button (only the button removes, and not in the first 0.6 s — the second tap of a double tap used to land on your row and remove it); someone else's emoji adds yours; no server conflict |
| 7 | Camera icon should also offer the gallery | Camera opened the camera only | Camera icon → **Take photo** / **Choose from gallery** |
| 8 | Several reactions per person | Server replaced a person's previous emoji | Several emojis per person (up to 8 per message); the same emoji again removes only that one |

Changed regression contracts (product decisions in this round): FR-SOC-01 (several emojis per user), FR-LINK-01 (forward is a copy, not a link), FR-PUSH push options (not collapsible), FR-VCE-14 (Needl Voice opened from the chat header).

Also fixed (found while verifying): after a Needl Voice clip was transcribed, the app asked Android to download the English (India) speech pack, which Android shows as a system dialog at a random moment over the chat. The automatic request is removed; the phone's own English is used as before.

## Verification

- App: 304/304 tests (Flutter 3.29.3); `test/beta_1126_test.dart` covers old/new forward display, quotes and previews, several reactions, fast taps in order, failure undo, chip double-tap, camera menu, handoff voice reply.
- Server: API suites 65/65 (new `beta-1126`: forward copy / retry once / photo / forward-of-forward / permissions; several reactions; 20 concurrent taps with no error; 8-per-person limit; handoff voice reply). `push-routing.unit.mjs` 3/3: a viewer whose phone may be offline still gets the push, no Alerts entry; pushes not collapsible.
- Tester's backend catalog: all modules pass except FR-NDL-10 (product decision, unchanged).
- Emulator journey `integration_test/vocle_beta_1126_test.dart` passed end to end: Needl Voice from the chat header with the clip kept out of the chat; camera → gallery picker; text and photo forwarded through the real sheet; two reactions from one person; 9 rapid taps with no error; handoff voice reply recorded, posted and readable by the sender.
- Real Android touches (adb, release-like profile build): long-press → 👍 → long-press again → ❤️ → both shown; double tap on your own 👍 no longer removes it.
