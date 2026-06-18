# MedCollab — Project State

**Last updated:** 2026-06-18  
**Analyzer:** `flutter analyze` — **No issues found**  
**Web build:** `flutter build web` — **OK**

---

## Repository layout

```
MedCollab/   (GitLab: mathiharan-project/MedCollab)
├── medcollab-backend/   # Node.js API
└── medcollab-app/       # Flutter client
```

---

## Flutter app — phase status

| Phase | Status | Description |
|-------|--------|-------------|
| **1 — Foundation** | ✅ Complete | API client, socket, storage, theme, router shell |
| **2 — Auth UI** | ✅ Complete | Full phone → OTP → profile → home flow |
| **3 — Core nav** | ⬜ Next | Spaces, channels, real-time chat |
| **4 — Handoffs** | ⬜ Pending | Killer feature + FCM |

---

## Phase 2 — Authentication (complete)

### Implemented

| Component | Path |
|-----------|------|
| `AuthBloc` / events / state | `lib/features/auth/presentation/bloc/` |
| Splash (session restore) | `splash_page.dart` |
| Phone entry | `phone_entry_page.dart` |
| OTP verification | `otp_verification_page.dart` |
| Profile setup | `profile_setup_page.dart` |
| Home + logout | `home_page.dart` |
| `UserRepository` | `getMe`, `updateMe` |
| Router + auth redirects | `app_router.dart` + `GoRouterRefreshStream` |

### Auth flow

1. **Splash** → `AuthStarted` → check secure storage for refresh token  
2. **Has session** → `GET /api/users/me` → home or profile setup  
3. **No session** → phone entry → `POST /api/auth/request-otp`  
4. **OTP** → `POST /api/auth/verify-otp` → tokens saved, socket connected  
5. **New user / incomplete profile** → profile setup → `PUT /api/users/me`  
6. **Home** → logout → `POST /api/auth/logout` + clear storage  

### Validation

- Phone: 10-digit Indian mobile (6–9 prefix) → E.164 `+91…`
- OTP: 6 digits
- Profile: name ≥ 2 chars, role required

### Persistent login

- Access + refresh tokens in `flutter_secure_storage`
- App restart restores session via `AuthStarted` + `getMe`
- Silent token refresh via `AuthInterceptor` on 401

---

## Run commands

```bash
cd medcollab-app
flutter pub get
flutter analyze

# Chrome (backend on localhost)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000

# Web production build
flutter build web --dart-define=API_BASE_URL=http://localhost:5000
```

**Backend dev tip:** set `OTP_BYPASS=true` and use OTP `123456`.

---

## Android build note

Gradle SSL (Avast HTTPS scanning) may block Android builds. Chrome/web works without Gradle. See `android/setup_gradle_truststore.ps1` if needed.

---

## Next action

**Phase 3:** Spaces list, channel navigation, real-time messaging.

See [TASKS.md](TASKS.md)
