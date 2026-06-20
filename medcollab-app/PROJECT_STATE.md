# MedCollab — Project State

**Last updated:** 2026-06-19  
**Analyzer:** `flutter analyze` — **No issues found**  
**Backend:** In-memory MongoDB in dev (no Atlas required)

---

## Phase status

| Phase | Status | Description |
|-------|--------|-------------|
| **1 — Foundation** | ✅ Complete | API client, socket, storage, theme, router |
| **2 — Auth UI** | ✅ Complete | Phone → OTP → profile → home |
| **3 — Core nav** | ✅ MVP | Spaces list, channels, real-time chat |
| **4 — Handoffs** | ⬜ Next | Killer feature + FCM |

---

## Phase 3 — Core navigation (MVP)

| Component | Path |
|-----------|------|
| `SpaceModel`, `ChannelModel` | `features/spaces/data/models/` |
| `MessageModel` | `features/messages/data/models/` |
| `SpaceRepository` | `features/spaces/data/repositories/` |
| `MessageRepository` | `features/messages/data/repositories/` |
| `ChannelChatCubit` | `features/messages/presentation/cubit/` |
| Spaces home (create/join) | `spaces_home_page.dart` |
| Space detail (channels) | `space_detail_page.dart` |
| Channel chat thread | `channel_chat_page.dart` |

### Flow

1. **Spaces home** — `GET /api/spaces`, create space, join via invite code  
2. **Space detail** — channel list with `#general`, `#emergency`, `#academics`  
3. **Channel chat** — load/send messages via REST, real-time via socket `new_message`

---

## Run commands

**Backend** (Terminal 1):
```powershell
cd D:\MedCollab\medcollab-backend
npm run dev
```

**Flutter Chrome** (Terminal 2):
```powershell
cd D:\MedCollab\medcollab-app
flutter run -d chrome
```

Dev OTP: `123456` (with `OTP_BYPASS=true`)

---

## Backend dev notes

- **No `MONGODB_URI` needed** — in-memory MongoDB starts automatically  
- Data resets when the server restarts  
- Avast users: `medcollab-backend/.npmrc` has `strict-ssl=false` for npm
