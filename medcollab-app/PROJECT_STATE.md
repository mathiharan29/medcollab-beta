# MedCollab — Project State

**Last updated:** 2026-06-20  
**Branch:** `design/clinical-design-system`  
**Phase:** Beta deployment preparation complete (not yet deployed)

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
| **Design system** | ✅ Complete | MedCollab tokens + shared components (clinical aesthetic) |
| **Beta deployment prep** | ✅ Ready | Checklist + scripts — see `DEPLOYMENT.md` |

---

## Beta deployment readiness (2026-06-20)

**Guide:** [`DEPLOYMENT.md`](../DEPLOYMENT.md) at repo root — full checklist with exact commands.

### Backend — production ready

| Area | Status | Notes |
|------|--------|-------|
| MongoDB Atlas | ✅ Ready | `MONGODB_URI` required when `NODE_ENV=production` |
| In-memory MongoDB | ✅ Dev only | `mongodb-memory-server` in devDependencies; blocked in prod |
| Cloudinary | ✅ Ready | Required for beta media; local disk fallback dev-only |
| Socket.io | ✅ Ready | Same port as HTTP; JWT auth; space room sync |
| CORS | ✅ Ready | Mobile unaffected; web needs `ALLOWED_ORIGINS` |
| Env validation | ✅ Ready | `scripts/validate-env.js`; OTP_BYPASS blocked in prod |
| Trust proxy | ✅ Ready | Enabled for Railway rate limiting |
| Health check | ✅ Ready | `GET /health` |
| Startup scripts | ✅ Ready | `scripts/start-production.ps1` / `.sh`, `Procfile`, `railway.json` |

### Flutter — production ready

| Area | Status | Notes |
|------|--------|-------|
| Env config | ✅ Ready | `--dart-define=API_BASE_URL` (required for release APK) |
| Socket URL | ✅ Ready | Optional `--dart-define=SOCKET_URL`; defaults to API host |
| Android INTERNET | ✅ Ready | Permission in main manifest |
| Release build script | ✅ Ready | `scripts/build-release-apk.ps1` |
| Release signing | ⚠️ Beta only | Still uses debug keystore — OK for internal beta |
| App ID | ⚠️ Placeholder | `com.example.medcollab_app` — change before Play Store |
| FCM client | ❌ Pending | Backend ready; Flutter not integrated |

### External services required for beta

1. **MongoDB Atlas** — persistent database
2. **Railway** — API hosting
3. **Cloudinary** — media storage (do not rely on Railway disk)
4. **MSG91** — OTP SMS (disable `OTP_BYPASS`)
5. **Firebase** — optional (push notifications)

---

## Design system (2026-06-18)

**Personality:** Calm · Professional · Premium · Trustworthy · Clinical  
**Constraints:** No gradients · Border-first surfaces · 48px touch targets

| Token | Hex |
|-------|-----|
| Primary Teal | `#0F766E` |
| Primary Container | `#CCFBF1` |
| Secondary Slate | `#1E293B` |
| Accent Amber | `#F59E0B` |
| Background | `#F8FAFC` |

Theme files: `lib/core/theme/` · Shared widgets: `lib/shared/presentation/widgets/`

---

## Reliability fixes (2026-06-20)

| Area | Fix |
|------|-----|
| **Socket + JWT** | Token refresh recreates socket with new JWT; auto-recover on disconnect |
| **Chat realtime** | Channel rejoin + silent message reload on reconnect |
| **Presence** | Snapshot on `sync_space_rooms`; monotonic merge; self-online when connected |
| **Handoffs** | `handoff_acknowledged` socket; navigation pop preserves back stack |
| **App lifecycle** | Socket reconnect on app resume |

---

## Open items (post-beta)

| Priority | Item |
|----------|------|
| High | Deploy to Railway + Atlas + Cloudinary (follow `DEPLOYMENT.md`) |
| High | Release keystore + real application ID for Play Store |
| High | Refresh token rotation / server-side revocation |
| Medium | FCM push integration in Flutter |
| Medium | App logo → launcher icon + splash |
| Medium | Redis for multi-instance presence/rate limits |
| Low | Message pagination UI (`hasMore`) |

---

## Run commands

### Local development

```powershell
# Backend (in-memory MongoDB, OTP bypass)
cd medcollab-backend
copy .env.example .env   # set OTP_BYPASS=true, leave MONGODB_URI empty
npm run dev

# Flutter Chrome
cd medcollab-app
flutter run -d chrome
```

Dev OTP when `OTP_BYPASS=true`: **123456**

### Production validation

```powershell
cd medcollab-backend
node scripts/validate-env.js
```

### Beta APK build

```powershell
cd medcollab-app
.\scripts\build-release-apk.ps1 -ApiBaseUrl "https://YOUR-API.up.railway.app"
```

See [`DEPLOYMENT.md`](../DEPLOYMENT.md) for the full deploy checklist.
