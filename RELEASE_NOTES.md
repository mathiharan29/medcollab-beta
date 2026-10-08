# Vocle Closed Beta — Release Notes

## Current build — `1.0.0+26` (8 October 2026)

**APK:** `Vocle-beta.apk` · **API:** https://medcollab.up.railway.app  

### For testers
- Needl (group chat): names on messages, people list, clearer hub cards  
- Search colleagues by **mobile number** (including strangers for message request)  
- Video send + PDF open hardened  
- Reactions: multiple emojis; tap others’ emoji to see who reacted  
- Notification Reply no longer stuck loading  
- Security hardening rolled to API (login token verify, private chat privacy)

### Team docs
- Architect: `docs/ARCHITECT_STATUS_UPDATE_2026-10-08.md`  
- Security (Sriram): `docs/SRIRAM_REMEDIATION_STATUS_2026-10-08.md`  

---

## Historical — Closed beta packaging `1.0.0` build `14` (24 August 2026)

**Product:** Vocle  
**Version:** `1.0.0` (build `14`)  
**Date:** 24 August 2026  
**Audience:** Invited doctors (~15) — Android closed beta  

---

## What’s in this build

- Transparent Vocle logo (`Logo_bgless.png`) on splash and sign-in
- Privacy Policy and Terms of Use (sign-in links + Profile → Legal)
- Expanded Help & FAQ (join, DMs, handoffs, OTP, privacy, feedback)
- Send feedback, Report a bug, Feature request, Contact team
- Sprint 12–13 UX polish and QA fixes (unread badges, media caching, push dedupe, socket recovery guard, DM race fix, media URL allowlist)
- FCM Android push for messages, mentions, handoffs, emergencies
- Production API: `https://medcollab.up.railway.app`

## Known limitations (closed beta)

- Android APK only (sideload); not on Play Store yet
- Signed with debug keystore for pilot installs
- No third-party product analytics (by design)
- Pilot may include downtime or incomplete features — report via Feedback / Bug report
- Do not paste unnecessary patient identifiers into chats or tickets

## Install

1. Uninstall any older Vocle / MedCollab APK if prompted about signature mismatch.
2. Install `vocle-beta.apk` (build 14).
3. Allow notifications when prompted.
4. Sign in with mobile OTP.
5. Join your department group via invite code or QR.

## Support

- Email: **vocle.official@gmail.com**
- Instagram: **@thevocle**
- In-app: Profile → Help / Feedback / Report a bug

## Changelog since Sprint 12

| Area | Change |
|------|--------|
| Branding | Transparent logo asset |
| Legal | Privacy + Terms in-app |
| Support | Feedback endpoint + FAQ expansion |
| QA | Socket recovered-handler guard, DM upsert, media URL validation |
| Client | Cached chat media, list keys, push tap dedupe |
| Version | `1.0.0+14` |
