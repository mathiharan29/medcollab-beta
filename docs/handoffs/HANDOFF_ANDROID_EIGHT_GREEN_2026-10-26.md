# Handoff: Android LOCAL_ONLY eight-case lane green (2026-10-26)

**Audience:** Dev team + Security / Sriram remediation reviewers  
**Branch:** `master`  
**Evidence commit baseline:** `21c802ceaf674acb9116b53d475b627ab15977ae`  
**Lane:** Vocle Android-eight (`scripts/run_android_eight.py` / `scripts/run-android-eight.ps1`)  
**Result:** **8/8 PASS** (LOCAL_ONLY device cases)

---

## 1. Verdict

All eight Android LOCAL_ONLY cases that previously blocked ship confidence are green on committed tree `21c802c`:

| Case | Status | Area |
| --- | --- | --- |
| FR-MED-08 | PASS | Media picker / upload / PDF / cancel |
| FR-PUSH-05 | PASS | Notification grouping + tap route + reply |
| FR-PUSH-06 | PASS | FCM token lifecycle |
| FR-NAV-04 | PASS | Resume / deep navigation |
| FR-NAV-05 | PASS | Session restore |
| FR-LINK-04 | PASS | Invite / deep link join |
| FR-JRN-05 | PASS | Journey (auth → clinical path) |
| FR-JRN-06 | PASS | Journey (handoff / Q14 join UI path) |

Full report + logs: [`docs/handoffs/evidence/android-eight-21c802c-2026-10-26/`](./evidence/android-eight-21c802c-2026-10-26/)  
Primary files: `results.json`, `report.md`, `coverage.json`, `junit.xml`, `provenance.json`, `*-events.json`, `backend-device-*.log`, `diagnostics/`.

**Not claimed:** real MSG91/FCM provider delivery, iOS, or full-187 CI/security suite clearance by this lane alone. Push to remotes still requires a successful `full-187` gate for the push `HEAD` (`pushEligible: true`).

---

## 2. Product / client fixes (dev)

These made the LOCAL_ONLY device cases deterministic:

1. **AuthBloc OTP / logout** — Avoid emitting after `emit.forEach` completion; unblock logout so session teardown does not hang the harness.
2. **Auth interceptor** — Do not wipe in-flight OTP / anonymous session on 401 during widget OTP flows.
3. **Cold FCM tap buffer** — Buffer notification taps that arrive before the Flutter broadcast listener is ready (`fcm_service` / app bootstrap) so FR-PUSH-05 / NAV deep-link taps are not lost.
4. **Join / invite redirect (Q14)** — Pending-join UI and router behavior so invite deep links land on the correct space/channel path (FR-LINK-04 / journeys).
5. **ChannelChatCubit** — Guard emits after close; media/picker error paths do not crash the chat page.
6. **Media picker** — Safer camera / PlatformException handling; patient-text vs bed alias alignment for journey assertions.
7. **Harness** — Deferred emulator boot after APK prewarm; 1536MB AVD; settle waits / retries; longer device-case timeout; Node ECONNRESET resilience in device-server.

Entry points of interest:

- `medcollab-app/lib/` — AuthBloc, FCM, router, channel chat, media picker
- `scripts/device-server/`, `scripts/vocle_android.py`, `scripts/run_android_eight.py`
- Journeys / invites fixtures under harness + app invite preview flows

---

## 3. Security notes (security team)

| Topic | Status / ask |
| --- | --- |
| OTP bypass | Still **dev-only**; production must keep `OTP_BYPASS` blocked. Device lane uses local/control-server OTP paths — do not treat green as MSG91 production proof. |
| JWT / interceptor | 401 handling during OTP was narrowed so anonymous OTP is not cleared incorrectly. Review that authenticated session wipe-on-401 still holds outside OTP widget flows. |
| FCM | Cold-start tap buffer is client-side only; token registration (FR-PUSH-06) still goes through existing Firebase Admin / token API. No new secret surfaces in this lane. |
| Media uploads | FR-MED-08 exercises real chat upload paths against local/device backend; Cloudinary production credentials are not required for this evidence pack. |
| Artifacts | Do **not** commit `Vocle-apk-secrets-for-Sanjay.zip`, `.env`, `dart-defines.release.json`, or signing keystores. Release APK is a build artifact — distribute out-of-band, not as a secret dump in git. |
| Evidence pack | Contains harness logs and event JSON only (no production tokens). Review `diagnostics/` and `backend-device-*.log` if auditing control-server behavior. |

Wave context: Sriram Waves 1–3 already on `master`; realtime Wave 4 remains separate. This handoff does not close Wave 4.

---

## 4. How to re-run the eight-case lane

From repo root (Windows):

```powershell
powershell -File .\scripts\run-android-eight.ps1
```

Or:

```powershell
python .\scripts\run_android_eight.py
```

Preconditions: Flutter SDK, Android SDK/`ANDROID_HOME`, free adb (close personal emulators), committed tree preferred for provenance.

---

## 5. Ship / push gate

| Gate | Role |
| --- | --- |
| Android-eight 8/8 | Confidence for the LOCAL_ONLY Android device set |
| `full-187` (`scripts/run-vocle-local-gate.ps1 -Profile full-187`) | **Required** before `git push`; only exit `0` + `pushEligible: true` for current `HEAD` clears push |

After sign-off and eligible gate marker, push:

- `origin` → GitLab (`gitlab.com/mathiharan-project/MedCollab`)
- `github` → Railway deploy source (`mathiharan29/medcollab-beta`) — only if intentional for production deploy from `master`

---

## 6. Release APK

Build (machine with signing + `medcollab-app/scripts/dart-defines.release.json`):

```powershell
powershell -File .\medcollab-app\scripts\build-release-apk.ps1
```

Output is typically copied to repo-root `Vocle-beta.apk` / `MedCollab-beta.apk` per script. Treat as release binary; keep signing material private.

---

## 7. Evidence index

Curated copy of pass run `2026-10-26T15-57-42Z-21c802ce`:

- `docs/handoffs/evidence/android-eight-21c802c-2026-10-26/MANIFEST.txt`
- `results.json` — counts PASS: 8
- `report.md` — human table
- Per-case `*-events.json`, `backend-device-*.log`, `diagnostics/*`

Raw launcher output remains under gitignored `test-results/android-eight/` on the builder machine.
