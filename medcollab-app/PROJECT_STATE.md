# MedCollab — Project State

**Last updated:** 2026-06-20  
**Analyzer:** `flutter analyze` — no issues  
**QA audit:** Staff Engineer / QA pass completed (reliability fixes applied)

---

## Phase status

| Phase | Status | Description |
|-------|--------|-------------|
| **1 — Foundation** | ✅ Complete | API client, socket, storage, theme, router |
| **2 — Auth UI** | ✅ Complete | Phone → OTP → profile → home |
| **3 — Core nav** | ✅ MVP | Spaces, channels, real-time channel chat |
| **4 — Threads** | ✅ MVP | Structured discussions per message |
| **5 — Rich comms** | ✅ MVP | Media, documents, message UX, members, search |
| **6 — Handoffs** | ✅ MVP | Clinical shift handover workflow |

---

## QA audit summary (2026-06-20)

### Fixes applied (bugs / reliability only)

| Area | Fix |
|------|-----|
| **Auth + socket** | JWT refresh now reconnects socket with new token; session expiry notifies `AuthBloc` |
| **Auth restore** | `getMe()` before socket connect; network errors allow session retry |
| **Message send** | Duplicate bubble race fixed (socket arrives before REST) |
| **Send errors** | Chat/thread cubits reset `isSending` on unexpected failures |
| **Token refresh** | Single-flight refresh prevents parallel 401 storms |
| **Handoffs reload** | Debounced socket-triggered list refresh |
| **Presence map** | Capped at 300 entries to limit memory growth |
| **Router** | `debugLogDiagnostics` only in debug builds |
| **Backend access** | Private/archived channel checks; socket `join_channel` membership guard |
| **Backend messages** | Message-by-id ops verify `channelId` matches URL |
| **Backend handoffs** | Atomic submit/acknowledge; received-status filter fix |
| **Backend search** | Regex input escaped (ReDoS mitigation) |

### Open improvements (not implemented — no new features)

| Priority | Item |
|----------|------|
| High | Refresh token rotation / server-side revocation |
| High | `connectionStateRecovery.skipMiddlewares` security review |
| Medium | App lifecycle socket reconnect on resume |
| Medium | Consume `message_updated` / `message_deleted` socket events in UI |
| Medium | Web tokens in `SharedPreferences` — XSS risk on web builds |
| Medium | Multi-instance: presence + rate limits need Redis before scale |
| Low | Message pagination (`hasMore`) in channel/thread UI |
| Low | `AppDependencies.dispose()` wiring on app exit |

---

## Phase 6 — Clinical shift handoffs (MVP)

| Component | Path |
|-----------|------|
| Models + repository | `features/handoffs/data/` |
| List / create / edit / detail | `features/handoffs/presentation/pages/` |
| Realtime list refresh | `handoffs_cubit.dart` |

**Flow:** Space → Shift handoffs → create draft → submit → assigned doctor acknowledges → archived.

---

## Phase 5 — Rich communication (MVP)

Media upload, documents, message UX polish, members, presence, channel search.

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
