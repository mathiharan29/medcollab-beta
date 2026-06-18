# MedCollab — Claude Code Context

## What this project is
A medical collaboration platform for doctors. Replacing WhatsApp for clinical
communication. Think Slack, but built for Indian hospital workflows.

## GitLab
https://gitlab.com/mathiharan-project/MedCollab

## Target users (beta)
- MBBS interns
- PG residents  
- Junior consultants
Starting with 15 doctors. Then 50. Then 100.

## Core philosophy
Compete with WhatsApp by solving workflow problems, not just messaging.
Killer feature: structured shift handoffs (no other tool has this).

## Tech stack
- Backend: Node.js + Express + MongoDB Atlas + Socket.io
- Mobile: Flutter (flutter_bloc, dio, go_router, socket_io_client)
- Media: Cloudinary
- Push notifications: Firebase Cloud Messaging
- Auth: Phone OTP (MSG91) + JWT
- Hosting: Railway (backend) + Firebase App Distribution (mobile beta)
- CI: GitLab CI (.gitlab-ci.yml)

## Project structure
```
medcollab-backend/   ← Node.js API
medcollab-app/       ← Flutter client
```

## What is DONE

### Backend — complete
- All models, middleware, controllers, routes, socket handlers
- Auth, users, spaces, channels, messages, handoffs, media, notifications

### Flutter — Phase 1 + 2 complete
- Core: API client, socket, secure storage, theme, router
- Auth: Splash → phone → OTP → profile setup → home
- AuthBloc, persistent login, logout

### Next — Phase 3
- Spaces list, channels, real-time chat UI

## Architecture decisions — DO NOT change these

### Backend folder structure
Feature-based, not type-based:
  src/features/messages/ contains model + routes + controller + service

### API response shape — always this format
Success: { success: true, message: "...", data: { ... } }
Error:   { success: false, message: "...", errors: [...] }

### Flutter folder structure
Feature-first clean architecture:
  lib/features/<feature>/data|domain|presentation

### Message pagination — cursor-based, not page-based
### Soft deletes — never hard delete messages
### Socket + REST separation — REST persists, socket broadcasts

### OTP bypass for development
  Set OTP_BYPASS=true in .env → OTP is always "123456"

## Key constants
Backend: src/constants/index.js
Flutter: lib/core/constants/

## Environment variables
See medcollab-backend/.env.example

## Design principles
- Feel clinical and trustworthy, not consumer chat
- Emergency messages visually distinct (red, different sound)
- Handoffs are the #1 differentiator — give them premium UX
