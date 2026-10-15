# Vocle Admin — baby steps (phone fix + Railway deploy)

## A) Fix “Validation failed” on phone (local, right now)

You do **not** need `+91` with spaces. Use one of these:

| Type this | We send to API |
|-----------|----------------|
| `9876543210` | `+919876543210` |
| `+919876543210` | `+919876543210` |

Spaces like `+91 98765 43210` used to break validation — that is fixed. **Hard-refresh** the page (`Ctrl+Shift+R`).

### Local login (empty test DB)

1. Backend running: `cd medcollab-backend` → `npm run dev`
2. Open **http://localhost:5000/admin/** (same API — easiest)  
   or http://localhost:5173 if you still use `python -m http.server 5173`
3. Phone: your 10-digit number  
4. OTP: `123456` (local `OTP_BYPASS=true`)

You will mostly see **yourself** (in-memory DB). Real beta doctors need Railway deploy (section B).

---

## B) Deploy ASAP — same Railway project / same API service

**Yes — same Railway dashboard and the same service** that already runs  
`https://medcollab.up.railway.app`.

We do **not** need a second Railway app for v1. Admin is served at:

**https://medcollab.up.railway.app/admin/**

```
Same Railway service (medcollab-backend)
├── /api/...     ← Flutter app + admin API
├── /admin/      ← admin portal HTML/JS
└── MongoDB Atlas (existing)
```

### Step 1 — Get your Mongo user id (production)

On a phone that already uses Vocle beta, or via API after MSG91 login, you need your user `_id`.

Easiest after deploy (step 5): temporarily set `ADMIN_ALLOW_ANY_IN_DEV` is **ignored in production**. So before going live you must set `ADMIN_USER_IDS`.

If you already know your id from Atlas or a previous `/api/users/me` call, use that.  
Otherwise: after pushing, ask a teammate with Atlas access to copy your User `_id`, **or** temporarily log ids from Railway logs on next login (optional later).

### Step 2 — Railway variables (same service)

Railway → your MedCollab API service → **Variables** → add/update:

```env
ADMIN_USER_IDS=PUT_YOUR_MONGO_USER_ID_HERE,PUT_SANJAY_ID_HERE
ALLOWED_ORIGINS=https://medcollab.up.railway.app
```

- Keep existing `MONGODB_URI`, `JWT_*`, MSG91, Cloudinary, etc.
- Do **not** set `OTP_BYPASS=true` in production.
- `ADMIN_ALLOW_ANY_IN_DEV` is only for local; leave it unset on Railway.

Save / redeploy if Railway asks.

### Step 3 — Commit admin code (when you ask the agent, or yourself)

Must include:

- `medcollab-backend/src/features/admin/**`
- `medcollab-backend/public/admin/**`
- `medcollab-backend/src/app.js` (mounts `/admin`)
- User model fields + auth middleware changes

### Step 4 — Push to GitHub `master` (what Railway watches)

Railway deploys from **GitHub** `mathiharan29/medcollab-beta` **`master`**, root `medcollab-backend`.

From your usual sync (example):

```powershell
cd D:\MedCollab
.\scripts\sync-railway-deploy.ps1
```

Or push the backend commit to GitHub `master` the way you normally ship API changes.

### Step 5 — Wait for deploy, then open admin

1. Railway → Deployments → wait until success  
2. Check https://medcollab.up.railway.app/health  
3. Open **https://medcollab.up.railway.app/admin/**  
4. Login with your **real** Vocle phone → **MSG91 OTP** (not 123456)  
5. If 403: your id is missing from `ADMIN_USER_IDS` — fix Step 2 and redeploy vars

### Step 6 — Confirm real data

You should see real user counts from Atlas (same DB as the APK).  
Banner should say production API / live data.

---

## C) What you do NOT need

| Idea | Needed for v1? |
|------|----------------|
| Second Railway service | No |
| Vercel / separate admin domain | No (optional later: `admin.vocle.in`) |
| Changing Flutter app | No |
| New Mongo database | No |

---

## D) After every UI tweak to admin

Edit files in `vocle-admin/`, then copy into the deployable folder:

```powershell
Copy-Item D:\MedCollab\vocle-admin\index.html,D:\MedCollab\vocle-admin\app.js,D:\MedCollab\vocle-admin\styles.css,D:\MedCollab\vocle-admin\config.js `
  -Destination D:\MedCollab\medcollab-backend\public\admin\ -Force
```

Then commit + sync to GitHub `master` again.

---

## Quick troubleshooting

| Symptom | Fix |
|---------|-----|
| Validation failed on phone | 10 digits only, hard refresh; no spaces |
| Connection refused localhost | Start `npm run dev`; open `/admin/` on port 5000 |
| Empty users locally | Expected without Atlas; deploy to Railway |
| 403 after OTP on prod | Set `ADMIN_USER_IDS` to your Mongo `_id` |
| Old admin UI on Railway | Ensure `public/admin` was committed + deployed |
