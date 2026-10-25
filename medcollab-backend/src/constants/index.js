/**
 * CONSTANTS
 *
 * All enums and string constants live here.
 * Never use raw strings like 'admin' or 'emergency' in business logic.
 * Always import from here. This prevents typos and makes refactoring easy.
 */

// ─── User Roles ────────────────────────────────────────────────────────────────
const USER_ROLES = {
  MBBS_STUDENT: 'mbbs_student',
  INTERN: 'intern',
  PG_RESIDENT: 'pg_resident',
  JUNIOR_CONSULTANT: 'junior_consultant',
  CONSULTANT: 'consultant',
  NURSE: 'nurse',
  OTHER: 'other',
};

// ─── Availability Status ───────────────────────────────────────────────────────
// Doctors can set these to signal to their team where they are
const AVAILABILITY_STATUS = {
  AVAILABLE: 'available',
  ON_CALL: 'on_call',
  IN_OT: 'in_ot',          // In operating theatre
  IN_ICU: 'in_icu',
  ON_ROUNDS: 'on_rounds',
  OFF_DUTY: 'off_duty',
  DO_NOT_DISTURB: 'do_not_disturb',
  OFFLINE: 'offline',      // Explicitly offline / not reachable via Vocle
};

// ─── Space Types ───────────────────────────────────────────────────────────────
// A Space is the top-level container (like a Slack workspace)
const SPACE_TYPES = {
  DEPARTMENT: 'department',     // Cardiology, General Medicine
  COLLEGE: 'college',           // AIIMS PG batch
  HOSPITAL: 'hospital',         // Apollo Hospital
  COMMUNITY: 'community',       // Open medical community
};

// ─── Space Member Roles ────────────────────────────────────────────────────────
const SPACE_ROLES = {
  OWNER: 'owner',       // Created the space, full control
  ADMIN: 'admin',       // Can manage members and channels
  MEMBER: 'member',     // Regular participant
};

// ─── Channel Types ─────────────────────────────────────────────────────────────
const CHANNEL_TYPES = {
  GENERAL: 'general',           // Normal group discussion
  EMERGENCY: 'emergency',       // High-priority alerts — different notification sound
  ACADEMIC: 'academic',         // Case discussions, journal clubs
  ANNOUNCEMENTS: 'announcements', // One-way broadcasting by admins
  DIRECT: 'direct',             // 1:1 DM between two users
};

// ─── Message Types ─────────────────────────────────────────────────────────────
const MESSAGE_TYPES = {
  TEXT: 'text',
  IMAGE: 'image',         // X-rays, clinical photos
  VIDEO: 'video',         // Short clinical clips
  DOCUMENT: 'document',   // PDF reports, discharge summaries
  ECG: 'ecg',             // ECG strips (image, but categorised separately for UI)
  HANDOFF: 'handoff',     // System message when a handoff is submitted
  ALERT: 'alert',         // System-generated emergency alert
};

// ─── Message Priority ──────────────────────────────────────────────────────────
// Controls notification sound and visual treatment on the client
const MESSAGE_PRIORITY = {
  NORMAL: 'normal',
  URGENT: 'urgent',       // Orange indicator
  EMERGENCY: 'emergency', // Red indicator, loud notification, wakes screen
};

// ─── Handoff Status ────────────────────────────────────────────────────────────
const HANDOFF_STATUS = {
  DRAFT: 'draft',               // Being written, not visible to receiver yet
  SUBMITTED: 'submitted',       // Sent to incoming doctor
  ACKNOWLEDGED: 'acknowledged', // Incoming doctor confirmed receipt
};

// ─── Shift Types ──────────────────────────────────────────────────────────────
const SHIFT_TYPES = {
  MORNING: 'morning',     // ~8am–2pm
  EVENING: 'evening',     // ~2pm–8pm
  NIGHT: 'night',         // ~8pm–8am
};

// ─── Patient Status (inside handoff) ──────────────────────────────────────────
const PATIENT_STATUS = {
  STABLE: 'stable',
  MONITORING: 'monitoring',
  CRITICAL: 'critical',
  IMPROVING: 'improving',
  DETERIORATING: 'deteriorating',
};

