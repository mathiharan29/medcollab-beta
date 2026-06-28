# MedCollab — Claude Code Context

## What this project is
Medical collaboration platform for doctors. Replacing WhatsApp for clinical communication. Slack-like, built for Indian hospital workflows.

## Repos & production (2026-06-28)

| | URL |
|---|-----|
| GitLab (primary dev) | https://gitlab.com/mathiharan-project/MedCollab |
| GitHub (Railway) | https://github.com/mathiharan29/medcollab-beta |
| **Production API** | **https://medcollab.up.railway.app** |
| Health | https://medcollab.up.railway.app/health |

**Beta backend: LIVE** — MongoDB Atlas + Railway + Cloudinary configured.  
**MSG91: BLOCKED** — user cannot access msg91.com dashboard (IP blocked at signup). Production login needs MSG91 vars on Railway.

## Target users (beta)
MBBS interns, PG residents, junior consultants. Starting with ~15 doctors.

## Tech stack
- Backend: Node.js + Express + MongoDB Atlas + Socket.io on **Railway**
- Mobile: Flutter (flutter_bloc, dio, go_router, socket_io_client)
- Media: **Cloudinary** (cloud `denbnijqe` in production)
- Auth: Phone OTP (**MSG91**) + JWT — MSG91 pending
- Push: Firebase (optional, not configured)
- CI: GitLab CI; deploy via GitHub → Railway

## Project structure
```
medcollab-backend/   ← Node.js API (Railway root: medcollab-backend/)
medcollab-app/       ← Flutter client
DEPLOYMENT.md        ← Beta deploy guide + troubleshooting
```

## What is DONE

### Backend — complete + deployed
- All controllers, socket, auth, handoffs, media
- Production on Railway; `/health` OK
- Realtime fixes: JWT socket refresh, space rooms, presence snapshot

### Flutter — Phases 1–6 MVP + design system
- Auth, spaces, channels, threads, media, members, presence, handoffs
- Clinical design system (teal/slate, no gradients)

### Beta deployment
- ✅ MongoDB Atlas (`medcollab-beta` database)
- ✅ Railway (`medcollab.up.railway.app`)
- ✅ Cloudinary
- ⏳ MSG91 (dashboard access blocked)
- ⬜ Production APK

## Architecture — DO NOT change
- Feature-based backend folders
- API envelope: `{ success, message, data }`
- REST persists messages; socket broadcasts
- OTP bypass: `OTP_BYPASS=true` dev only; **blocked in production**

## Key docs
- `DEPLOYMENT.md` — deploy checklist, Railway, MSG91, APK
- `medcollab-app/PROJECT_STATE.md` — detailed status
- `medcollab-backend/.env.example` — all env vars

## Local dev
```powershell
cd medcollab-backend && npm run dev   # OTP_BYPASS=true, OTP 123456
cd medcollab-app && flutter run -d chrome
```

## Design principles
Clinical, trustworthy; handoffs are the differentiator; no flashy animations.
