import { createRequire } from 'node:module';
import { join } from 'node:path';

let mongoose;
let User;
let OTP;
let Message;
let Notification;
let Handoff;
let SupportTicket;

export async function connectDatabase() {
  const backendDirectory = process.env.SANITY_BACKEND_DIR;
  const uri = process.env.SANITY_DATABASE_URI || 'mongodb://127.0.0.1:27017/vocle_sanity';
  if (!backendDirectory) throw new Error('SANITY_BACKEND_DIR is required for independent database checks.');
  const backendRequire = createRequire(join(backendDirectory, 'package.json'));
  mongoose = backendRequire('mongoose');
  User = backendRequire(join(backendDirectory, 'src/features/users/user.model.js'));
  OTP = backendRequire(join(backendDirectory, 'src/features/auth/otp.model.js'));
  Message = backendRequire(join(backendDirectory, 'src/features/messages/message.model.js'));
  Notification = backendRequire(join(backendDirectory, 'src/features/notifications/notification.model.js'));
  Handoff = backendRequire(join(backendDirectory, 'src/features/handoffs/handoff.model.js'));
  ({ SupportTicket } = backendRequire(join(backendDirectory, 'src/features/support/support.controller.js')));
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 10_000 });
}

export async function closeDatabase() {
  await mongoose?.disconnect();
}

export async function userByPhone(phone) {
  return User.findOne({ phone }).lean();
}

export async function newestOtp(phone) {
  return OTP.findOne({ phone }).sort({ createdAt: -1 }).lean();
}

export async function messageById(id) {
  return Message.findById(id).lean();
}

export async function notificationFor(userId, referenceId) {
  return Notification.findOne({ userId, referenceId }).sort({ createdAt: -1 }).lean();
}

export async function handoffById(id) {
  return Handoff.findById(id).lean();
}

export async function supportTicketById(id) {
  return SupportTicket.findById(id).lean();
}
