# MedCollab — Claude Code Context

## What this project is
A medical collaboration platform for doctors. Replacing WhatsApp for clinical
communication. Think Slack, but built for Indian hospital workflows.

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
- Mobile: Flutter
- Media: Cloudinary
- Push notifications: Firebase Cloud Messaging
- Auth: Phone OTP (MSG91) + JWT
- Hosting: Railway (backend) + Firebase App Distribution (mobile beta)

## Project structure
medcollab-backend/   ← Node.js API (this folder)
medcollab-app/       ← Flutter mobile app

## What is DONE (Day 1 + Day 2 in progress)

### Backend — fully built
- All 6 Mongoose models: User, OTP, Space, Channel, Message, Handoff, Notification
- All middleware: auth (JWT), errorHandler, rateLimiter, validate
- All route files: auth, users, spaces, channels, messages, handoffs, media, notifications
- Socket.io setup: room architecture, presence handler, message handler
- Services: otp.service.js, notification.service.js
- Auth controller: requestOtp, verifyOtp, refreshToken, logout

### Still needed
- controllers: users, spaces, channels, messages, handoffs, media, notifications
- Wire all route files to use real controllers (replace placeholder functions)
- End-to-end test with curl

### Flutter app
- Not started yet. Build after backend controllers are done.

## Architecture decisions — DO NOT change these

### Folder structure
Feature-based, not type-based:
  src/features/messages/ contains model + routes + controller + service
  NOT: src/models/ src/routes/ src/controllers/ (flat structure)

### API response shape — always this format
Success: { success: true, message: "...", data: { ... } }
Error:   { success: false, message: "...", errors: [...] }
Use respond.ok(), respond.created(), respond.badRequest() from utils/apiResponse.js

### Always use asyncHandler wrapper
  const asyncHandler = require('../../utils/asyncHandler');
  const myController = asyncHandler(async (req, res) => { ... });
  Never write try/catch in controllers — asyncHandler catches everything.

### Authentication pattern
  req.user is available in all protected routes (set by protect middleware)
  req.user contains the full User document (minus fcmTokens)

### Message pagination — cursor-based, not page-based
  Query: { channelId, _id: { $lt: beforeId } } sorted createdAt: -1, limit 30
  Returns: { messages: [...], hasMore: boolean }

### Soft deletes — never hard delete
  Messages: set isDeleted: true (pre-save hook blanks content)
  Spaces/Channels: set isArchived: true
  Never call .deleteOne() on messages

### Socket + REST separation
  REST (HTTP): persists data to MongoDB
  Socket.io: broadcasts to connected clients AFTER REST saves
  Flow: controller saves message → calls emitNewMessage(channelId, message)
  Import from: const { emitNewMessage } = require('../../socket')

### OTP bypass for development
  Set OTP_BYPASS=true in .env
  Any phone number → OTP is always "123456"
  Never enable in production

## Database collections
- users          (phone as primary identity, no passwords)
- otps           (hashed, TTL-indexed — auto-deletes after 10 min)
- spaces         (top-level containers, like Slack workspaces)
- channels       (inside spaces, type: general/emergency/academic/direct)
- messages       (cursor-paginated, soft-delete, threaded via threadId)
- handoffs       (DRAFT → SUBMITTED → ACKNOWLEDGED lifecycle)
- notifications  (in-app inbox, TTL 30 days)

## Key constants (always import from src/constants/index.js)
USER_ROLES, AVAILABILITY_STATUS, SPACE_TYPES, SPACE_ROLES,
CHANNEL_TYPES, MESSAGE_TYPES, MESSAGE_PRIORITY,
HANDOFF_STATUS, SHIFT_TYPES, PATIENT_STATUS,
NOTIFICATION_TYPES, PAGINATION, MEDIA, SOCKET_EVENTS

## Environment variables needed (.env)
NODE_ENV=development
PORT=5000
MONGODB_URI=mongodb+srv://...
JWT_SECRET=64-char-random-string
JWT_REFRESH_SECRET=different-64-char-string
OTP_BYPASS=true            ← for local dev
CLOUDINARY_CLOUD_NAME=...
CLOUDINARY_API_KEY=...
CLOUDINARY_API_SECRET=...
FIREBASE_PROJECT_ID=...    ← optional for dev (push notifications)
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY=...

## What to work on next (Day 2 plan)
Build controllers in this order — each is independently testable:

1. src/features/users/user.controller.js
   - getMe, updateMe, updateAvailability, registerFcmToken, getUserById, searchUsers

2. src/features/spaces/space.controller.js  
   - createSpace, getMySpaces, getSpaceById, joinSpace,
     regenerateInviteCode, updateSpace, getMembers, removeMember, leaveSpace
   - When createSpace: seed 3 default channels (#general, #emergency, #academics)

3. src/features/channels/channel.controller.js
   - createChannel, getSpaceChannels, getChannelById, updateChannel,
     archiveChannel, createOrGetDM, getChannelMembers, pinMessage, unpinMessage

4. src/features/messages/message.controller.js
   - getMessages, sendMessage, getThread, replyToThread,
     editMessage, deleteMessage, toggleReaction, markAsRead
   - After sendMessage: call emitNewMessage() from socket/index.js
   - After sendMessage: call notifyNewMessage() from notification.service.js

5. src/features/handoffs/handoff.controller.js
   - createHandoff, getMyHandoffs, getHandoffById, updateHandoff,
     submitHandoff, acknowledgeHandoff, deleteHandoff, getSpaceHandoffs
   - After submitHandoff: call notifyHandoffReceived()
   - After acknowledgeHandoff: call notifyHandoffAcknowledged()

6. src/features/media/media.controller.js
   - uploadFile (to Cloudinary), deleteFile

7. src/features/notifications/notification.controller.js
   - getNotifications, getUnreadCount, markAsRead, markAllAsRead, deleteNotification

After each controller, update the matching routes.js file to:
  const xController = require('./x.controller');
  (replace the inline placeholder object)

## Flutter app plan (Day 3)
Build screens in this order:
1. Phone entry → OTP → Profile setup (auth flow)
2. Spaces list → Space detail → Channel view (main navigation)
3. Message composer + real-time socket (core chat)
4. Handoff create → submit → acknowledge (killer feature)

## Monetization plan (don't build yet, keep in mind)
Free for individuals always.
Department plan: ₹999/month.
Hospital plan: ₹9999/month.
Never charge interns or residents — charge the institution.

## Design principles
- Feel clinical and trustworthy, not consumer chat
- Emergency messages visually distinct (red, different sound)
- Availability status always visible on member avatars
- Handoffs are the #1 differentiator — give them premium UX
