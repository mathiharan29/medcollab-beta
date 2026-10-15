# MedCollab

Medical collaboration platform for hospital teams — Slack-like messaging built for Indian clinical workflows.

| Resource | URL |
|----------|-----|
| **GitLab (primary)** | https://gitlab.com/mathiharan-project/MedCollab |
| **GitHub (Railway deploy)** | https://github.com/mathiharan29/medcollab-beta |
| **Production API** | https://medcollab.up.railway.app |
| **Health check** | https://medcollab.up.railway.app/health |

---

## Monorepo layout

```
MedCollab/
├── medcollab-app/              # Flutter client (iOS, Android, Web)
├── medcollab-backend/          # Node.js REST + Socket.io API
├── vocle-admin/                # Internal ops admin portal (separate from public site)
├── PROJECT_LEAD_SUMMARY.md     # Shareable project-lead status
├── AI_HANDOFF.md               # Tech handoff
├── PUSH_NOTIFICATIONS.md       # FCM setup
├── DEPLOYMENT.md               # Beta deploy guide
├── CLAUDE.md                   # AI agent context
└── .gitlab-ci.yml              # CI: analyze, test, web build
```

---

## Quick start (local)

### Backend

```powershell
cd medcollab-backend
copy .env.example .env   # OTP_BYPASS=true, leave MONGODB_URI empty
npm install
npm run dev              # http://localhost:5000
```

In-memory MongoDB starts automatically in dev. OTP: **`123456`** when `OTP_BYPASS=true`.

### Flutter (Chrome)

```powershell
cd medcollab-app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
```

### Flutter (production API)

```powershell
flutter run --dart-define=API_BASE_URL=https://medcollab.up.railway.app
```

*Login uses MSG91 OTP widget on production (`OTP_BYPASS=false`).*

### Admin portal (internal)

Separate from any public website. See [`vocle-admin/README.md`](vocle-admin/README.md).

```powershell
cd medcollab-backend   # set ADMIN_USER_IDS + ALLOWED_ORIGINS=...,http://localhost:5173
npm run dev
cd ..\vocle-admin
python -m http.server 5173   # http://localhost:5173
```

---

## Current status (2026-08-02)

| Component | Status |
|-----------|--------|
| Backend API (Railway) | ✅ Live — Atlas + Cloudinary + Sprint 8 APIs + FCM |
| Flutter app | ✅ Sprint 10 — Vocle UX, DMs, handoffs, search, **Android push** |
| MSG91 OTP | ✅ Widget SDK + API verify |
| Production APK | ✅ `D:\MedCollab\MedCollab-beta.apk` (~56 MB, FCM) |
| FCM push | ✅ LIVE (Android QA-confirmed) |

Share with project lead: [PROJECT_LEAD_SUMMARY.md](PROJECT_LEAD_SUMMARY.md).  
Also: [medcollab-app/PROJECT_STATE.md](medcollab-app/PROJECT_STATE.md), [AI_HANDOFF.md](AI_HANDOFF.md), [PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md), [DEPLOYMENT.md](DEPLOYMENT.md).

---

## Tech stack

| Layer | Stack |
|-------|--------|
| Mobile | Flutter, flutter_bloc, go_router, dio, socket_io_client |
| API | Node.js, Express, MongoDB Atlas, Socket.io |
| Hosting | Railway (production), local dev |
| Auth | Phone OTP (MSG91) + JWT |
| Media | Cloudinary |
| Push | Firebase Cloud Messaging (Android LIVE) |

---

## CI/CD

GitLab CI on push to `master`: `flutter analyze`, `flutter test`, `flutter build web`, backend syntax check.

GitHub `medcollab-beta` is mirrored for Railway auto-deploy.

---

## Secrets (never commit)

- `medcollab-backend/.env`
- Railway / Atlas / Cloudinary / MSG91 credentials
- Firebase service account keys

---

## License

Proprietary — Mathiharan Project.
