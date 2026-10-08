# MedCollab — Claude Code Context

## What this project is
Medical collaboration platform for doctors (**product UI name: Vocle**). Replacing WhatsApp for clinical communication. Slack-like, built for Indian hospital workflows.

## Repos & production (2026-08-02)

| | URL |
|---|-----|
| GitLab (primary dev) | https://gitlab.com/mathiharan-project/MedCollab |
| GitHub (Railway) | https://github.com/mathiharan29/medcollab-beta |
| **Production API** | **https://medcollab.up.railway.app** |
| Health | https://medcollab.up.railway.app/health |

**Beta: LIVE** — MongoDB Atlas + Railway Hobby + Cloudinary + MSG91 widget OTP + Firebase FCM + production APK (`1.0.0+26`).  
**Current focus:** Needl UX + Sriram security remediation (Waves 1–3 ✅ on `master`; Wave 4 realtime next). See `docs/ARCHITECT_STATUS_UPDATE_2026-10-08.md` and `docs/SRIRAM_REMEDIATION_STATUS_2026-10-08.md`.

**Railway deploys from GitHub `master` only** (root `medcollab-backend`). Design branches do not auto-deploy.

## Target users (beta)
MBBS interns, PG residents, junior consultants. Starting with ~15 doctors.

## Tech stack
- Backend: Node.js + Express + MongoDB Atlas + Socket.io on **Railway**
- Mobile: Flutter (flutter_bloc, dio, go_router, socket_io_client)
- Media: **Cloudinary** (cloud `denbnijqe` in production)
- Auth: Phone OTP (**MSG91 widget SDK**) + JWT
- Push: **Firebase Cloud Messaging (Android LIVE)**
- CI: GitLab CI; deploy via GitHub → Railway

## Project structure
```
medcollab-backend/   ← Node.js API (Railway root: medcollab-backend/)
medcollab-app/       ← Flutter client
DEPLOYMENT.md        ← Beta deploy guide + troubleshooting
PUSH_NOTIFICATIONS.md ← FCM Firebase + Railway setup
PROJECT_LEAD_SUMMARY.md ← Shareable project-lead status
```

## What is DONE

### Backend — complete + deployed
- All controllers, socket, auth, handoffs, media
- Sprint 8: DMs list, search, invite preview, notification unread/prefs
- Sprint 10: Firebase Admin FCM send (modular `firebase-admin/app`)
- Production on Railway; `/health` OK; logs `Firebase Admin connected`
- Realtime: JWT socket refresh, space rooms, presence snapshot

### Flutter — Phases 1–10
- Auth, spaces, channels, threads, media, members, presence, handoffs
- Sprint 7–8: Home shell, DMs, typing, drafts, invites, search, notif prefs
- Sprint 9: modular configurable Home
- Sprint 10: FCM client, local notifications, deep links, token lifecycle
- Vocle clinical UI redesign + QA polish

### Beta deployment
- ✅ MongoDB Atlas (`medcollab-beta` database)
- ✅ Railway Hobby (`medcollab.up.railway.app`)
- ✅ Cloudinary
- ✅ MSG91 widget OTP
- ✅ Firebase FCM (Android)
- ✅ Production APK (`scripts/build-release-apk.ps1` → `MedCollab-beta.apk`)

## Architecture — DO NOT change
- Feature-based backend folders
- API envelope: `{ success, message, data }`
- REST persists messages; socket broadcasts
- OTP bypass: `OTP_BYPASS=true` dev only; **blocked in production**

## Key docs
- `PROJECT_LEAD_SUMMARY.md` — share with project lead / ChatGPT
- `AI_HANDOFF.md` — tech lead + agent handoff
- `DEPLOYMENT.md` — deploy checklist, Railway, MSG91, APK
- `PUSH_NOTIFICATIONS.md` — FCM setup
- `medcollab-app/PROJECT_STATE.md` — detailed status
- `medcollab-backend/.env.example` — all env vars

## Local dev
```powershell
cd medcollab-backend && npm run dev   # OTP_BYPASS=true, OTP 123456
cd medcollab-app && flutter run -d chrome
```

## Design principles
Clinical, trustworthy; handoffs are the differentiator; no flashy animations.
