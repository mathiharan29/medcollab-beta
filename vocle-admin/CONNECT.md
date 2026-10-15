# How Vocle Admin connects to real app data

## Mental model

```
Vocle Admin portal (this folder, :5173)
        |  phone OTP + JWT
        |  GET/PUT /api/admin/*
        v
MedCollab API  (local :5000  OR  https://medcollab.up.railway.app)
        |
        v
MongoDB Atlas  <--- same DB the Flutter Vocle app writes to
```

The admin portal has **no database of its own**.  
It uses the **same login** as the app, then calls **admin-only** API routes that query the **same** `User` / `Message` / `Handoff` / `Space` collections.

Exact Cloudinary / Atlas / Railway bills still live in those vendor consoles. Phase 2 shows **estimates** from our counters + free-tier headroom alerts.

## Why localhost looked empty

| Piece | Role | If missing |
|-------|------|------------|
| API on `:5000` | Serves `/api/admin/*` | Login fails |
| Static portal on `:5173` | Serves `index.html` | Browser: connection refused / nothing |
| Same DB as the app | Real users & messages | Empty **in-memory** local DB only |

Local `.env` without `MONGODB_URI` = empty in-memory Mongo. That is **not** beta production data.

## See real Vocle users

**A) Portal → production API (recommended for ops)**

1. Deploy backend (admin routes) to GitHub `master` → Railway.
2. Railway env: `ADMIN_USER_IDS=yourId,sanjayId` and `ALLOWED_ORIGINS` includes `http://localhost:5173`.
3. Set in `config.js`: `window.VOCLE_ADMIN_API = 'https://medcollab.up.railway.app'`
4. Serve portal, login with real MSG91 OTP.

**B) Local API + Atlas URI**

Put production `MONGODB_URI` in local `.env` (writes hit real data — be careful). Portal stays on `http://localhost:5000`.

## Local UI dogfood (empty DB)

```powershell
cd D:\MedCollab\medcollab-backend
npm run dev

cd D:\MedCollab\vocle-admin
python -m http.server 5173
```

Open `http://localhost:5173` — OTP `123456` when `OTP_BYPASS=true`.  
You will see **yourself** after login, not beta doctors, until A or B above.

## Auth gate

1. OTP → JWT (`/api/auth/verify-otp`)
2. `/api/admin/*` also requires `ADMIN_USER_IDS` (or local `ADMIN_ALLOW_ANY_IN_DEV=true`)
3. Space owner/admin ≠ platform admin
