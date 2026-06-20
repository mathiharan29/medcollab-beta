# MedCollab — Project State

**Last updated:** 2026-06-20  
**Analyzer:** `flutter analyze` — no issues  
**Web build:** `flutter build web` — verified for Phase 5

---

## Phase status

| Phase | Status | Description |
|-------|--------|-------------|
| **1 — Foundation** | ✅ Complete | API client, socket, storage, theme, router |
| **2 — Auth UI** | ✅ Complete | Phone → OTP → profile → home |
| **3 — Core nav** | ✅ MVP | Spaces, channels, real-time channel chat |
| **4 — Threads** | ✅ MVP | Structured discussions per message |
| **5 — Rich comms** | ✅ MVP | Media, documents, message UX, members, search |
| **6 — Handoffs** | ⬜ Next | Killer feature + FCM |

---

## Phase 5 — Rich communication and media (MVP)

| Area | Component | Path |
|------|-----------|------|
| **Media** | `MediaRepository`, `MediaPickerService` | `features/media/` |
| | Image upload + bubbles + preview | `message_widgets.dart`, `image_preview_page.dart` |
| **Documents** | PDF/file attach + open via `url_launcher` | `message_widgets.dart` |
| **Message UX** | Timestamps, delivery state, sender grouping, date separators | `message_list_utils.dart`, `message_widgets.dart` |
| | Empty state, smart auto-scroll | `channel_chat_page.dart` |
| **Channels** | Create channel dialog (name, description, private) | `create_channel_dialog.dart` |
| | Channel search + member count | `space_detail_page.dart` |
| **Members** | Member list, profile sheet, presence | `space_members_page.dart`, `member_widgets.dart` |
| | Presence states (Available, Busy, In OT, Off Duty) | `presence_cubit.dart` |
| **Search** | Channel filter (client), member search (API) | `space_detail_page.dart`, `members_cubit.dart` |
| **State** | `ChannelRepository`, `MemberRepository`, `PresenceCubit` | `app_dependencies.dart` |

### Flow

1. **Attach** — composer `+` menu → gallery / camera / PDF → Cloudinary upload → image or document message
2. **Images** — thumbnail bubble → tap → full-screen pinch-zoom preview
3. **Documents** — file card bubble → tap → opens in browser / external app
4. **Messages** — grouped by sender, date chips, sending/sent/failed indicators
5. **Channels** — FAB create, search bar, description in list + chat app bar
6. **Members** — people icon on space → searchable list, profile sheet, presence chips

### Cloudinary (dev)

Set in `medcollab-backend/.env`:

```
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
```

Without credentials, media upload returns a server error; text chat still works.

---

## Phase 4 — Threaded discussions (MVP)

| Component | Path |
|-----------|------|
| `ThreadReplyPreview`, `ThreadDetail` | `features/messages/data/models/` |
| `MessageModel` (+ `threadId`, `replyCount`, `lastReply`, media fields) | `message_model.dart` |
| `ThreadRepository` | `features/messages/data/repositories/thread_repository.dart` |
| `ThreadCubit` | `features/messages/presentation/cubit/thread_cubit.dart` |
| `ThreadPage` | `thread_page.dart` |
| `MessageBubble`, `ThreadCountBadge`, `ParentMessagePreview` | `message_widgets.dart` |
| Channel thread badges + navigation | `channel_chat_page.dart` |

---

## Phase 3 — Core navigation (MVP)

| Component | Path |
|-----------|------|
| Spaces home / detail | `features/spaces/presentation/pages/` |
| Channel chat | `channel_chat_page.dart` |
| `SpaceRepository`, `MessageRepository` | `features/*/data/repositories/` |

---

## Run commands

**Backend:**
```powershell
cd D:\MedCollab\medcollab-backend
npm run dev
```

**Flutter Chrome:**
```powershell
cd D:\MedCollab\medcollab-app
flutter run -d chrome
```

Dev OTP: `123456`
