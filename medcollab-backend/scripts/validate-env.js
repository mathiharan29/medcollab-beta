#!/usr/bin/env node
/**
 * Validate environment variables before production deploy.
 * Usage: node scripts/validate-env.js
 * Exit 0 = ready, exit 1 = missing required vars.
 */

require('dotenv').config();

const NODE_ENV = process.env.NODE_ENV || 'development';
const isProd = NODE_ENV === 'production';

const required = ['JWT_SECRET', 'JWT_REFRESH_SECRET'];
if (isProd) {
  required.push('MONGODB_URI');
}

const warnings = [];
const errors = [];

for (const key of required) {
  if (!process.env[key]) {
    errors.push(`Missing required: ${key}`);
  }
}

if (isProd && process.env.OTP_BYPASS === 'true') {
  errors.push('OTP_BYPASS must not be true in production');
}

const cloudinaryOk = Boolean(
  process.env.CLOUDINARY_CLOUD_NAME &&
  process.env.CLOUDINARY_API_KEY &&
  process.env.CLOUDINARY_API_SECRET &&
  process.env.CLOUDINARY_CLOUD_NAME !== 'your_cloud_name',
);

if (isProd && !cloudinaryOk) {
  warnings.push('Cloudinary not configured — use Cloudinary for beta media storage');
}

if (isProd && !process.env.MSG91_AUTH_KEY) {
  warnings.push('MSG91_AUTH_KEY missing — OTP SMS will not work');
}

if (isProd && !process.env.MSG91_TEMPLATE_ID) {
  warnings.push('MSG91_TEMPLATE_ID missing — OTP SMS will not work');
}

if (isProd && !cloudinaryOk && !process.env.API_BASE_URL) {
  warnings.push('API_BASE_URL missing — local media URLs will be wrong');
}

if (process.env.JWT_SECRET && process.env.JWT_SECRET.length < 32) {
  warnings.push('JWT_SECRET should be at least 32 characters (64+ recommended)');
}

console.log(`\nMedCollab env validation (${NODE_ENV})\n${'─'.repeat(40)}`);

if (errors.length === 0 && warnings.length === 0) {
  console.log('✓ All required variables present\n');
  process.exit(0);
}

warnings.forEach((w) => console.log(`⚠ ${w}`));
errors.forEach((e) => console.log(`✗ ${e}`));
console.log('');

process.exit(errors.length > 0 ? 1 : 0);
