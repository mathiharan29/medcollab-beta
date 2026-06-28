# MedCollab — Beta Deployment Guide

**Phase:** External beta — **backend LIVE**  
**Production API:** https://medcollab.up.railway.app  
**Last updated:** 2026-06-28

---

## Beta progress (what’s done)

| Step | Status |
|------|--------|
| MongoDB Atlas cluster `medcollab-beta` | ✅ |
| Railway deploy from GitHub `mathiharan29/medcollab-beta` | ✅ |
| `/health` → `"database": "connected"` | ✅ |
| Cloudinary (`denbnijqe`) | ✅ |
| `API_BASE_URL` on Railway | ✅ Set to production URL |
| MSG91 OTP SMS | ⏳ **In progress** — dashboard OK (use mobile data on home Wi‑Fi if blocked); add keys to Railway |
| Flutter production APK | ⬜ Pending MSG91 |

**Repos:**

- **GitHub (Railway):** https://github.com/mathiharan29/medcollab-beta  
- **GitLab (primary dev):** https://gitlab.com/mathiharan-project/MedCollab  

Push to both after changes: `git push origin branch` and `git push github branch`

---

## Architecture overview

```
┌─────────────────┐     HTTPS/WSS      ┌──────────────────────────────┐
│  Flutter APK    │ ◄────────────────► │  Railway (Node.js API)       │
│  (dart-define)  │                    │  Express + Socket.io         │
└─────────────────┘                    └──────────┬───────────────────┘
                                                  │
                    ┌─────────────────────────────┼─────────────────────┐
                    ▼                             ▼                     ▼
            MongoDB Atlas                  Cloudinary              MSG91 (OTP)
            (persistent DB)                (media CDN)             (SMS)
```

---

## Pre-deploy checklist

### Backend

- [x] `NODE_ENV=production` set on Railway
- [x] `MONGODB_URI` points to MongoDB Atlas
- [x] `JWT_SECRET` and `JWT_REFRESH_SECRET` set
- [x] `OTP_BYPASS=false`
- [ ] `MSG91_AUTH_KEY` and `MSG91_TEMPLATE_ID` configured — **blocked: MSG91 dashboard IP**
- [x] Cloudinary credentials configured
- [x] `API_BASE_URL=https://medcollab.up.railway.app`
- [ ] `ALLOWED_ORIGINS` — only needed for Flutter web
- [ ] Firebase credentials (optional)
- [x] Health check returns 200: `GET /health`

### MongoDB Atlas

- [x] Cluster created (M0 free tier)
- [x] Database user configured
- [x] Network access: `0.0.0.0/0` (beta)
- [x] Connection string uses `/medcollab-beta` database name

### Flutter mobile

- [ ] Production API URL known (Railway HTTPS, no trailing slash)
- [ ] Release APK built with `--dart-define=API_BASE_URL=...`
- [ ] `INTERNET` permission in Android manifest (included in repo)
- [ ] APK tested on a **physical phone** (not emulator defaults)
- [ ] OTP login works with real MSG91 SMS

---

## 1. MongoDB Atlas setup

