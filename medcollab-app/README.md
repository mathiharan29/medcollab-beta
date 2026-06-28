# MedCollab Flutter App

Medical collaboration platform for hospital teams.

## Production API (beta)

```text
https://medcollab.up.railway.app
```

Build for production:

```powershell
.\scripts\build-release-apk.ps1 -ApiBaseUrl "https://medcollab.up.railway.app"
```

Login on production requires **MSG91 OTP** (not yet configured — MSG91 dashboard access blocked).

## Setup

```powershell
cd medcollab-app
flutter pub get
```

## Run (local backend)

```powershell
# Chrome
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000

# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000

# Physical phone (LAN IP)
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5000
```

Dev backend OTP: **123456** when `OTP_BYPASS=true` in backend `.env`.

## Architecture

```
lib/
├── core/           # API, socket, theme, router, env
├── features/       # auth, spaces, messages, handoffs, members, media
└── shared/         # widgets (AppFab, AppSearchBar, etc.)
```

## Status

See [PROJECT_STATE.md](PROJECT_STATE.md) and [../DEPLOYMENT.md](../DEPLOYMENT.md).
