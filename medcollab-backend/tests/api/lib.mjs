// Tiny API harness for a LOCAL backend (see dev-backend.js). Never production.
export const BASE = process.env.VOCLE_API || 'http://127.0.0.1:5001';
if (/railway\.app/.test(BASE)) throw new Error('Refusing to run tests against production');

export async function api(token, method, path, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  try { json = await res.json(); } catch { /* empty */ }
  return { status: res.status, body: json, data: json?.data };
}

let counter = 0;
/** Sign in (OTP bypass) and finish onboarding. Returns { token, id, phone, name }. */
export async function doctor(name, extra = {}) {
  counter += 1;
  const phone = extra.phone || `+9197${String(Date.now()).slice(-6)}${String(counter).padStart(2, '0')}`;
  await api(null, 'POST', '/api/auth/request-otp', { phone });
  const v = await api(null, 'POST', '/api/auth/verify-otp', { phone, otp: '123456' });
  if (v.status !== 200) throw new Error(`login failed ${v.status} ${JSON.stringify(v.body)}`);
  const token = v.data.accessToken || v.data.tokens?.accessToken;
  const { phone: _p, ...profile } = extra;
  const u = await api(token, 'PUT', '/api/users/me', {
    name, role: 'pg_resident', speciality: 'Medicine', ...profile,
  });
  if (u.status !== 200) throw new Error(`onboard failed ${u.status} ${JSON.stringify(u.body)}`);
  return { token, id: u.data.user._id || u.data.user.id, phone, name };
}

/** A group (space) with `members` joined via invite. Returns { spaceId, general }. */
export async function ward(owner, members, name = 'Ward 5') {
  const s = await api(owner.token, 'POST', '/api/spaces', { name, type: 'department' });
  if (s.status !== 201) throw new Error(`space ${s.status} ${JSON.stringify(s.body)}`);
  const space = s.data.space;
  for (const m of members) {
    const j = await api(m.token, 'POST', '/api/spaces/join', { inviteCode: space.inviteCode });
    if (j.status !== 200) throw new Error(`join ${j.status} ${JSON.stringify(j.body)}`);
  }
  const general = (s.data.channels || []).find((c) => c.name === 'general') || s.data.channels[0];
  return { spaceId: space._id, general: general._id };
}

/** 1:1 chat between a and b via request → accept. Returns channelId. */
export async function dmBetween(a, b) {
  const direct = await api(a.token, 'POST', '/api/channels/dm', { userId: b.id });
  if (direct.status === 200 || direct.status === 201) return direct.data.channel._id;
  const r = await api(a.token, 'POST', '/api/message-requests', { toUserId: b.id, introMessage: 'Hi' });
  const reqId = r.data?.request?.id || r.data?.request?._id;
  const acc = await api(b.token, 'POST', `/api/message-requests/${reqId}/accept`);
  if (acc.status !== 200) throw new Error(`accept ${acc.status} ${JSON.stringify(acc.body)}`);
  const again = await api(a.token, 'POST', '/api/channels/dm', { userId: b.id });
  if (again.status !== 200 && again.status !== 201) throw new Error(`dm ${again.status}`);
  return again.data.channel._id;
}

export const send = async (who, channelId, text, extra = {}) => {
  const r = await api(who.token, 'POST', `/api/channels/${channelId}/messages`, {
    type: 'text', content: { text }, ...extra,
  });
  if (r.status !== 201) throw new Error(`send ${r.status} ${JSON.stringify(r.body)}`);
  return r.data.message;
};

const results = [];
export async function check(name, fn) {
  try {
    await fn();
    results.push({ name, ok: true });
    console.log(`  PASS  ${name}`);
  } catch (e) {
    results.push({ name, ok: false, err: e.message });
    console.log(`  FAIL  ${name}\n        ${e.message}`);
  }
}
export function eq(actual, expected, label = '') {
  const a = JSON.stringify(actual), b = JSON.stringify(expected);
  if (a !== b) throw new Error(`${label} expected ${b}, got ${a}`);
}
export function ok(cond, label) {
  if (!cond) throw new Error(label || 'assertion failed');
}
export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export function summary(title) {
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${title}: ${results.length - failed.length}/${results.length} passed`);
  process.exitCode = failed.length ? 1 : 0;
}
