# MedCollab Flutter — Task Tracker

## Phase 1 — Foundation ✅

| Task | Status | Notes |
|------|--------|-------|
| Study backend API contracts | ✅ Done | Routes, models, socket events inferred from backend |
| `pubspec.yaml` + dependencies | ✅ Done | flutter_bloc, dio, socket_io_client, go_router |
| Feature-first folder structure | ✅ Done | `lib/core`, `lib/features/*`, `lib/shared` |
| `main.dart` + `app.dart` | ✅ Done | DI bootstrap, `MaterialApp.router` |
| Theme (clinical / trustworthy) | ✅ Done | Material 3, emergency accent colors |
| Router (`go_router`) | ✅ Done | Route constants + auth redirect |
| Constants (API, socket, enums) | ✅ Done | Mirrors backend `src/constants/index.js` |
| API client (`dio`) | ✅ Done | Typed responses, auth interceptor, multipart upload |
| Socket client | ✅ Done | JWT handshake, channel rooms, presence events |
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

## Phase 4 — Threaded discussions ✅ MVP

| Task | Status | Notes |
|------|--------|-------|
| Thread models + repository | ✅ Done | `ThreadDetail`, `ThreadRepository` |
| Thread screen + reply UI | ✅ Done | `ThreadPage`, `ThreadCubit` |
| Parent preview + reply badge | ✅ Done | `message_widgets.dart` |
| Channel integration | ✅ Done | `MessageBubble`, thread route |
| Realtime thread updates | ✅ Done | Socket `new_message` + `threadId` |

## Phase 5 — Rich communication and media ✅ MVP

| Task | Status | Notes |
|------|--------|-------|
| Image upload (Cloudinary) | ✅ Done | `MediaRepository` + backend `POST /api/media/upload` |
| Gallery picker + camera capture | ✅ Done | `image_picker`, `MediaPickerService` |
| Image message bubbles + preview | ✅ Done | `cached_network_image`, pinch-zoom |
| PDF / file attachments | ✅ Done | `file_picker`, document bubbles |
| Download / open attachments | ✅ Done | `url_launcher` |
| Timestamps + delivery state | ✅ Done | Sending / sent / failed indicators |
| Sender grouping + date separators | ✅ Done | `message_list_utils.dart` |
| Empty state + auto-scroll | ✅ Done | Smart scroll when near bottom |
| Long message wrapping | ✅ Done | `softWrap` on text bubbles |
| Custom channel creation UI | ✅ Done | `CreateChannelDialog` |
| Channel description + member count | ✅ Done | `SpaceDetailPage` |
| Channel search | ✅ Done | Client-side filter |
| Space member list | ✅ Done | `SpaceMembersPage` |
| User profile card | ✅ Done | `UserProfileSheet` |
| Online/offline + presence states | ✅ Done | `PresenceCubit`, socket `presence_update` |
| Search members | ✅ Done | API `GET /api/users/search` + local filter |
| `ChannelRepository`, `MemberRepository` | ✅ Done | Wired in `AppDependencies` |

## Phase 6 — Clinical handoffs ✅ MVP

| Task | Status | Notes |
|------|--------|-------|
| Handoff create / submit / acknowledge | ✅ Done | Realtime via socket |
| Push notifications (FCM) | ⬜ Pending | Backend ready |

## Phase 7 — Beta deployment (2026-06-28)

| Task | Status | Notes |
|------|--------|-------|
| MongoDB Atlas | ✅ Live | `medcollab-beta` DB |
| Railway API | ✅ Live | https://medcollab.up.railway.app |
| Cloudinary | ✅ Live | Production media |
| GitHub mirror for Railway | ✅ Done | mathiharan29/medcollab-beta |
| MSG91 OTP | ⏳ Blocked | MSG91 website IP block at signup |
| Production APK | ⬜ Pending | `scripts/build-release-apk.ps1` |

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

### Media
- `POST /api/media/upload` (multipart `file`) → `{ url, thumbnailUrl, publicId, fileName, mimeType, ... }`

### Socket handshake
- URL: same host as API (no `/api` prefix)
- Auth: `{ token: accessToken }` in handshake
- Events: see `lib/core/constants/socket_events.dart`
