# MedCollab Backend — Claude Code Context

## Production (2026-06-28)

| | |
|---|---|
| **API** | https://medcollab.up.railway.app |
| **Health** | https://medcollab.up.railway.app/health |
| **Deploy** | Railway via GitHub `mathiharan29/medcollab-beta`, root `medcollab-backend` |
| **Database** | MongoDB Atlas `medcollab-beta` |
| **Media** | Cloudinary `denbnijqe` |
| **MSG91** | Not configured — dashboard IP blocked at signup |

## What this project is
Medical collaboration API — Node.js + Express + MongoDB + Socket.io.

## Tech stack
- Node.js + Express + MongoDB Atlas + Socket.io
- Cloudinary (production media)
- MSG91 OTP (pending)
- Railway hosting

## What is DONE
- All models, controllers, routes, socket handlers
- Production deploy on Railway with env validation
- Realtime: JWT socket refresh, space rooms, presence snapshot, handoff acknowledge events
- `nixpacks.toml`, `Procfile`, `scripts/validate-env.js`

## Architecture — DO NOT change
- Feature-based folders under `src/features/`
- API envelope: `{ success, message, data }`
- REST persists; socket broadcasts after save
- `OTP_BYPASS=true` dev only — **server exits if true in production**

## Environment variables
See `.env.example`. Production requires:
- `MONGODB_URI`, `JWT_SECRET`, `JWT_REFRESH_SECRET`
- `API_BASE_URL=https://medcollab.up.railway.app`
- `CLOUDINARY_*`
- `MSG91_AUTH_KEY`, `MSG91_TEMPLATE_ID` (when MSG91 works)
- `OTP_BYPASS=false`

## Local dev
```powershell
copy .env.example .env   # OTP_BYPASS=true, empty MONGODB_URI
npm run dev              # in-memory MongoDB, OTP 123456
```

## Docs
- `../DEPLOYMENT.md` — full beta guide
- `../medcollab-app/PROJECT_STATE.md` — project status
