/**
 * MSG91 OTP Widget — server-side access token verification.
 *
 * Client flow: Flutter SDK sendOTP → verifyOTP → access token
 * Server flow: verify token with MSG91 → find/create user → issue JWT
 *
 * Docs: https://docs.msg91.com/otp-widget/verify-access-token
 */

const axios = require('axios');
const logger = require('../utils/logger');

const VERIFY_URL = 'https://control.msg91.com/api/v5/widget/verifyAccessToken';

const normalizePhoneToE164 = (raw) => {
  if (!raw || typeof raw !== 'string') return null;

  const trimmed = raw.trim();
  if (trimmed.includes('@')) return null;

  const digits = trimmed.replace(/\D/g, '');
  if (digits.length < 10) return null;

  if (trimmed.startsWith('+')) {
    return `+${digits}`;
  }

  if (digits.length === 10) {
    return `+91${digits}`;
  }

  return `+${digits}`;
};

const extractVerifiedPhone = (data) => {
  const candidate =
    data?.mobile ||
    data?.phone ||
    data?.identifier ||
    data?.mobile_no ||
    data?.mobileNo;

  return normalizePhoneToE164(candidate);
};

/**
 * Verify MSG91 widget access token and return normalized E.164 phone.
 *
 * @param {string} accessToken - JWT from OTPWidget.verifyOTP on the client
 * @returns {Promise<{ phone: string, raw: object }>}
 */
const verifyWidgetAccessToken = async (accessToken) => {
  const authKey = process.env.MSG91_AUTH_KEY;
  if (!authKey) {
    throw new Error('MSG91_AUTH_KEY is not configured');
  }

  const response = await axios.post(
    VERIFY_URL,
    {
      authkey: authKey,
      'access-token': accessToken,
    },
    {
      headers: { 'Content-Type': 'application/json' },
      timeout: 10000,
    },
  );

  const data = response.data;
  if (data?.type !== 'success') {
    logger.warn(`MSG91 verifyAccessToken failed: ${JSON.stringify(data)}`);
    throw new Error('Invalid or expired OTP session');
  }

  const phone = extractVerifiedPhone(data);
  if (!phone) {
    logger.warn(`MSG91 verifyAccessToken missing phone: ${JSON.stringify(data)}`);
    throw new Error('Could not resolve verified phone number');
  }

  return { phone, raw: data };
};

module.exports = { verifyWidgetAccessToken, normalizePhoneToE164 };
