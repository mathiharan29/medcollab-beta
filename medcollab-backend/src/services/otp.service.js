/**
 * OTP SERVICE
 *
 * Responsibilities:
 * 1. Generate a cryptographically random 6-digit OTP
 * 2. Deliver it via SMS (MSG91 in production, console.log in dev)
 * 3. Verify a submitted OTP against the stored hash
 *
 * Why crypto.randomInt instead of Math.random()?
 * Math.random() is not cryptographically secure. An attacker who knows
 * the seed can predict future values. crypto.randomInt() uses the OS
 * entropy pool — truly unpredictable.
 *
 * OTP_BYPASS mode:
 * When OTP_BYPASS=true in .env, any phone number gets OTP "123456"
 * without sending an SMS. This lets you develop and test locally
 * without consuming MSG91 credits or a real phone.
 * NEVER enable this in production.
 */

const crypto = require('crypto');
const axios = require('axios');
const OTP = require('../features/auth/otp.model');
const logger = require('../utils/logger');

/**
 * Generate a cryptographically secure 6-digit OTP string
 * Returns a zero-padded string: e.g. "007423", "123456"
 */
const generateOtpCode = () => {
  // randomInt(min, max) is exclusive of max, so 0–999999
  const num = crypto.randomInt(0, 1000000);
  return num.toString().padStart(6, '0');
};

/**
 * Send an OTP to a phone number
 * Creates the OTP record in DB, then delivers via SMS (or console in dev)
 *
 * @param {string} phone - E.164 format: "+919876543210"
 * @returns {Promise<{ success: boolean, message: string }>}
 */
const sendOtp = async (phone) => {
  // Dev bypass — no SMS sent, always use "123456"
  if (process.env.OTP_BYPASS === 'true') {
    const bypassCode = '123456';
    await OTP.createOtp(phone, bypassCode);
    logger.debug(`OTP BYPASS — code for ${phone}: ${bypassCode}`);
    return { success: true, message: 'OTP sent (bypass mode)' };
  }

  // Generate real OTP
  const otpCode = generateOtpCode();

  // Store hashed OTP in database BEFORE sending SMS
  // If SMS fails, we don't leak an unhashed OTP into the DB
  await OTP.createOtp(phone, otpCode);

  // Deliver via MSG91 (preferred for India — cheap, reliable, supports DLT)
  try {
    await sendViaMSG91(phone, otpCode);
    logger.info(`OTP sent to ${phone}`);
    return { success: true, message: 'OTP sent successfully' };
  } catch (smsError) {
    logger.error(`SMS delivery failed for ${phone}: ${smsError.message}`);
    // OTP is in DB — they can retry. Don't expose the error to the client.
    throw new Error('Failed to send OTP. Please try again in a moment.');
  }
};

/**
 * Send SMS via MSG91
 * Requires MSG91_AUTH_KEY and MSG91_TEMPLATE_ID in environment
 *
 * MSG91 DLT requirements (India TRAI regulation):
 * - All commercial SMS must be registered on TRAI's DLT platform
 * - Template must be pre-approved
 * - For development, use MSG91's sandbox/test mode
 *
 * @param {string} phone - E.164 format phone number
 * @param {string} otpCode - 6-digit OTP
 */
const sendViaMSG91 = async (phone, otpCode) => {
  const authKey = process.env.MSG91_AUTH_KEY;
  const templateId = process.env.MSG91_TEMPLATE_ID;

  if (!authKey || !templateId) {
    throw new Error('MSG91 credentials not configured');
  }

  // Strip the + from E.164 format — MSG91 expects digits only
  const mobileNumber = phone.replace('+', '');

  const response = await axios.post(
    'https://control.msg91.com/api/v5/otp',
    {
      template_id: templateId,
      mobile: mobileNumber,
      authkey: authKey,
      otp: otpCode,
      // MSG91 will inject {{otp}} into your pre-approved template
    },
    {
      headers: { 'Content-Type': 'application/json' },
      timeout: 10000, // 10 second timeout — don't hang the request
    }
  );

  if (response.data?.type !== 'success') {
    throw new Error(`MSG91 error: ${JSON.stringify(response.data)}`);
  }
};

/**
 * Verify an OTP submitted by the user
 *
 * @param {string} phone - Phone number that requested the OTP
 * @param {string} otpCode - 6-digit code submitted by user
 * @returns {Promise<{ valid: boolean, reason?: string }>}
 */
const verifyOtp = async (phone, otpCode) => {
  // In bypass mode, accept "123456" without DB lookup for any phone
  if (process.env.OTP_BYPASS === 'true' && otpCode === '123456') {
    return { valid: true };
  }

  return OTP.verifyOtp(phone, otpCode);
};

module.exports = { sendOtp, verifyOtp };
