const expectedOrigin = 'http://127.0.0.1:5000';

export async function request(path, { method = 'GET', token, body, formData, expectedStatus = 200 } = {}) {
  const origin = process.env.SANITY_ORIGIN || expectedOrigin;
  if (origin !== expectedOrigin) throw new Error(`Rejected non-local sanity origin: ${origin}`);
  const response = await fetch(new URL(path, origin), {
    method,
    redirect: 'error',
    headers: {
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body === undefined || formData ? {} : { 'Content-Type': 'application/json' }),
    },
    body: formData || (body === undefined ? undefined : JSON.stringify(body)),
    signal: AbortSignal.timeout(10_000),
  });
  const payload = await response.json().catch(() => null);
  if (response.status !== expectedStatus) throw new Error(`${method} ${path} expected ${expectedStatus}, received ${response.status}: ${JSON.stringify(payload)}`);
  return payload;
}

export async function download(path, token) {
  const origin = process.env.SANITY_ORIGIN || expectedOrigin;
  const url = new URL(path, origin);
  if (origin !== expectedOrigin || url.origin !== expectedOrigin) throw new Error(`Rejected non-local download origin: ${url.origin}`);
  const response = await fetch(url, { redirect: 'error', headers: token ? { Authorization: `Bearer ${token}` } : {}, signal: AbortSignal.timeout(10_000) });
  if (!response.ok) throw new Error(`Download ${url.pathname} failed with ${response.status}.`);
  return new Uint8Array(await response.arrayBuffer());
}

export function expectSuccess(payload, label) {
  if (!payload?.success || !payload.data) throw new Error(`${label} did not return the standard success response.`);
  return payload.data;
}
