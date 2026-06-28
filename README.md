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
├── medcollab-app/       # Flutter client (iOS, Android, Web)
├── medcollab-backend/   # Node.js REST + Socket.io API
├── DEPLOYMENT.md        # Beta deploy guide (start here for production)
├── CLAUDE.md            # AI agent context
└── .gitlab-ci.yml       # CI: analyze, test, web build
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

*Login requires MSG91 OTP on production (`OTP_BYPASS=false`).*

---

## Current status (2026-06-28)

| Component | Status |
|-----------|--------|
| Backend API (local) | ✅ Complete |
| **Backend API (Railway)** | ✅ **Live** — Atlas + Cloudinary |
| Flutter app (features) | ✅ MVP — auth, chat, media, handoffs, presence |
| **MSG91 OTP (production)** | ⏳ MSG91 dashboard IP blocked at signup |
| **Flutter production APK** | ⬜ Pending MSG91 |

See [medcollab-app/PROJECT_STATE.md](medcollab-app/PROJECT_STATE.md) and [DEPLOYMENT.md](DEPLOYMENT.md).

---

## Tech stack

| Layer | Stack |
|-------|--------|
| Mobile | Flutter, flutter_bloc, go_router, dio, socket_io_client |
| API | Node.js, Express, MongoDB Atlas, Socket.io |
| Hosting | Railway (production), local dev |
| Auth | Phone OTP (MSG91) + JWT |
| Media | Cloudinary |
| Push | Firebase (optional, not configured) |

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
