# MedCollab — Project State

**Last updated:** 2026-06-20  
**Analyzer:** `flutter analyze` — no issues  
**Web build:** `flutter build web` — verified through Phase 5

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

## Phase 6 — Clinical shift handoffs (MVP)

| Area | Component | Path |
|------|-----------|------|
| **Models** | `HandoffModel`, `HandoffPatientModel` | `features/handoffs/data/models/` |
| **Repository** | CRUD + submit + acknowledge | `handoff_repository.dart` |
| **State** | `HandoffsCubit`, `HandoffFormCubit` | `presentation/cubit/` |
| **List** | Search, Active/Archived tabs, priority colours | `handoffs_list_page.dart` |
| **Create/Edit** | Assigned doctor, patients, shift context | `handoff_form_page.dart` |
| **Detail** | View, edit draft, acknowledge, delete draft | `handoff_detail_page.dart` |
| **Realtime** | Socket `new_message` (type `handoff`) refreshes list | `handoffs_cubit.dart` |
| **Navigation** | Space card + app bar → `/spaces/:id/handoffs` | `space_detail_page.dart` |

### Handoff fields (patient-level)

| Field | Source |
|-------|--------|
| Patient identifier | `bedNumber` + `ward` + `clinicalAlias` (no PHI) |
| Diagnosis | `diagnosis` |
| Current status | `PatientStatus` |
| Pending tasks | `pendingTasks[]` |
| Assigned doctor | `toUser` on handoff |
| Priority | `isFlagged` + status → colour accent |
| Last updated | `updatedAt` / `submittedAt` |

### Flow

1. **Space** → **Shift handoffs** card or app bar icon
2. **List** — search by bed, diagnosis, doctor; filter Active vs Archived
3. **Create** — pick assigned doctor, add patients, save draft or submit
4. **Edit** — draft only (sender)
5. **Archive** — delete draft, or receiver acknowledges submitted handoff
6. **Realtime** — submit/ack posts `handoff` system message; list auto-refreshes

### API (existing backend)

- `POST /api/handoffs` — create draft
- `PUT /api/handoffs/:id` — edit draft
- `POST /api/handoffs/:id/submit` — send to assigned doctor
- `POST /api/handoffs/:id/acknowledge` — receiver archives
- `DELETE /api/handoffs/:id` — delete draft
- `GET /api/spaces/:spaceId/handoffs` — space history
- `GET /api/handoffs` — personal inbox + drafts

---

## Phase 5 — Rich communication and media (MVP)

| Area | Component | Path |
|------|-----------|------|
| **Media** | `MediaRepository`, `MediaPickerService` | `features/media/` |
| **Documents** | PDF/file attach + open | `message_widgets.dart` |
| **Message UX** | Grouping, dates, delivery state | `message_list_utils.dart` |
| **Members** | List, profile, presence | `features/members/` |

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