1. Create account at [mongodb.com/atlas](https://www.mongodb.com/atlas)
2. Create a **free M0 cluster**
3. **Database Access** → Add user (password auth)
4. **Network Access** → Add IP `0.0.0.0/0` (beta) or Railway static IP
5. **Connect** → Drivers → copy connection string:
   ```
   mongodb+srv://USER:PASSWORD@cluster0.xxxxx.mongodb.net/medcollab?retryWrites=true&w=majority
   ```
6. Set as `MONGODB_URI` on Railway

**Local dev:** Leave `MONGODB_URI` empty → in-memory MongoDB starts automatically (dev only).

**Production:** `mongodb-memory-server` is a **devDependency** — not installed with `npm ci --omit=dev`. Production **requires** Atlas.

---

## 2. Cloudinary setup

1. Create account at [cloudinary.com](https://cloudinary.com)
2. Dashboard → copy **Cloud name**, **API Key**, **API Secret**
3. Set on Railway:
   ```
   CLOUDINARY_CLOUD_NAME=your_cloud
   CLOUDINARY_API_KEY=your_key
   CLOUDINARY_API_SECRET=your_secret
   ```
4. Verify: upload an image in chat — URL should be `res.cloudinary.com/...`

**Without Cloudinary:** Backend falls back to local `uploads/` folder. **This breaks on Railway** — files are lost on every redeploy.

---

## 3. Railway backend deploy

### Option A — GitLab → Railway

GitLab is **not** directly supported on Railway. Use **GitHub mirror** (below).

### Option A — GitHub → Railway (current setup)

1. Repo: https://github.com/mathiharan29/medcollab-beta  
2. **New Project** → **Deploy from GitHub repo**  
3. **Root Directory:** `medcollab-backend`  
4. **Branch:** `master`  
5. Build uses `medcollab-backend/nixpacks.toml`  
6. Add env vars → **Generate Domain** → set `API_BASE_URL`

### Option B — GitLab only (manual)

```powershell
cd D:\MedCollab\medcollab-backend
npm ci --omit=dev
$env:NODE_ENV="production"
# Set all env vars first, then:
node scripts/validate-env.js
node src/server.js
```

### Production startup scripts

| Script | Platform | Purpose |
|--------|----------|---------|
| `scripts/start-production.ps1` | Windows | Validate + `npm ci --omit=dev` + start |
| `scripts/start-production.sh` | Linux/macOS | Same |
| `scripts/validate-env.js` | All | Pre-flight env check |
| `Procfile` | Heroku/Railway | `web: node src/server.js` |
| `railway.json` | Railway | Health check on `/health` |

### Verify deployment

```powershell
curl https://YOUR-DOMAIN.up.railway.app/health
```

Expected:
```json
{"status":"ok","database":"connected","environment":"production",...}
```

---

## 4. Environment variables reference

See complete list: `medcollab-backend/.env.example`

| Variable | Required (prod) | Notes |
|----------|-----------------|-------|
| `NODE_ENV` | Yes | Must be `production` |
| `PORT` | Auto | Railway sets this |
| `MONGODB_URI` | Yes | Atlas connection string |
| `JWT_SECRET` | Yes | 64+ char random |
| `JWT_REFRESH_SECRET` | Yes | Different from JWT_SECRET |
| `MSG91_AUTH_KEY` | Yes | OTP SMS |
| `MSG91_TEMPLATE_ID` | Yes | DLT template |
| `OTP_BYPASS` | Yes | Must be `false` |
| `CLOUDINARY_*` | Strongly recommended | Media persistence |
| `API_BASE_URL` | Yes if no Cloudinary | Public HTTPS URL |
| `ALLOWED_ORIGINS` | Web only | Comma-separated |
| `FIREBASE_*` | Optional | Push notifications |

Generate JWT secrets:
```powershell
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

---

## 5. Socket.io production notes

- Socket.io attaches to the **same HTTP server** as Express (single Railway port)
- Auth: JWT in `handshake.auth.token` (Flutter client handles this)
- Mobile apps have **no Origin header** — CORS allows them automatically
- Ping: every 25s, timeout 60s
- Connection recovery: 2 minutes
- Space rooms sync via `sync_space_rooms` event on connect/reconnect

**Flutter client:** Socket URL = API URL (same host, no `/api` prefix).

---

## 6. CORS configuration

| Client | CORS needed? | Config |
|--------|--------------|--------|
| Flutter APK (mobile) | No | No Origin header sent |
| Flutter web | Yes | Add web URL to `ALLOWED_ORIGINS` |
| Postman / curl | No | No Origin header |

Production example:
```
ALLOWED_ORIGINS=https://medcollab-web.example.com,https://app.medcollab.com
```

Development: localhost origins auto-allowed when `NODE_ENV !== production`.

---

## 7. Flutter production build

### Environment configuration

The app reads the API URL at **compile time** via `--dart-define`:

| Flag | Required | Default (if omitted) |
|------|----------|----------------------|
| `API_BASE_URL` | **Yes for release** | `10.0.2.2:5000` (Android emulator only) |
| `SOCKET_URL` | No | Same as `API_BASE_URL` |
| `ENABLE_API_LOGGING` | No | `true` (disabled in release builds anyway) |

Config file: `medcollab-app/lib/core/config/env_config.dart`

### Build release APK

**PowerShell:**
```powershell
cd D:\MedCollab\medcollab-app
.\scripts\build-release-apk.ps1 -ApiBaseUrl "https://YOUR-DOMAIN.up.railway.app"
```

**Manual:**
```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://YOUR-DOMAIN.up.railway.app `
  --dart-define=ENABLE_API_LOGGING=false
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Physical phone testing

```powershell
# Install on connected device
flutter install --release `
  --dart-define=API_BASE_URL=https://YOUR-DOMAIN.up.railway.app
```

Or sideload the APK from `build/app/outputs/flutter-apk/app-release.apk`.

### Build Flutter web (optional)

```powershell
flutter build web `
  --dart-define=API_BASE_URL=https://YOUR-DOMAIN.up.railway.app `
  --dart-define=ENABLE_API_LOGGING=false
```

Add the web deploy URL to backend `ALLOWED_ORIGINS`.

---

## 8. Local development (unchanged)

```powershell
# Backend — in-memory MongoDB, OTP bypass, local media
cd D:\MedCollab\medcollab-backend
copy .env.example .env
# Set OTP_BYPASS=true, leave MONGODB_URI empty
npm run dev

# Flutter — Chrome
cd D:\MedCollab\medcollab-app
flutter run -d chrome

# Flutter — physical phone on same Wi-Fi
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5000
```

Dev OTP when `OTP_BYPASS=true`: **123456**

---

## 9. Post-deploy smoke test

Run with two physical devices or one phone + one browser:

| # | Test | Pass criteria |
|---|------|---------------|
| 1 | Health check | `GET /health` → 200, database connected |
| 2 | OTP login | Real SMS received, login succeeds |
| 3 | Create space | Space appears in list |
| 4 | Send text message | Other user sees it within 1s |
| 5 | Send image | Upload succeeds, image loads from Cloudinary |
| 6 | Send document | PDF/document opens |
| 7 | Presence | Status changes reflect on other user |
| 8 | Handoff | Submit → acknowledge → archived |
| 9 | Idle 20 min | Messages still sync after JWT refresh |
| 10 | App background | Realtime works after resume |

---

## 10. Known beta limitations

| Item | Status | Impact |
|------|--------|--------|
| FCM push notifications | Backend ready, Flutter not integrated | No background push |
| Release signing | Debug keystore | OK for internal beta, not Play Store |
| App ID | `com.example.medcollab_app` | Change before store release |
| Local media fallback | Dev only | Must use Cloudinary in production |
| `.npmrc` strict-ssl=false | Local Windows only | Do not copy to Railway |
| Multi-server scale | Single instance | Presence/rate limits in-memory |

---

## 11. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `MONGODB_URI is required` | Atlas not set | Set URI on Railway |
| `Socket auth rejected` | Expired JWT | Hot restart app; check token refresh |
| Media 404 after redeploy | Local disk fallback | Configure Cloudinary |
| OTP never arrives | MSG91 not configured | Set MSG91 keys, DLT template |
| APK can't connect | Wrong API URL | Rebuild with `--dart-define=API_BASE_URL=...` |
| CORS error (web only) | Origin not allowed | Add URL to `ALLOWED_ORIGINS` |
| `OTP_BYPASS must not be enabled` | Bypass left on | Set `OTP_BYPASS=false` |
| `cd medcollab-backend: No such file` | Root Directory + old railway.toml | Root=`medcollab-backend`; use `nixpacks.toml` in backend folder |
| MSG91 **website** says IP blocked | Too many signup/login attempts | See §13 below |

---

## 13. MSG91 dashboard “IP blocked” (signup / login)

This is **MSG91’s website** blocking you — not MedCollab. Common when creating an account or retrying login many times.

### Fixes (try in order)

1. **Wait 20 hours** — MSG91 auto-unblocks throttled IPs ([MSG91 help](https://msg91.com/help/common-signup-problems-solutions))
2. **Different network** — mobile hotspot worked for us; use on home Wi‑Fi if blocked
3. **Use existing account** — you used MSG91 last year; try **Forgot password** instead of new signup
4. **Email support:** support@msg91.com — “IP blocked during signup, please unblock”
5. **If you can log in elsewhere:** Settings → User Profile → **Blocked IP List** → remove your IP
6. **Do not** mark your own login as “Suspicious” in Login History

### After MSG91 dashboard works

1. Create **OTP Widget** with **MSG91 default SMS template** (no DLT)
2. Enable **Mobile Integration**, disable **Captcha** for native app
3. Copy **Widget ID** + **Auth Token** (Token section — not the auth key name)
4. Copy **Auth Key** → `MSG91_AUTH_KEY` on Railway (disable IP whitelist)
5. Railway Variables:
   ```env
   MSG91_AUTH_KEY=...
   OTP_BYPASS=false
   ```
   (`MSG91_TEMPLATE_ID` not needed for widget flow)
6. Deploy backend → build APK:
   ```powershell
   cd medcollab-app
   .\scripts\build-release-apk.ps1 `
     -ApiBaseUrl "https://medcollab.up.railway.app" `
     -Msg91WidgetToken "YOUR_WIDGET_TOKEN"
   ```
7. Login flow: app → MSG91 SDK sends SMS → verify → backend `POST /api/auth/verify-msg91-token`

### Beta testing without MSG91 (temporary)

Production **blocks** `OTP_BYPASS=true` in code. Options while MSG91 is blocked:

- Test against **local backend** with `OTP_BYPASS=true` and OTP `123456`
- Or temporarily change server to allow bypass in production (not recommended for real users)

---

## 12. Rollback

Railway keeps deployment history. To rollback:
1. Railway dashboard → Deployments
2. Select previous successful deploy → Redeploy

Database (Atlas) is independent — rollback does not affect data.

---

## Quick command reference

```powershell
# Validate backend env
cd medcollab-backend && node scripts/validate-env.js

# Production start (local smoke test)
cd medcollab-backend && .\scripts\start-production.ps1

# Build beta APK
cd medcollab-app && .\scripts\build-release-apk.ps1 -ApiBaseUrl "https://medcollab.up.railway.app"

# Health check
curl https://medcollab.up.railway.app/health
```
