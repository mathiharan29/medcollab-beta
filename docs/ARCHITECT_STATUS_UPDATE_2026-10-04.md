# Vocle (MedCollab) — Architect Status Update

**Date:** 2026-10-04  
**Audience:** Architecture / tech lead  
**Product UI:** Vocle · **Codebase / API:** MedCollab  
**Current app version:** `1.0.0+24`  
**Production API:** https://medcollab.up.railway.app  
**Health:** https://medcollab.up.railway.app/health  
**Latest release APK:** `D:\MedCollab\Vocle-beta.apk` (local artifact; not in git)  
**Primary remotes:** GitLab `origin` · GitHub `mathiharan29/medcollab-beta` (`master` → Railway)

---

## 1. Where we are

Vocle is a **closed-beta clinical messaging app** for Indian hospital doctors (interns, PGs, junior consultants). Goal: replace WhatsApp for department chat, DMs, threads, and **structured shift handoffs**.

| Layer | Status |
|-------|--------|
| Backend (Node / Express / Mongo / Socket.io) | Live on Railway Hobby |
| Android Flutter client | Beta APK in active doctor testing |
| Auth (MSG91 widget OTP → JWT) | Live |
| Push (FCM Android) | Live |
| Media (Cloudinary) | Live (prod cloud `denbnijqe`) |
| Legal / support surfaces | Shipped (Privacy, Terms, FAQ, feedback) |

**Architecture (unchanged):** REST persists messages; Socket.io broadcasts. API envelope `{ success, message, data }`. Feature-folder backend. Railway deploys **only** from GitHub `master` with root `medcollab-backend/`.

**Team split (current):**
- Product / agent loop: feature + beta polish on `master`
- Sanjay: APK generation (MSG91 + `google-services.json` shared privately)
- Sriram: media security — offline/local done; next is **separate non-prod Cloudinary** for integration-security CI

---

## 2. Features shipped so far

### Core platform (Sprints 1–14)
- Phone OTP login (MSG91 widget) + JWT session / refresh
- Spaces (departments), channels, members, invites + QR join
- Direct messages, threads, reactions, pins, search, drafts
- Structured **handoffs** (draft → submitted → acknowledged)
- Home shell, notification prefs, FCM deep links
- Privacy / Terms / Help / bug & feature request
- Closed-beta packaging (`1.0.0+14` era)

### Beta growth (Sprints 15–17)
- Role-aware onboarding / profile (incl. MBBS student)
- DM-by-phone + **message requests** (group ≠ free DM)
- DM-first Messages hub; live QR scan
- Handoff list / navigation polish
- Rate-limit and back-nav hotfixes

### WhatsApp-smooth chat (≈ `1.0.0+19`–`+21`)
- Quote-reply (swipe), DM privacy hardening
- Branding / OTP autofill / thread socket dedupe
- Faster DM open, chat scroll restore, in-app forward
- Self-notes DM, overdue handoff “resolve” honesty
- Notification preference merge fixes

### Sprint 18 — Needl + handoff write-back (`1.0.0+22`)
- Multi-person DM (**Needl**) create + rename
- Messages hub: Direct / **Needl** / Groups
- Handoff assignee **write-back notes** + **reassign**
- `GET /api/users/me/needl`

### Chat / notifications polish (`1.0.0+23`–`+24`)
- Typing **bubbles** in chat + DM list (not plain text)
- Grouped notifications + shade **Reply**; cold-start opens chat
- Tab back-stack (Home ↔ Handoffs without killing app)
- Video attach (gallery); upload limit raised to 50 MB
- Composer: **+** attach, emoji, `@`, clinical shortcuts
- Needl: selectable chips with names; create + **expand** people  
  (history: all / today / none — Slack-style)
- Production crash fix: invalid Mongoose `_id: true` on handoff `writeBackNotes` (`4638682`)

### Research parked (not built)
- **Pulse** — ward urgency cards above chat (see `docs/MEDICO_COMMS_RESEARCH_PULSE.md`)

---

## 3. Production / ops snapshot

| Item | State |
|------|--------|
| Railway | Healthy after handoff schema fix; redeploy required when schema/API changes |
| Cloudinary | Prod cloud in use; local disk fallback only for dev |
| FCM | Android client + Firebase Admin on Railway |
| Secrets | `dart-defines.release.json` + `google-services.json` gitignored; zip shared to Sanjay out-of-band |
| Tests | Flutter unit/widget suite exists; device smoke still mostly manual |

---

## 4. Open items

### P0 — Beta correctness / trust
| Open | Notes |
|------|--------|
| Device regression on `1.0.0+24` | Needl create/expand, video, notification tap, tab back — doctor QA |
| Notification grouping on all OEM Androids | MessagingStyle + data-only FCM; verify MIUI/Samsung |
| Video delete path | Backend `destroy` retries image→raw only; video resource_type incomplete |
| Message-request edge cases | Toggle / prefs merge — watch for regressions |

### P1 — Security / compliance (Sriram)
| Open | Notes |
|------|--------|
| **Separate non-prod Cloudinary** | Empty cloud; GHA secrets only; no prod media/keys |
| Integration-security phase in CI | Upload / read / delete synthetic assets only |
| DPDP posture narrative | Keep clinical data off WhatsApp; retention story for Pulse/handoffs later |

### P1 — Product differentiators
| Open | Notes |
|------|--------|
| **Pulse** (recommended next unique feature) | Timed assignable ward asks; survives shift change |
| Handoff I-PASS / fuller template | Research preferred I-PASS; write-back shipped first |
| Dark theme | Deferred |

### P2 — Platform / scale
| Open | Notes |
|------|--------|
| Play Store `applicationId` / listing | Still `com.example.medcollab_app` for beta |
| iOS | Not in closed beta |
| Dedicated unread API | Badges still notification-derived in places |
| Roster / shift sync | Partial; not full hospital roster product |
| Cloud Agents / Teams billing for Cursor | Org process, not product |

### Known ops debt
| Open | Notes |
|------|--------|
| Railway auto-deploy reliability | Occasionally stuck until manual Redeploy |
| Architect docs drift | Older `PROJECT_LEAD_SUMMARY` still at Sprint 14 — this file is current |
| APK / secret zips on disk | Must never be committed |

---

## 5. Suggested near-term sequence

1. **QA gate** on `1.0.0+24` Needl + notifications + video with 2–3 doctors  
2. **Cloudinary security test cloud** for Sriram’s GHA phase (no prod credentials)  
3. Spec + spike **Pulse** MVP (Home strip + create from Needl + ack/done)  
4. Harden media delete for **video**; Play Store package rename when ready for store

---

## 6. Pointers

| Doc | Use |
|-----|-----|
| `DEPLOYMENT.md` | Railway, MSG91, APK |
| `PUSH_NOTIFICATIONS.md` | FCM |
| `docs/MEDICO_COMMS_RESEARCH_PULSE.md` | Differentiator research |
| `docs/SPRINT_18_REGRESSION_1.0.0+22.md` | Needl / handoff write-back gate |
| `medcollab-backend/.env.example` | All server env vars |
| This file | Architect snapshot as of 2026-10-04 |

---

**One-line status for leadership:**  
Vocle closed beta is live with handoffs, Needl multi-person DMs, FCM, and WhatsApp-like chat polish through `1.0.0+24`; next bets are device QA, isolated Cloudinary security CI, and **Pulse** as the install-worthy clinical differentiator.
