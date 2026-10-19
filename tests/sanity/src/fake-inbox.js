import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

export async function latestOtp(phone) {
  const directory = process.env.SANITY_PROVIDER_INBOX;
  if (!directory) throw new Error('SANITY_PROVIDER_INBOX is required.');
  const lines = (await readFile(join(directory, 'msg91-inbox.ndjson'), 'utf8')).trim().split('\n');
  const match = lines.map((line) => JSON.parse(line)).reverse().find((entry) => entry.type === 'otp' && entry.mobile === phone.replace('+', ''));
  if (!match || !/^\d{6}$/.test(match.otp)) throw new Error(`No valid captured OTP for ${phone}.`);
  return match.otp;
}
