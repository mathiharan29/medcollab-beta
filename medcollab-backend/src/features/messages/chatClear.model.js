/**
 * CHAT CLEAR — "Clear chat" is personal (WhatsApp-style): it hides every
 * message up to `clearedAt` for one user only. Other members keep theirs.
 */
const mongoose = require('mongoose');

const chatClearSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    channelId: { type: mongoose.Schema.Types.ObjectId, ref: 'Channel', required: true },
    clearedAt: { type: Date, required: true },
  },
  { timestamps: true }
);

chatClearSchema.index({ userId: 1, channelId: 1 }, { unique: true });

module.exports = mongoose.model('ChatClear', chatClearSchema);
