# MedCollab (Vocle) — Tech Lead Report & AI Handoff

**Date:** 2026-10-08  
**Status:** Beta live · Needl UX `1.0.0+26` · Security Waves 1–3 on Railway  
**Production API:** https://medcollab.up.railway.app  
**Railway deploy source:** GitHub `mathiharan29/medcollab-beta` **`master`** (root `medcollab-backend`)  
**Latest APK:** `D:\MedCollab\Vocle-beta.apk` (`1.0.0+26`)  
**Tip SHA:** `7a0ae10`

---

## 1. Product summary

| Layer | Status |
|-------|--------|
| Backend | ✅ Waves 1–3 security remediations deployed |
| Mobile | ✅ Needl / search / media / reactions / notif reply |
| Push (FCM) | ✅ Android LIVE |

**Do not change:** feature folders, `{ success, message, data }`, REST persist / Socket broadcast.

---

## 2. Recent work (agents — continue here)

### Done
- Needl = multi-person DM hub (not threads); members list; titles; composer cleanup  
- Wave 1: MSG91 provider verify, atomic OTP, video validate, PDF/octet typing  
- Wave 2: `channelAccess` primitive; S1/S2/S3/S4/S6  
- Wave 3: S8 audience, N1 Needl filter, N3 mentions  

### Next (ordered)
1. **Wave 4** — socket revoke / typing auth / null crash / recovery auth / deactivated sockets  
2. **Wave 5** — FUNC-01 notification `MessageRequest` enum + FUNC-02 DM accept upsert  
3. Waves 6–8 — deleted-edit, media remainder, hardening/policy  

### Docs to share
| Audience | File |
|----------|------|
| Architect / lead | `docs/ARCHITECT_STATUS_UPDATE_2026-10-08.md` |
| Security (Sriram) | `docs/SRIRAM_REMEDIATION_STATUS_2026-10-08.md` |
| Findings source | `docs/VOCLE_DEVELOPER_REMEDIATION_REPORT.md` |
| Lead one-pager | `PROJECT_LEAD_SUMMARY.md` |

---

## 3. Known limitations

| Item | Limitation |
|------|------------|
| Message-request accept | Still broken on upstream until Wave 5 (sanity FUNC-01/02) |
| Socket revocation | Stale rooms until Wave 4 |
| Play Store id | Still `com.example.medcollab_app` for beta |
| iOS / APNs | Not configured |
| Unread counts | Still partly notification-derived |

---

## 4. Local commands

```powershell
# Backend
cd D:\MedCollab\medcollab-backend; npm run dev

# App
cd D:\MedCollab\medcollab-app; flutter run -d chrome

# Release APK
$defs = Get-Content D:\MedCollab\medcollab-app\scripts\dart-defines.release.json -Raw | ConvertFrom-Json
cd D:\MedCollab\medcollab-app
.\scripts\build-release-apk.ps1 `
  -ApiBaseUrl $defs.API_BASE_URL `
  -Msg91WidgetToken $defs.MSG91_WIDGET_TOKEN `
  -SkipAnalyze `
  -OutputApkName "Vocle-beta.apk"
```

---

## 5. Doc index

`PROJECT_LEAD_SUMMARY.md` · `DEPLOYMENT.md` · `PUSH_NOTIFICATIONS.md` · `docs/ARCHITECT_STATUS_UPDATE_2026-10-08.md` · `docs/SRIRAM_REMEDIATION_STATUS_2026-10-08.md`
