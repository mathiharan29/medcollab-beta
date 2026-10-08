# Vocle (MedCollab) — Architect Status Update

**Date:** 2026-10-08  
**Audience:** Architecture / tech lead  
**Product UI:** Vocle · **Codebase / API:** MedCollab  
**Current app version:** `1.0.0+26`  
**Production API:** https://medcollab.up.railway.app  
**Health:** https://medcollab.up.railway.app/health  
**Latest release APK:** `D:\MedCollab\Vocle-beta.apk` (local artifact; not in git)  
**Primary remotes:** GitLab `origin` · GitHub `mathiharan29/medcollab-beta` (`master` → Railway)  
**Tip SHA (security waves):** `7a0ae10`

Supersedes the narrative in [`ARCHITECT_STATUS_UPDATE_2026-10-04.md`](ARCHITECT_STATUS_UPDATE_2026-10-04.md) for current status; keep the older file for history.

---

## 1. Where we are

Vocle remains a **closed-beta clinical messaging app** (interns / PGs / junior consultants). Stack and architecture are unchanged: REST persists, Socket.io broadcasts, `{ success, message, data }`, feature-folder backend, Railway from GitHub `master` / `medcollab-backend`.

**This week’s focus:** Needl UX polish + **security remediation Waves 1–3** from Sriram’s validation report (`docs/VOCLE_DEVELOPER_REMEDIATION_REPORT.md`).

| Layer | Status |
|-------|--------|
| Backend | Live; Waves 1–3 deployed to Railway via GitHub `master` |
| Android APK | `1.0.0+26` (Needl + auth/media client fixes) |
| Auth (MSG91 widget → JWT) | Hardened (no client JWT trust) |
| Push FCM | Live; notification reply spinner fixed client-side |
| Media Cloudinary | Live; PDF/video send path hardened |
| Security validation (Sriram) | Waves 1–3 fixed on upstream; Waves 4–8 remaining |

---

## 2. Shipped since 2026-10-04 snapshot

### Needl / Messages hub (`1.0.0+25` → `+26`)
- Needl tab = **group DMs** (not message threads); Direct = 1:1 only
- Expand/add people keeps multi-name titles; members list sheet
- Sender names visible in Needl chats
- Composer cleaned (bolt shortcuts removed)
- Phone lookup in Start DM / Needl add / global search hardened
- Multi-emoji reactions; reactor list on tap; atomic `@mention` backspace
- Notification shade reply re-posts MessagingStyle (stops infinite loading)

### Security remediation (backend) — Waves 1–3

| Wave | Theme | Commit |
|------|--------|--------|
| 1 | MSG91 provider verify; atomic OTP; video/PDF/octet typing | `77b6d2d` |
| 2 | Shared `channelAccess`; threads/handoffs/pins/drafts/media delete | `97d90fe` |
| 3 | Private fanout audience; Needl access filter; mention audience | `7a0ae10` |

Detail for security: [`SRIRAM_REMEDIATION_STATUS_2026-10-08.md`](SRIRAM_REMEDIATION_STATUS_2026-10-08.md).

---

## 3. Production / ops

| Item | State |
|------|--------|
| Railway | Redeploys from GitHub `master`; confirm `/health` after each wave push |
| Cloudinary | Prod cloud `denbnijqe`; PDF uses raw `secure_url` |
| MSG91 | Widget path must call provider verify (dummy/fabricated tokens denied) |
| Secrets | APK dart-defines + `google-services.json` stay out of git |

---

## 4. Open items

### P0 — Finish Sriram queue (ordered)
| Wave | Scope |
|------|--------|
| **4** | Socket revoke rooms, typing auth, null payload, recovery re-auth, deactivated sockets |
| **5** | Message-request notification enum + DM accept upsert (FUNC-01/02 — sanity still red) |
| **6–8** | Deleted-edit, media remainder, hardening/policy |

### P1 — Product / beta
| Open | Notes |
|------|--------|
| Device QA on `+26` | Needl, video, PDF open, phone search, reactions, notif reply |
| Cloudinary **test** cloud for Sriram CI | Still required — never prod keys in GHA |
| Pulse differentiator | Parked research |

### P2 — Platform
| Open | Notes |
|------|--------|
| Play Store applicationId | Still example id for beta |
| iOS | Out of closed beta |
| Owner attestations | Cloudinary / Atlas / release checklists (Sriram §15) |

---

## 5. Suggested near-term sequence

1. Install `1.0.0+26` APK; doctor smoke on Needl + media + search  
2. Sriram re-runs VOCLE suites for Waves 1–3 VR IDs against `7a0ae10+`  
3. Implement **Wave 4** realtime lifecycle  
4. **Wave 5** message-request functional sanity (unblocks 4 dependent scenarios)  
5. Isolated Cloudinary security cloud for CI  

---

## 6. Pointers

| Doc | Use |
|-----|-----|
| `docs/SRIRAM_REMEDIATION_STATUS_2026-10-08.md` | Security VR → commit map |
| `docs/VOCLE_DEVELOPER_REMEDIATION_REPORT.md` | Full findings |
| `PROJECT_LEAD_SUMMARY.md` | Lead-facing status |
| `AI_HANDOFF.md` | Agent / tech-lead handoff |
| `DEPLOYMENT.md` | Railway / APK |
| `PUSH_NOTIFICATIONS.md` | FCM |

---

**One-line status:**  
Vocle beta is live at `1.0.0+26` with Needl UX fixes and **security Waves 1–3** on Railway; remaining Sriram P1 work is realtime (Wave 4) and message-request functional failures (Wave 5).
