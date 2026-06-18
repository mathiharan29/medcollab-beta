/**
 * HANDOFF MODEL
 *
 * This is MedCollab's most important differentiator.
 * No other chat tool has structured clinical handoffs.
 * This is the feature that makes doctors say "I can't go back to WhatsApp."
 *
 * What a handoff is in clinical practice:
 * At the end of every shift, the outgoing doctor must brief the incoming
 * doctor about every active patient. This is a WHO patient safety standard.
 * Currently done via WhatsApp voice notes, rushed verbal briefings, or
 * paper handover sheets. All are lossy and dangerous.
 *
 * Our handoff solves:
 * - Structured patient-by-patient review
 * - Pending tasks explicitly listed (not buried in chat)
 * - Acknowledgement receipt (incoming doctor confirms they read it)
 * - Attached images (lab reports, ECGs, drug charts)
 * - Searchable history ("what happened to the patient in Bed 4 last Tuesday?")
 *
 * Privacy design:
 * - NO real patient names stored anywhere
 * - Patients are identified by: bed number + diagnosis alias
 * - "Bed 7 – ACS" not "Ramesh Kumar, MI"
 * - This is HIPAA/DPDP-conscious by default
 *
 * Status flow:
 * DRAFT → SUBMITTED → ACKNOWLEDGED
 *   |
 *   └── Only the sender sees drafts
 *       SUBMITTED becomes visible to the receiver
 *       ACKNOWLEDGED = receiver clicked "I've read this" (legally significant)
 */

const mongoose = require('mongoose');
const {
  HANDOFF_STATUS,
  SHIFT_TYPES,
  PATIENT_STATUS,
} = require('../../constants');

// ── Patient Entry Subdocument ─────────────────────────────────────────────────
const patientSchema = new mongoose.Schema(
  {
    // Physical location — how the incoming doctor finds the patient
    bedNumber: {
      type: String,
      required: [true, 'Bed number is required'],
      trim: true,
      maxlength: 20, // "7", "ICU-3", "CICU Bed 2"
    },

    ward: {
      type: String,
      trim: true,
      maxlength: 50, // "CICU", "Ward 4", "HDU"
    },

    // Anonymised clinical identifier — no real names
    // "65M with ACS", "28F post-LSCS Day 2"
    clinicalAlias: {
      type: String,
      required: [true, 'Clinical alias is required'],
      trim: true,
      maxlength: 100,
    },

    diagnosis: {
      type: String,
      trim: true,
      maxlength: 200,
    },

    // Current clinical state
    status: {
      type: String,
      enum: Object.values(PATIENT_STATUS),
      default: PATIENT_STATUS.STABLE,
    },

    // Free-text clinical summary
    // "Started on heparin infusion at 18 units/kg/hr. Repeat ECG at 2am."
    notes: {
      type: String,
      maxlength: 2000,
      default: '',
    },

    // Explicit checklist of outstanding tasks
    // Forces the handoff writer to think through what's pending
    pendingTasks: {
      type: [String],
      default: [],
      // e.g. ["Check 2am ECG", "Review K+ levels", "BP charting every 2h"]
    },

    // Attached media: lab reports, drug charts, ECG images
    attachments: [
      {
        url: { type: String },
        thumbnailUrl: { type: String },
        fileName: { type: String },
        mimeType: { type: String },
        uploadedAt: { type: Date, default: Date.now },
        _id: false,
      },
    ],

    // Flag patients needing urgent attention from the receiver
    isFlagged: {
      type: Boolean,
      default: false,
    },
  },
  { _id: true } // Patients DO get _id — we reference them in follow-up queries
);

// ── Handoff Schema ────────────────────────────────────────────────────────────
const handoffSchema = new mongoose.Schema(
  {
    spaceId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Space',
      required: true,
      index: true,
    },

    // The channel where this handoff was submitted
    // A system message appears in this channel linking to the handoff
    channelId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Channel',
      required: true,
    },

    // ── Participants ──────────────────────────────────────────────────────
    fromUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },

    toUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },

    // ── Shift Context ─────────────────────────────────────────────────────
    shiftDate: {
      type: Date,
      required: true,
    },

    shiftType: {
      type: String,
      enum: Object.values(SHIFT_TYPES),
      required: true,
    },

    // ── Patients ──────────────────────────────────────────────────────────
    patients: {
      type: [patientSchema],
      default: [],
      // A typical shift covers 5–20 patients
    },

    // ── Free-text shift summary ───────────────────────────────────────────
    // Overall shift notes beyond individual patients
    // "Quiet night. Two new admissions. Lab server was down 10pm-12am."
    shiftSummary: {
      type: String,
      maxlength: 2000,
      default: '',
    },

    // ── Status Lifecycle ──────────────────────────────────────────────────
    status: {
      type: String,
      enum: Object.values(HANDOFF_STATUS),
      default: HANDOFF_STATUS.DRAFT,
    },

    submittedAt: {
      type: Date,
      default: null,
    },

    acknowledgedAt: {
      type: Date,
      default: null,
    },

    // Optional acknowledgement note from the receiver
    // "Noted. Will check on Bed 7 first." (creates accountability)
    acknowledgementNote: {
      type: String,
      maxlength: 500,
      default: '',
    },
  },
  {
    timestamps: true,
  }
);

// ── Indexes ───────────────────────────────────────────────────────────────────
handoffSchema.index({ spaceId: 1, shiftDate: -1 });                      // List handoffs by space, recent first
handoffSchema.index({ toUserId: 1, status: 1 });                          // "Show me my pending handoffs"
handoffSchema.index({ fromUserId: 1, shiftDate: -1 });                    // "Show me handoffs I've sent"
handoffSchema.index({ spaceId: 1, shiftDate: 1, shiftType: 1 });          // Roster-style daily view

// ── Instance Methods ──────────────────────────────────────────────────────────

/**
 * Submit a draft handoff (makes it visible to the receiver)
 */
handoffSchema.methods.submit = function () {
  this.status = HANDOFF_STATUS.SUBMITTED;
  this.submittedAt = new Date();
  return this.save();
};

/**
 * Mark a handoff as acknowledged by the receiver
 */
handoffSchema.methods.acknowledge = function (note = '') {
  this.status = HANDOFF_STATUS.ACKNOWLEDGED;
  this.acknowledgedAt = new Date();
  this.acknowledgementNote = note;
  return this.save();
};

const Handoff = mongoose.model('Handoff', handoffSchema);
module.exports = Handoff;
