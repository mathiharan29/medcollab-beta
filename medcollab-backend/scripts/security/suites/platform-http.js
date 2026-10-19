'use strict';
const assert = require('node:assert/strict');
const supervise = require('../local-supervisor');
const oid = value => String(value?._id || value);
module.exports = ({ add, ids }) => {
  const routes = ['seed-conversation', 'seed-handoff', 'seed-notifications'];
  const reg = (name, actor, endpoint, statuses, options) => add(name, actor, 'POST', endpoint, statuses, undefined, {
    module: 'Developer and Platform HTTP', category: 'developer-authorization', sources: ['src/features/dev/dev.routes.js', 'src/middleware/auth.js'],
    securityInvariant: 'Developer writes require the enabled configuration and an active authenticated caller; body identity/resource fields cannot redirect the write.', ...options,
  });
  for (const route of routes) {
    const endpoint = `/api/dev/${route}`;
    reg(`production disabled developer guard ${route}`, 'A', endpoint, [403], {
      context: 'Unchanged Express app under production configuration in disposable local test entrypoint; full production startup requires Cloudinary and is not exercised.',
      run: async c => { const p = await supervise(c, 'production-routes'); c.evidence.configuration = 'production, ENABLE_DEV_TOOLS=false'; c.evidence.providerCredentialsAbsent = true; return p.http('A', 'POST', endpoint, {}); },
    });
    reg(`production developer override still requires auth ${route}`, 'anonymous', endpoint, [401], {
      run: async c => { const p = await supervise(c, 'production-routes', true); c.evidence.configuration = 'production, ENABLE_DEV_TOOLS=true'; return p.http('anonymous', 'POST', endpoint, {}); },
    });
    reg(`enabled developer anonymous denial ${route}`, 'anonymous', endpoint, [401], {});
    reg(`enabled developer inactive denial ${route}`, 'anonymous', endpoint, [401], {
      run: c => c.http('anonymous', 'POST', endpoint, {}, `Bearer ${require('jsonwebtoken').sign({ userId: oid(c.users.I) }, process.env.JWT_SECRET, { expiresIn: 60 })}`),
    });
    reg(`developer seed binds caller despite forged body ${route}`, 'A', endpoint, [200], {
      prepare: async c => { if (route === 'seed-handoff') await c.models.Channel.updateOne({ _id: ids.channel }, { name: 'general' }); },
      body: { userId: ':C', fromUserId: ':C', toUserId: ':C', spaceId: ids.otherSpace, channelId: ids.otherChannel },
      check: async (body, c) => {
        if (route === 'seed-conversation') {
          const m = await c.models.Message.findById(body.data?.messageId).lean();
          c.evidence.boundCaller = oid(m?.senderId) === oid(c.users.A); c.evidence.boundChannel = oid(m?.channelId) === ids.dmAB;
          return c.evidence.boundCaller && c.evidence.boundChannel && body.data?.channelId === ids.dmAB;
        }
        if (route === 'seed-handoff') {
          const h = await c.models.Handoff.findById(body.data?.handoffId).lean();
          c.evidence.boundCaller = oid(h?.fromUserId) === oid(c.users.A) && oid(h?.toUserId) === oid(c.users.A);
          return c.evidence.boundCaller && oid(h?.spaceId) === ids.space && oid(h?.channelId) === ids.channel && h.status === 'draft';
        }
        c.evidence.responseValidationFields = (body.errors || []).map(x => x.field).sort();
        const n = await c.models.Notification.find({ userId: { $in: Object.values(c.users).map(u => u._id) } }).lean();
        c.evidence.notificationRecipients = n.map(x => oid(x.userId));
        return body.data?.count === 3 && n.length === 3 && n.every(x => oid(x.userId) === oid(c.users.A));
      },
    });
  }
  async function platform(c, endpoint, verify, status = 200) {
    assert.ok(endpoint === '/' || endpoint === '/api' || endpoint === '/health' || endpoint.startsWith('/join/'));
    const url = new URL(endpoint, 'http://127.0.0.1:5000'); assert.equal(url.origin, 'http://127.0.0.1:5000');
    const r = await fetch(url, { redirect: 'error', signal: AbortSignal.timeout(5000) });
    const text = await r.text();
    c.evidence.actualStatus = r.status; c.evidence.contentType = r.headers.get('content-type');
    c.evidence.nosniff = r.headers.get('x-content-type-options'); c.evidence.expressHeaderAbsent = !r.headers.has('x-powered-by');
    c.evidence.platformInvariant = verify(text, c) && c.evidence.nosniff === 'nosniff' && c.evidence.expressHeaderAbsent;
    // Platform endpoints do not use the API envelope. Preserve actual status and
    // contract evidence; normalize only the harness envelope, never the result.
    c.evidence.envelopeNormalization = 'platform JSON/HTML, actual HTTP status retained';
    return { status: r.status, nativeResponseKind: c.evidence.contentType?.includes('application/json') ? 'json' : 'html', data: { success: r.status < 400 } };
  }
  for (const [endpoint, fields] of [ ['/', ['api', 'health', 'name', 'status']], ['/api', ['endpoints', 'name', 'status', 'version']], ['/health', ['analytics', 'cloudinary', 'database', 'environment', 'firebase', 'status', 'timestamp', 'uptime']] ]) add(`public platform metadata allowlist ${endpoint}`, 'anonymous', 'GET', endpoint, [200], undefined, {
    module: 'Developer and Platform HTTP', category: 'platform-data-minimization', sources: ['src/app.js'],
    securityInvariant: 'Public metadata has only the source-defined non-sensitive fields, safe relative API hints and standard security headers.',
    run: c => platform(c, endpoint, (text, ctx) => {
      const body = JSON.parse(text); ctx.evidence.returnedFields = Object.keys(body).sort();
      return JSON.stringify(ctx.evidence.returnedFields) === JSON.stringify(fields) &&
        (endpoint !== '/health' || (body.database === 'connected' && body.environment === 'test' && body.firebase === false && body.cloudinary === false)) &&
        (endpoint !== '/api' || Object.values(body.endpoints).every(v => typeof v === 'string' && v.startsWith('/api/')));
    }), check: (_, c) => c.evidence.platformInvariant,
  });
  for (const [name, input, status, canonical] of [
    ['canonical synthetic code', 'DSCABA', 200, 'DSCABA'],
    ['short code rejected', 'abc', 400, null],
    ['HTML attribute injection sanitized', 'ABCD\" onclick=\"alert(1)\"<svg/onload=alert(2)>', 200, 'ABCDONCLICKALERT1SVGONLOADALERT2'],
    ['script boundary injection sanitized', "ABCD</script><script>alert(1)</script>", 200, 'ABCDSCRIPTSCRIPTALERT1SCRIPT'],
  ]) {
    const endpoint = `/join/${encodeURIComponent(input)}`;
    add(`deep link ${name}`, 'anonymous', 'GET', endpoint, [status], undefined, {
      module: 'Developer and Platform HTTP', category: 'platform-deeplink-boundary', sources: ['src/app.js'],
      securityInvariant: 'Invite landing sanitizes caller code into A-Z0-9 in HTML/script/URL contexts, rejects short values, and never joins a space or discloses space data.',
      run: c => platform(c, endpoint, (text, ctx) => {
        ctx.evidence.canonicalCode = canonical; ctx.evidence.scriptCount = (text.match(/<script>/g) || []).length;
        return status === 400 ? !text.includes('medcollab:///join/') :
          text.includes(`<p class="code">${canonical}</p>`) && text.includes(`href="medcollab:///join/${canonical}"`) && ctx.evidence.scriptCount === 1 && (input === canonical || !text.includes(input)) && !text.includes('Discovery AB');
      }, status),
      check: (_, c) => c.evidence.platformInvariant,
    });
  }
};
