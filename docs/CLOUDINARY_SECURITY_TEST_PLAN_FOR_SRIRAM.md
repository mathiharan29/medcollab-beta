# Cloudinary security-test setup — plan for Sriram

**Date:** 2026-10-04  
**From:** Vocle / MedCollab eng (via Cursor)  
**To:** Sriram (media / integration-security)  
**Context:** Offline/local media security + Cloudinary SDK contract tests are done. This is the **final integration-security phase** against a **non-production** Cloudinary cloud only.

---

## Goal

Run CI (GitHub Actions) that can **upload / read / delete synthetic assets only**, with:

- **No** production Cloudinary credentials  
- **No** production media (cloud `denbnijqe` stays untouched)  
- Credentials scoped so a leak cannot touch real doctor uploads  

---

## What Mathiharan will do (your blocker today)

1. Create a **brand-new Cloudinary cloud** (Free plan is fine), e.g. name it `vocle-security-test`.  
2. Leave Media Library **empty** — do not copy or sync from production.  
3. Copy the three Dashboard values into a **private** channel / 1Password note for you (not Git, not Slack public):

| Secret name (for GHA) | Value |
|------------------------|--------|
| `CLOUDINARY_CLOUD_NAME` | *(new test cloud name)* |
| `CLOUDINARY_API_KEY` | *(test API key)* |
| `CLOUDINARY_API_SECRET` | *(test API secret)* |

4. Confirm when those three are in your hands.  
5. **Never** share Railway / prod `CLOUDINARY_*` for this work.

Until step 3–4 happen, you cannot finish the integration-security phase against a real Cloudinary edge.

---

## What you (Sriram) need to do once you have the three secrets

1. Add them as **GitHub Actions secrets** on the security / CI repo (or MedCollab mirror — whichever runs the suite).  
2. Point the integration-security job at those secrets only (no fallback to prod).  
3. Use a dedicated folder prefix for synthetic assets, mirroring the app:

```text
medcollab/messages/security-test/
medcollab/avatars/security-test/
medcollab/handoffs/
```

4. Exercise the same SDK surface the app uses (`cloudinary` Node v2):

| Capability | App usage | Your tests should cover |
|------------|-----------|-------------------------|
| Upload | `uploader.upload_stream` | image, video, raw (PDF) |
| Read / deliver | `cloudinary.url` / `secure_url` | HTTPS URLs + simple transforms |
| Delete | `uploader.destroy` | Cleanup after each run |

5. Tear down assets at end of job (`destroy`) so the test cloud stays empty-ish.  
6. Fail the job if any secret name still looks like prod cloud `denbnijqe`.

### GHA permission bar (minimum)

A standard Cloudinary **API key + secret** on the **test** cloud is enough for upload + read + delete. You do **not** need:

- Prod keys  
- Console login in CI  
- Extra Cloudinary add-ons  
- Write access to Railway  

Optional later: separate API key used only by GHA; rotate anytime.

---

## How Vocle uses Cloudinary today (so tests stay realistic)

Source of truth: `medcollab-backend/src/config/cloudinary.js` + `media.controller.js`.

Env vars (exact names on server):

```text
CLOUDINARY_CLOUD_NAME
CLOUDINARY_API_KEY
CLOUDINARY_API_SECRET
```

Upload folders:

- `medcollab/messages/{userId}`
- `medcollab/avatars/{userId}`
- `medcollab/handoffs`

Resource types: **image**, **video**, **raw** (PDF).  
Config flag: `secure: true`.

**Quirk for your delete tests:** app delete currently tries `destroy` with `resource_type: 'image'`, then `'raw'`. It does **not** yet retry `'video'`. For video cleanup in CI, call `destroy` with `resource_type: 'video'` explicitly (or expect `not found` if you only mirror app code).

Allowed MIME types / size live in `medcollab-backend/src/constants/index.js` (`MEDIA.ALLOWED_TYPES`, ~50 MB max). Synthetic fixtures should stay inside that envelope.

---

## Account settings to reproduce (behavior only — not prod config dump)

On the **test** cloud, mirror:

| Setting / behavior | Why |
|--------------------|-----|
| HTTPS delivery | Matches `secure: true` |
| Image + video + raw uploads allowed | Matches app |
| ~50 MB upload headroom | Matches current backend limit |
| Folder layout under `medcollab/...` | Path / ownership realism |

Do **not** need to copy from prod:

- Custom CDN domain  
- Named transformations / presets (app does not require them)  
- Prod backups / add-ons  
- Any Media Library contents  

---

## Suggested test plan (integration-security job)

1. **Smoke:** config present → `ping` / trivial upload of 1×1 PNG → assert `secure_url` host is `res.cloudinary.com` and cloud name is the **test** cloud.  
2. **Upload matrix:** PNG/JPEG, short MP4, small PDF → assert `resource_type` + `public_id` under `medcollab/.../security-test/`.  
3. **Read:** build transformed URL (e.g. `w_400`) → HTTP GET 200.  
4. **Delete:** destroy uploaded `public_id`s → assert gone; second destroy → not found.  
5. **Negative:** missing secret → job fails closed; wrong cloud name guard if you hardcode deny-list `denbnijqe`.  
6. **Cleanup always:** `finally` / post-job wipe of the security-test folder prefix.

---

## What you should ask Mathiharan for (checklist)

- [ ] New empty Cloudinary cloud created  
- [ ] Three test secrets delivered privately  
- [ ] Confirmation that Railway prod keys were **not** reused  
- [ ] (Optional) Who owns rotation if the test key leaks  

## What you do **not** need from Mathiharan

- Production `CLOUDINARY_API_SECRET`  
- Access to Media Library on `denbnijqe`  
- Mongo / MSG91 / Firebase Admin keys (out of scope for this phase)

---

## Status after this doc

| Phase | Status |
|-------|--------|
| Offline / local media security | Done (your side) |
| Cloudinary SDK contract tests | Done (your side) |
| Non-prod Cloudinary cloud + GHA secrets | **Waiting on Mathiharan** |
| Integration-security CI against live test cloud | **Your next step after secrets** |

When the three test secrets land, reply with “secrets received — cloud name = …” (cloud name only is fine in Slack) and proceed with the GHA job.

---

**TL;DR:** Mathiharan creates an empty test Cloudinary cloud and sends you three non-prod secrets. You wire them into GitHub Actions and run upload/read/delete against synthetic `medcollab/.../security-test/` assets only. Production stays sealed.
