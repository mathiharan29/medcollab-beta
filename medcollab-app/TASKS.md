# MedCollab Flutter — Task Tracker

## Phase 1 — Foundation ✅

| Task | Status | Notes |
|------|--------|-------|
| Study backend API contracts | ✅ Done | Routes, models, socket events inferred from `medcollab-backend-day2` |
| `pubspec.yaml` + dependencies | ✅ Done | flutter_bloc, dio, socket_io_client, flutter_secure_storage, go_router |
| Feature-first folder structure | ✅ Done | `lib/core`, `lib/features/auth`, `lib/shared` |
| `main.dart` + `app.dart` | ✅ Done | DI bootstrap, `MaterialApp.router` |
| Theme (clinical / trustworthy) | ✅ Done | Material 3, emergency accent colors |
| Router (`go_router`) | ✅ Done | Route constants + auth redirect stub (no feature screens) |
| Constants (API, socket, enums) | ✅ Done | Mirrors backend `src/constants/index.js` |
| API client (`dio`) | ✅ Done | Typed responses, auth interceptor, token refresh |
| Socket client | ✅ Done | JWT handshake, channel rooms, event streams |
| Secure storage service | ✅ Done | Access/refresh tokens, session persistence |
| Base repository | ✅ Done | `ApiResponse` parsing, error mapping |
| Auth models | ✅ Done | User, session, OTP request/response DTOs |
| Auth repository | ✅ Done | requestOtp, verifyOtp, refresh, logout |

## Phase 2 — Auth UI ✅

| Task | Status | Notes |
|------|--------|-------|
| `AuthBloc` + events/states | ✅ Done | Session restore, OTP, profile, logout |
| Splash screen | ✅ Done | Dispatches `AuthStarted` |
| Phone entry screen | ✅ Done | E.164 validation, loading, errors |
| OTP verification screen | ✅ Done | Resend, change phone |
| Profile setup screen | ✅ Done | Name, role, speciality, institution |
| Wire router redirect to auth state | ✅ Done | `GoRouterRefreshStream` |
| Persistent login | ✅ Done | Secure storage + `getMe` on launch |
| Logout | ✅ Done | API + local session clear |

## Phase 3 — Core navigation ✅ MVP

| Task | Status | Notes |
|------|--------|-------|
| Spaces list + create/join | ✅ Done | `SpacesHomePage` |
| Channel list per space | ✅ Done | `SpaceDetailPage` |
| Message thread + send | ✅ Done | `ChannelChatPage` + `ChannelChatCubit` |
| Socket real-time messages | ✅ Done | `new_message` listener |

## Phase 4 — Killer feature (next)

| Task | Status |
|------|--------|
| Handoff create / submit / acknowledge | ⬜ Pending |
| Push notifications (FCM) | ⬜ Pending |

## API contract reference (inferred)

### Response envelope
```json
{ "success": true, "message": "...", "data": { } }
{ "success": false, "message": "...", "errors": [ ] }
```

### Auth
- `POST /api/auth/request-otp` → `{ phone }` → `{ phone, expiresInMinutes }`
- `POST /api/auth/verify-otp` → `{ phone, otp }` → `{ accessToken, refreshToken, isNewUser, user }`
- `POST /api/auth/refresh` → `{ refreshToken }` → `{ accessToken }`
- `POST /api/auth/logout` → `{ fcmToken? }` (protected)

### Socket handshake
- URL: same host as API (no `/api` prefix)
- Auth: `{ token: accessToken }` in handshake
- Events: see `lib/core/constants/socket_events.dart`
