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

const stripEnvQuotes = (value) => {
  if (!value || typeof value !== 'string') return '';
  return value.trim().replace(/^["']|["']$/g, '');
};

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

const decodeJwtPayload = (token) => {
  const parts = token.split('.');
  if (parts.length < 2) return null;

  try {
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
    const json = Buffer.from(padded, 'base64').toString('utf8');
    return JSON.parse(json);
  } catch {
    return null;
  }
};

const extractPhoneFromJwt = (token) => {
  const payload = decodeJwtPayload(token);
  if (!payload || typeof payload !== 'object') return null;

  return normalizePhoneToE164(
    payload.mobile ||
      payload.phone ||
      payload.identifier ||
      payload.sub ||
      payload.msisdn,
  );
};

const extractVerifiedPhone = (data) => {
  const candidates = [
    data?.mobile,
    data?.phone,
    data?.identifier,
    data?.mobile_no,
    data?.mobileNo,
    data?.data?.mobile,
    data?.data?.phone,
    data?.data?.identifier,
  ];

  for (const candidate of candidates) {
    const phone = normalizePhoneToE164(candidate);
    if (phone) return phone;
  }

  const message = data?.message;
  if (typeof message === 'string') {
    const digits = message.replace(/\D/g, '');
    if (digits.length >= 10 && digits.length <= 15 && !message.includes('.')) {
      return normalizePhoneToE164(digits);
    }
  }

  return null;
};

const isVerifySuccess = (data, httpStatus) => {
  if (!data) return httpStatus >= 200 && httpStatus < 300;

  const type = data.type?.toString().toLowerCase();
  if (type === 'success') return true;

  const message = data.message?.toString().toLowerCase() || '';
  if (message.includes('verified') || message.includes('success')) return true;

  return false;
};

const callVerifyAccessToken = async (authKey, accessToken) => {
  const attempts = [
    async () => {
      const params = new URLSearchParams();
      params.set('authkey', authKey);
      params.set('access-token', accessToken);
      return axios.post(VERIFY_URL, params.toString(), {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        timeout: 15000,
        validateStatus: () => true,
      });
    },
    async () =>
      axios.post(
        VERIFY_URL,
        { authkey: authKey, 'access-token': accessToken },
        {
          headers: { 'Content-Type': 'application/json' },
          timeout: 15000,
          validateStatus: () => true,
        },
      ),
  ];

  let lastResponse;
  for (const attempt of attempts) {
    lastResponse = await attempt();
    if (isVerifySuccess(lastResponse.data, lastResponse.status)) {
      return lastResponse;
    }
  }

  return lastResponse;
};

/**
 * Verify MSG91 widget access token and return normalized E.164 phone when available.
 *
 * @param {string} accessToken - JWT from OTPWidget.verifyOTP on the client
 * @returns {Promise<{ phone: string|null, raw: object }>}
 */
const verifyWidgetAccessToken = async (accessToken) => {
  const authKey = stripEnvQuotes(process.env.MSG91_AUTH_KEY);
  if (!authKey) {
    throw new Error('MSG91_AUTH_KEY is not configured');
  }

  const token = stripEnvQuotes(accessToken);
  if (!token) {
    throw new Error('Access token is required');
  }

  const response = await callVerifyAccessToken(authKey, token);
  const data = response.data;

  if (!isVerifySuccess(data, response.status)) {
    logger.warn(
      `MSG91 verifyAccessToken failed (HTTP ${response.status}): ${JSON.stringify(data)}`,
    );
    const apiMessage =
      typeof data?.message === 'string' ? data.message : 'Invalid or expired OTP session';
    throw new Error(apiMessage);
  }

  const phone = extractVerifiedPhone(data) || extractPhoneFromJwt(token);
  if (!phone) {
    logger.warn(
      `MSG91 verifyAccessToken ok but phone not in payload: ${JSON.stringify(data)}`,
    );
  }

  return { phone, raw: data };
};

module.exports = { verifyWidgetAccessToken, normalizePhoneToE164 };
