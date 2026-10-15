# Vocle Admin Portal

Internal ops dashboard for Vocle (MedCollab). **Not** part of the public marketing site.

Zero-build static app (HTML/CSS/JS) — no `npm install` required.

**How data connects:** read [`CONNECT.md`](./CONNECT.md) first.

## Quick start (see the UI locally)

```powershell
cd D:\MedCollab\medcollab-backend
npm run dev
```

Open **http://localhost:5000/admin/** → type **10-digit** phone (e.g. `9876543210`) → OTP `123456`.

Full deploy steps: [`DEPLOY_STEPS.md`](./DEPLOY_STEPS.md) · Data wiring: [`CONNECT.md`](./CONNECT.md)

Local API without Atlas = empty DB (you’ll only see yourself after login).  
For beta doctors, point `config.js` at Railway after admin routes are deployed — see CONNECT.md.

## Env (backend)

```env
ALLOWED_ORIGINS=http://localhost:5173
ADMIN_ALLOW_ANY_IN_DEV=true   # local only
# Production Railway:
# ADMIN_USER_IDS=yourMongoUserId,sanjayMongoUserId
```

## Production notes

- Deploy on its own origin (e.g. `admin.vocle.in`), never linked from the public site.
- Add that origin to Railway `ALLOWED_ORIGINS`.
- Keep `ADMIN_USER_IDS` tight — space admins are not platform admins.

## Phase 1 capabilities

- Overview counts (users, spaces, messages, handoffs, storage tracked)
- User table with last seen, message/handoff counts, joinedVia
- Verify / unverify doctor
- Deactivate / reactivate account (`isActive`)
