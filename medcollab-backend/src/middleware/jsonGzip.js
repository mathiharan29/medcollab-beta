/**
 * Gzip JSON API responses (beta 11-14, issue 2 — slow lists on mobile data).
 *
 * Chat lists, timelines and notification pages are repetitive JSON that
 * shrinks 5–10× with gzip; nothing in the stack compressed them. Dependency
 * free (Node's zlib). Small bodies are sent as is (gzip would not pay off).
 * The Flutter client (dart:io HttpClient) decompresses transparently.
 */
const zlib = require('zlib');

const MIN_BYTES = 1024;

const jsonGzip = (req, res, next) => {
  const accepts = String(req.headers['accept-encoding'] || '');
  if (!/\bgzip\b/.test(accepts)) return next();

  const send = res.send.bind(res);
  res.json = function json(body) {
    const text = JSON.stringify(body);
    if (!res.get('Content-Type')) res.set('Content-Type', 'application/json; charset=utf-8');
    if (Buffer.byteLength(text) < MIN_BYTES || res.get('Content-Encoding')) {
      return send(text);
    }
    const gz = zlib.gzipSync(text, { level: 6 });
    res.set('Content-Encoding', 'gzip');
    res.append('Vary', 'Accept-Encoding');
    res.set('Content-Length', String(gz.length));
    return send(gz);
  };
  return next();
};

module.exports = { jsonGzip };
