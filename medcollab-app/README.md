# MedCollab Flutter App

Medical collaboration platform for hospital teams.

## Phase 1 — Foundation

Core infrastructure is in place. Feature screens start in Phase 2.

## Setup

```bash
cd medcollab-app
flutter pub get
flutter create . --project-name medcollab_app   # generates android/ios if missing
```

## Run (local backend on emulator)

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

Physical device (replace with your machine's LAN IP):

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.x:5000
```

## Architecture

```
lib/
├── core/           # Shared infrastructure
├── features/       # Feature-first modules
│   └── auth/
│       ├── data/
│       ├── domain/       # Phase 2+
│       └── presentation/ # Phase 2+
└── shared/         # Cross-feature utilities
```

See [TASKS.md](TASKS.md) for progress tracker.
