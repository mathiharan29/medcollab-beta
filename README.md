# MedCollab

Medical collaboration platform for hospital teams — Slack-like messaging built for Indian clinical workflows.

**GitLab:** https://gitlab.com/mathiharan-project/MedCollab

---

## Monorepo layout

```
MedCollab/
├── medcollab-app/       # Flutter client (iOS, Android, Web)
├── medcollab-backend/   # Node.js REST + Socket.io API
├── CLAUDE.md            # AI agent context (single source of truth)
└── .gitlab-ci.yml       # CI: analyze, test, web build
```

---

## Quick start

### Backend

```bash
cd medcollab-backend
cp .env.example .env   # JWT secrets only — MongoDB auto-starts in dev
npm install
npm run dev            # http://localhost:5000
```

No MongoDB Atlas needed for local dev — an in-memory database starts automatically.

Dev OTP: set `OTP_BYPASS=true` in `.env`, use **`123456`**.

### Flutter (Chrome)

```bash
cd medcollab-app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000
```

---

## Current status

| Component | Status |
|-----------|--------|
| Backend API | ✅ Complete (all controllers, socket, auth) |
| Flutter auth flow | ✅ Phone → OTP → profile → home + logout |
| Spaces / chat | ✅ MVP — spaces, channels, messages |
| Shift handoffs | ⬜ Phase 4 |

See [medcollab-app/PROJECT_STATE.md](medcollab-app/PROJECT_STATE.md) for detailed progress.

---

## Tech stack

| Layer | Stack |
|-------|--------|
| Mobile | Flutter, flutter_bloc, go_router, dio, socket_io_client |
| API | Node.js, Express, MongoDB Atlas, Socket.io |
| Auth | Phone OTP (MSG91) + JWT |
| Media | Cloudinary |
| Push | Firebase Cloud Messaging |

---

## CI/CD

GitLab CI runs on every push to `master`:

- `flutter analyze` + `flutter test`
- `flutter build web` (artifact)
- Backend syntax check

---

## Secrets (never commit)

- `medcollab-backend/.env`
- Firebase service account keys
- Cloudinary / MSG91 API keys

Configure in GitLab → **Settings → CI/CD → Variables** for deployment pipelines.

---

## License

Proprietary — Mathiharan Project.
