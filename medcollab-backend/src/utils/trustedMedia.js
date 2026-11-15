/**
 * Media URLs a client may store: our Cloudinary account (https) or this
 * server's own /uploads (local dev). Same rule as message media (sendMessage).
 */
const CLOUDINARY_HOSTS = ['res.cloudinary.com', 'cloudinary.com'];

const ownHosts = (req) => {
  const hosts = new Set(
    [req.hostname, req.get?.('host')?.split(':')[0]]
      .filter(Boolean)
      .map((h) => h.toLowerCase())
  );
  if (process.env.API_BASE_URL) {
    try {
      hosts.add(new URL(process.env.API_BASE_URL).hostname.toLowerCase());
    } catch {
      /* invalid config is caught at startup */
    }
  }
  return hosts;
};

const isTrustedMediaUrl = (raw, req) => {
  const url = String(raw || '');
  if (!url) return false;
  if (url.startsWith('/uploads/')) return !url.includes('..');
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }
  const host = parsed.hostname.toLowerCase();
  const isCloudinary =
    parsed.protocol === 'https:' &&
    CLOUDINARY_HOSTS.some((h) => host === h || host.endsWith(`.${h}`));
  const isLocalUpload =
    (parsed.protocol === 'http:' || parsed.protocol === 'https:') &&
    parsed.pathname.startsWith('/uploads/') &&
    (host === 'localhost' || host === '127.0.0.1' || host === '10.0.2.2' || ownHosts(req).has(host));
  return isCloudinary || isLocalUpload;
};

module.exports = { isTrustedMediaUrl };
