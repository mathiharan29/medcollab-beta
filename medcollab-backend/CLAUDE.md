# MedCollab Backend — Claude Code Context

## Production (2026-08-02)

| | |
|---|---|
| **API** | https://medcollab.up.railway.app |
| **Health** | https://medcollab.up.railway.app/health |
| **Deploy** | Railway Hobby via GitHub `mathiharan29/medcollab-beta` **`master`**, root `medcollab-backend` |
| **Database** | MongoDB Atlas `medcollab-beta` |
| **Media** | Cloudinary `denbnijqe` |
| **MSG91** | Widget OTP live (verify-msg91-token) |
| **FCM** | ✅ Firebase Admin connected (`FIREBASE_*` env) |

## What this project is
Medical collaboration API — Node.js + Express + MongoDB + Socket.io. Product UI name: **Vocle**.

## Tech stack
- Node.js + Express + MongoDB Atlas + Socket.io
- Cloudinary (production media)
- MSG91 OTP (widget)
- Firebase Admin (FCM push)
- Railway hosting

## What is DONE
- All models, controllers, routes, socket handlers
- Sprint 8: DMs, search, invite preview, notification unread/prefs
- Sprint 10: FCM send for messages / mentions / handoffs / emergency
- Modular Firebase init (`src/config/firebase.js` — `firebase-admin/app`)
- Production deploy on Railway with env validation
- Realtime: JWT socket refresh, space rooms, presence snapshot, handoff acknowledge events
- `nixpacks.toml`, `Procfile`, `scripts/validate-env.js`

## Architecture — DO NOT change
- Feature-based folders under `src/features/`
- API envelope: `{ success, message, data }`
- REST persists; socket broadcasts after save
- `OTP_BYPASS=true` dev only — **server exits if true in production**

## Platform admin (`/api/admin`)
- Separate from space owner/admin roles
- Allowlist: `ADMIN_USER_IDS` (comma-separated Mongo user ids)
- Portal: repo `vocle-admin/` (static, not public website)
- Doctor trust field: `isVerifiedDoctor` (distinct from phone OTP `isVerified`)

## Environment variables
See `.env.example`. Production requires:
- `MONGODB_URI`, `JWT_SECRET`, `JWT_REFRESH_SECRET`
- `API_BASE_URL=https://medcollab.up.railway.app`
- `CLOUDINARY_*`
- `MSG91_*` / widget verify path as configured
- `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`
- `OTP_BYPASS=false`

## Local dev
```powershell
copy .env.example .env   # OTP_BYPASS=true, empty MONGODB_URI
npm run dev              # in-memory MongoDB, OTP 123456
```

## Docs
- `../PROJECT_LEAD_SUMMARY.md` — shareable status
- `../PUSH_NOTIFICATIONS.md` — FCM setup
- `../DEPLOYMENT.md` — full beta guide
- `../medcollab-app/PROJECT_STATE.md` — project status