// ─── Notification Types ────────────────────────────────────────────────────────
const NOTIFICATION_TYPES = {
  NEW_MESSAGE: 'new_message',
  MENTION: 'mention',
  THREAD_REPLY: 'thread_reply',
  HANDOFF_RECEIVED: 'handoff_received',
  HANDOFF_ACKNOWLEDGED: 'handoff_acknowledged',
  EMERGENCY_ALERT: 'emergency_alert',
  SPACE_INVITE: 'space_invite',
  ROSTER_UPDATE: 'roster_update',
  MESSAGE_REQUEST: 'message_request',
};

// ─── Message request status ────────────────────────────────────────────────────
const MESSAGE_REQUEST_STATUS = {
  PENDING: 'pending',
  ACCEPTED: 'accepted',
  DECLINED: 'declined',
  BLOCKED: 'blocked',
};

// ─── Pagination ────────────────────────────────────────────────────────────────
const PAGINATION = {
  MESSAGES_LIMIT: 30,       // Messages per page (WhatsApp-like)
  DEFAULT_LIMIT: 20,
  MAX_LIMIT: 100,
};

// ─── Media ─────────────────────────────────────────────────────────────────────
const MEDIA = {
  MAX_FILE_SIZE_MB: 50,
  MAX_FILE_SIZE_BYTES: 50 * 1024 * 1024,
  ALLOWED_IMAGE_TYPES: ['image/jpeg', 'image/png', 'image/webp'],
  ALLOWED_DOCUMENT_TYPES: ['application/pdf'],
  ALLOWED_TYPES: [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
    'video/mp4',
    'video/quicktime',
    'video/webm',
    'video/3gpp',
    'application/pdf',
  ],
};

// ─── Socket Events ─────────────────────────────────────────────────────────────
// Single source of truth for all socket event names
// Import this on both server and (eventually) Flutter via a shared spec doc
const SOCKET_EVENTS = {
  // Connection lifecycle
  CONNECT: 'connect',
  DISCONNECT: 'disconnect',
  AUTHENTICATE: 'authenticate',
  AUTHENTICATED: 'authenticated',
  AUTH_ERROR: 'auth_error',

  // Room management
  JOIN_CHANNEL: 'join_channel',
  LEAVE_CHANNEL: 'leave_channel',
  SYNC_SPACE_ROOMS: 'sync_space_rooms',

  // Messaging
  SEND_MESSAGE: 'send_message',
  NEW_MESSAGE: 'new_message',
  MESSAGE_UPDATED: 'message_updated',
  MESSAGE_DELETED: 'message_deleted',

  // Typing indicators
  TYPING_START: 'typing_start',
  TYPING_STOP: 'typing_stop',
  USER_TYPING: 'user_typing',
  USER_STOPPED_TYPING: 'user_stopped_typing',

  // Presence
  UPDATE_AVAILABILITY: 'update_availability',
  PRESENCE_UPDATE: 'presence_update',

  // Notifications
  NEW_NOTIFICATION: 'new_notification',

  // Handoffs
  HANDOFF_SUBMITTED: 'handoff_submitted',
  HANDOFF_ACKNOWLEDGED: 'handoff_acknowledged',
  HANDOFF_NOTE_ADDED: 'handoff_note_added',
  HANDOFF_REASSIGNED: 'handoff_reassigned',

  // Spaces
  SPACE_MEMBER_JOINED: 'space_member_joined',
  SPACE_MEMBER_LEFT: 'space_member_left',

  // Errors
  ERROR: 'error',
};

module.exports = {
  USER_ROLES,
  AVAILABILITY_STATUS,
  SPACE_TYPES,
  SPACE_ROLES,
  CHANNEL_TYPES,
  MESSAGE_TYPES,
  MESSAGE_PRIORITY,
  HANDOFF_STATUS,
  SHIFT_TYPES,
  PATIENT_STATUS,
  NOTIFICATION_TYPES,
  MESSAGE_REQUEST_STATUS,
  PAGINATION,
  MEDIA,
  SOCKET_EVENTS,
};
