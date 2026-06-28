# MedCollab — Project State

**Last updated:** 2026-06-28  
**Production API:** https://medcollab.up.railway.app  
**Health:** https://medcollab.up.railway.app/health  
**GitHub (Railway deploy):** https://github.com/mathiharan29/medcollab-beta  
**GitLab (primary):** https://gitlab.com/mathiharan-project/MedCollab  
**Active branch:** `design/clinical-design-system` / `master` (synced on GitHub)

---

## Beta deployment status (live)

| Service | Status | Notes |
|---------|--------|-------|
| **MongoDB Atlas** | ✅ Live | Cluster `medcollab-beta`, DB `medcollab-beta`, Network Access `0.0.0.0/0` |
| **Railway API** | ✅ Live | `https://medcollab.up.railway.app` — `/health` returns `database: connected` |
| **Cloudinary** | ✅ Live | Cloud `denbnijqe` — logs show `Cloudinary configured` |
| **Socket.io** | ✅ Live | Same host as API; space room sync on connect |
| **MSG91 OTP** | ⏳ In progress | Dashboard access via mobile data; add Auth Key + Template on Railway |
| **Firebase push** | ⬜ Optional | Not configured (warnings only) |
| **Flutter production APK** | ⬜ Pending | Waiting on MSG91 or temporary auth workaround |

### Railway configuration (working)

| Setting | Value |
|---------|--------|
| Root Directory | `medcollab-backend` |
| Branch | `master` |
| Build | `nixpacks.toml` → `npm ci --omit=dev` |
| Start | `node src/server.js` |
| Port | `8080` (Railway `PORT`) |
| Bind | `0.0.0.0` |

### Railway env vars set (no secrets in this doc)

- `NODE_ENV=production`
- `API_BASE_URL=https://medcollab.up.railway.app`
- `MONGODB_URI` (Atlas)
- `JWT_SECRET`, `JWT_REFRESH_SECRET`
- `OTP_BYPASS=false`
- `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`
- `MSG91_*` — **not yet** (MSG91 account access blocked)

---

## Phase status (product)

| Phase | Status | Description |
|-------|--------|-------------|
| **1 — Foundation** | ✅ Complete | API client, socket, storage, theme, router |
| **2 — Auth UI** | ✅ Complete | Phone → OTP → profile → home |
| **3 — Core nav** | ✅ MVP | Spaces, channels, real-time channel chat |
| **4 — Threads** | ✅ MVP | Structured discussions per message |
| **5 — Rich comms** | ✅ MVP | Media, documents, members, presence |
| **6 — Handoffs** | ✅ MVP | Create, submit, acknowledge, realtime list |
| **Design system** | ✅ Complete | Clinical tokens + shared widgets |
| **Beta backend deploy** | ✅ Live | Railway + Atlas + Cloudinary |
| **Beta mobile deploy** | ⬜ Next | APK + MSG91 OTP |

---

## Reliability fixes (2026-06-20 → 2026-06-28)

| Area | Fix |
|------|-----|
| Socket + JWT | Token refresh recreates socket; auto-recover on disconnect |
| Chat / handoffs realtime | Channel rejoin + reload on reconnect |
| Presence | `sync_space_rooms` snapshot; monotonic merge; `0.0.0.0` bind |
| Handoffs navigation | `context.pop` preserves back stack |
| Railway monorepo | `medcollab-backend/nixpacks.toml`; removed root `railway.toml` |
| GitHub mirror | `mathiharan29/medcollab-beta` for Railway (GitLab has no Railway integration) |

---

## MSG91 blocker (current)

**Problem:** IP blocked while signing up / logging into **msg91.com** (not MedCollab).

**Try:**

1. Wait **20 hours** (MSG91 auto-unblocks throttle IPs)
2. Use **mobile hotspot** or different network (new IP)
3. Email **support@msg91.com** — ask to unblock IP for signup
4. If old account exists (used last year): try **password reset** instead of new signup
5. After login: Settings → User Profile → **Blocked IP List** → remove your IP

See [`DEPLOYMENT.md`](../DEPLOYMENT.md) § MSG91 for integration steps once dashboard access works.

---

## Open items

| Priority | Item |
|----------|------|
| **Now** | Unblock MSG91 account → Auth Key + Template ID → Railway vars |
| High | Build release APK: `.\scripts\build-release-apk.ps1 -ApiBaseUrl "https://medcollab.up.railway.app"` |
| High | Rotate Cloudinary API secret (was shared in chat) |
| Medium | FCM push in Flutter |
| Medium | Release keystore + real app ID (`com.example.medcollab_app`) |
| Low | Redis for multi-instance presence/rate limits |
| Low | Fix mongoose duplicate `inviteCode` index warning |

---

## Run commands

### Local dev

```powershell
cd medcollab-backend
copy .env.example .env   # OTP_BYPASS=true, leave MONGODB_URI empty
npm run dev

cd medcollab-app
flutter run -d chrome
```

Dev OTP: **123456** when `OTP_BYPASS=true`

### Production health check

```text
https://medcollab.up.railway.app/health
```

### Beta APK (after MSG91 or auth workaround)

```powershell
cd medcollab-app
.\scripts\build-release-apk.ps1 -ApiBaseUrl "https://medcollab.up.railway.app"
```

Full guide: [`DEPLOYMENT.md`](../DEPLOYMENT.md)
