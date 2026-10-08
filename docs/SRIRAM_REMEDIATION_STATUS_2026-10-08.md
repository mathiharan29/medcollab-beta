# Vocle — Security Remediation Status (for Sriram)

**Date:** 8 October 2026 (IST)  
**Audience:** Security / validation (Sriram)  
**Source report:** [`VOCLE_DEVELOPER_REMEDIATION_REPORT.md`](VOCLE_DEVELOPER_REMEDIATION_REPORT.md)  
**Application branch:** GitHub / GitLab `master`  
**Current SHA (docs cut):** `7a0ae10` (Wave 3) · app `1.0.0+26`  
**Production API:** https://medcollab.up.railway.app  

This is the **developer remediation progress** against your final validation handoff. Application fixes are on upstream `master` (Railway). We did **not** change your fork harness. Please re-run focused workflows against this SHA when ready.

---

## 1. Execution plan (agreed)

| Wave | Theme | Status | Key commits |
|------|--------|--------|-------------|
| **1** | Trusted identity (P0 + OTP) + beta UX bugs | ✅ Done | `77b6d2d` |
| **2** | Canonical channel access / containment | ✅ Done | `97d90fe` |
| **3** | Audience / disclosure | ✅ Done | `7a0ae10` |
| **4** | Realtime lifecycle (revoke, typing, null, recovery) | ⏳ Next | — |
| **5** | Functional message-request journeys (FUNC-01/02) | Pending | — |
| **6** | Deleted-edit + data hardening | Pending | — |
| **7** | Media / Cloudinary contracts (remainder) | Partial in W1 | — |
| **8** | Hardening + policy defaults | Pending | — |

Harness-only note from your report (**VR-INFRA-01**, VOCLE-171/355) was **not** an application defect — no upstream change required.

---

## 2. VR ID → fix mapping (completed)

### Wave 1 — Auth + related media/UX

| Report ID | Fix summary | Primary files |
|-----------|-------------|---------------|
| **VR-AUTH-WIDGET** | Removed MSG91 JWT decode “fast path”. Always calls provider `verifyAccessToken`; phone from provider payload (JWT decode only after success). | `medcollab-backend/src/services/msg91Widget.service.js` |
| **VR-A1-OTP-CONSUMPTION** | Atomic OTP consume via `findOneAndDelete` after hash match; concurrent success returns “already used”. | `medcollab-backend/src/features/auth/otp.model.js` |
| **VR-MEDIA-VIDEO-MESSAGE** (partial Wave 7) | `validateSendMessage` allows `video`. | `medcollab-backend/src/middleware/validate.js` |
| **VR-MEDIA-OCTET-RESOURCE-TYPE** (partial) | Octet-stream typed by extension → raw/video/image. | `medcollab-backend/src/features/media/media.controller.js` |
| **VR-CLOUDINARY-PDF-ATTACHMENT** (partial) | PDF delivery uses raw `secure_url` (no broken `fl_attachment` portal). | same |
| Reactions product change | Multi-emoji per user (not one-replace). | `message.model.js` `toggleReaction` |

### Wave 2 — Access / containment

| Report ID | Fix summary | Primary files |
|-----------|-------------|---------------|
| Shared primitive | `evaluateChannelAccess` / `resolveChannelAccessById` / inactive space revoked. | `medcollab-backend/src/utils/channelAccess.js` |
| **VR-S1** | Thread parent must be in same channel; reply counter update scoped by `channelId`; thread list filtered by channel. | `message.controller.js` |
| **VR-S2** | Create handoff: channel must belong to `spaceId`. | `handoff.controller.js` |
| **VR-S3** | `getChannelById`, `getChannelMembers`, pin/unpin use shared access (private-safe). | `channel.controller.js` |
| **VR-S4** | Receivers cannot force `status=draft`; detail denies draft to non-sender; search excludes others’ drafts. | `handoff.controller.js`, `search.controller.js` |
| **VR-S6** | Media delete: normalize path, reject `..`, require exact `medcollab/messages\|avatars/<userId>/` prefix; local delete containment; video destroy retry. | `media.controller.js`, `localMediaStorage.js` |

### Wave 3 — Audience

| Report ID | Fix summary | Primary files |
|-----------|-------------|---------------|
| **VR-S8** | `resolveMessageAudienceIds` — private channels fan out to members + space admins only (not whole space). | `channelAccess.js`, `message.controller.js` |
| **VR-N1-NEEDL-ACCESS** | Needl inbox filters every candidate channel through `canAccessChannel`. | `user.controller.js` |
| **VR-N3-MENTION-AUDIENCE** | Mentions: active users only + `canAccessChannel` before inbox/socket notify. | `notification.service.js` |

---

## 3. Not yet remediated (your queue order)

| Priority | IDs | Planned wave |
|----------|-----|--------------|
| P1 realtime | VR-S7, VR-S9, VR-R1, VR-R3, VR-R4, VR-R5 | Wave 4 |
| P1 functional | VR-FUNC-01, VR-FUNC-02 | Wave 5 |
| P2 data | VR-DATA-DELETED-EDIT (+ retention/expiry defaults) | Wave 6 |
| P2 media remainder | VR-MEDIA-VIDEO-DELETE formalization, PDF preview policy | Wave 7 |
| P3 | Hardening + policy decisions §11 | Wave 8 |
| Owner | VR-OWNER-CLOUDINARY / ATLAS / RELEASE | Account attestations (external) |

---

## 4. Suggested verification (your §13)

Re-run against upstream SHA `7a0ae10` (or later tip of `master`):

1. **Auth:** VOCLE-356, 357, 687 + positive OTP/widget controls  
2. **Access / drafts / Needl:** 094/098/193/197/275/276; 099; 159/272/273/594/595; 267–271; 313/314/704; 429/434/503/509  
3. **Audience:** 347; 603/604/685/686  
4. **Media (partial):** 724/725/746/770 (+ video send positive)  
5. **Sanity:** still expect FUNC-01/02 red until Wave 5 — do not treat Wave 1–3 as waiving those

Use fork dispatch `ref` pointing at synced upstream or cherry-pick tested SHA into your workflow target. Do **not** point CI at production Atlas/Cloudinary.

---

## 5. Product bugs fixed in the same window (not in your registry)

Doctor-reported Needl / chat issues fixed in `77b6d2d` / `87d8aad` (Flutter `1.0.0+25`–`+26`): sender names in Needl, phone lookup, composer/reactions/mention UX, notification reply spinner, PDF open client hardening. These are **not** substitutes for your security gates.

---

## 6. Contact / artifacts

| Item | Location |
|------|----------|
| Full findings | `docs/VOCLE_DEVELOPER_REMEDIATION_REPORT.md` |
| Architect snapshot | `docs/ARCHITECT_STATUS_UPDATE_2026-10-08.md` |
| Lead summary | `PROJECT_LEAD_SUMMARY.md` |
| APK | `D:\MedCollab\Vocle-beta.apk` (`1.0.0+26`) — local only, not in git |

**Ask when re-running:** reply with run IDs + which VR IDs flipped PASS so we can mark Wave gates closed and start Wave 4.
