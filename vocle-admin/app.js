(() => {
  const API_BASE = String(window.VOCLE_ADMIN_API || 'http://localhost:5000').replace(
    /\/$/,
    ''
  );
  const TOKEN_KEY = 'vocle_admin_access';
  const REFRESH_KEY = 'vocle_admin_refresh';
  const root = document.getElementById('root');

  const state = {
    admin: null,
    overview: null,
    growth: null,
    retention: null,
    infrastructure: null,
    users: [],
    pagination: null,
    filter: 'pending',
    q: '',
    error: '',
    busyId: '',
    loginStep: 'phone',
    phone: '',
    otp: '',
    loginBusy: false,
    loginError: '',
    ready: false,
  };

  const isLocalApi = /localhost|127\.0\.0\.1/.test(API_BASE);

  function getAccessToken() {
    return localStorage.getItem(TOKEN_KEY);
  }
  function getRefreshToken() {
    return localStorage.getItem(REFRESH_KEY);
  }
  function setTokens({ accessToken, refreshToken }) {
    if (accessToken) localStorage.setItem(TOKEN_KEY, accessToken);
    if (refreshToken) localStorage.setItem(REFRESH_KEY, refreshToken);
  }
  function clearTokens() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(REFRESH_KEY);
  }

  async function parseEnvelope(res) {
    const json = await res.json().catch(() => ({}));
    if (!res.ok || json.success === false) {
      const err = new Error(json.message || `Request failed (${res.status})`);
      err.status = res.status;
      err.errors = json.errors;
      throw err;
    }
    return json.data;
  }

  async function tryRefresh() {
    const refreshToken = getRefreshToken();
    if (!refreshToken) return false;
    try {
      const res = await fetch(`${API_BASE}/api/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) {
        clearTokens();
        return false;
      }
      setTokens({
        accessToken: json.data.accessToken,
        refreshToken: json.data.refreshToken || refreshToken,
      });
      return true;
    } catch {
      clearTokens();
      return false;
    }
  }

  async function api(path, { method = 'GET', body, auth = true } = {}) {
    const headers = { 'Content-Type': 'application/json' };
    if (auth && getAccessToken()) {
      headers.Authorization = `Bearer ${getAccessToken()}`;
    }
    let res = await fetch(`${API_BASE}${path}`, {
      method,
      headers,
      body: body != null ? JSON.stringify(body) : undefined,
    });
    if (res.status === 401 && auth && getRefreshToken()) {
      const ok = await tryRefresh();
      if (ok) {
        headers.Authorization = `Bearer ${getAccessToken()}`;
        res = await fetch(`${API_BASE}${path}`, {
          method,
          headers,
          body: body != null ? JSON.stringify(body) : undefined,
        });
      }
    }
    return parseEnvelope(res);
  }

  function escapeHtml(s) {
    return String(s ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function formatRelative(dateStr) {
    if (!dateStr) return 'Never';
    const t = new Date(dateStr).getTime();
    if (Number.isNaN(t)) return '—';
    const diff = Date.now() - t;
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'Just now';
    if (mins < 60) return `${mins}m ago`;
    const hours = Math.floor(mins / 60);
    if (hours < 48) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    if (days < 30) return `${days}d ago`;
    return new Date(dateStr).toLocaleDateString();
  }

  function normalizePhone(raw) {
    // Always emit clean E.164: +919876543210 (no spaces)
    let digits = String(raw || '').replace(/\D/g, '');
    if (!digits) return '';
    // 09876543210 → 9876543210
    if (digits.length === 11 && digits.startsWith('0')) digits = digits.slice(1);
    // Indian 10-digit mobile → +91…
    if (digits.length === 10) digits = `91${digits}`;
    return `+${digits}`;
  }

  function formatApiError(err) {
    if (err?.errors?.length) {
      return err.errors.map((e) => e.message || e.msg || String(e)).join(' · ');
    }
    return err.message || 'Request failed';
  }

  function stat(label, value, hint) {
    return `<div class="stat">
      <div class="stat-value">${escapeHtml(value ?? '—')}</div>
      <div class="stat-label">${escapeHtml(label)}</div>
      ${hint ? `<div class="stat-hint">${escapeHtml(hint)}</div>` : ''}
    </div>`;
  }

  function renderLogin() {
    root.innerHTML = `
      <div class="login-shell">
        <form class="login-card" id="login-form">
          <p class="eyebrow">Internal only</p>
          <h1>Vocle Admin</h1>
          <p class="sub">Platform ops portal — not part of the public site. API: ${escapeHtml(API_BASE)}</p>
          ${
            state.loginStep === 'phone'
              ? `
            <label for="phone">Phone (India)</label>
            <input id="phone" inputmode="tel" placeholder="9876543210" value="${escapeHtml(state.phone)}" required autofocus autocomplete="tel" />
            <button type="submit" ${state.loginBusy ? 'disabled' : ''}>${state.loginBusy ? 'Sending…' : 'Send OTP'}</button>
            <p class="hint">Type 10 digits (we add +91). Local OTP_BYPASS uses code <strong>123456</strong>.</p>
          `
              : `
            <label for="otp">OTP for ${escapeHtml(state.phone)}</label>
            <input id="otp" inputmode="numeric" placeholder="6-digit code" value="${escapeHtml(state.otp)}" required autofocus />
            <button type="submit" ${state.loginBusy ? 'disabled' : ''}>${state.loginBusy ? 'Checking…' : 'Enter admin'}</button>
            <button type="button" class="ghost" id="change-phone">Change phone</button>
          `
          }
          ${state.loginError ? `<p class="error">${escapeHtml(state.loginError)}</p>` : ''}
        </form>
      </div>
    `;

    document.getElementById('login-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      // Read inputs BEFORE re-render (re-render destroys the fields)
      const phoneInput = document.getElementById('phone');
      const otpInput = document.getElementById('otp');
      const rawPhone = phoneInput ? phoneInput.value : state.phone;
      const rawOtp = otpInput ? otpInput.value : state.otp;

      state.loginBusy = true;
      state.loginError = '';
      if (state.loginStep === 'phone') state.phone = rawPhone;
      else state.otp = rawOtp;
      renderLogin();

      try {
        if (state.loginStep === 'phone') {
          const phone = normalizePhone(rawPhone);
          if (!/^\+[1-9]\d{9,14}$/.test(phone)) {
            throw Object.assign(
              new Error('Enter a valid mobile with country code, e.g. 9876543210 or +919876543210'),
              { status: 400 }
            );
          }
          await api('/api/auth/request-otp', {
            method: 'POST',
            body: { phone },
            auth: false,
          });
          state.phone = phone;
          state.loginStep = 'otp';
        } else {
          const otp = String(rawOtp || '').trim();
          const data = await api('/api/auth/verify-otp', {
            method: 'POST',
            body: { phone: state.phone, otp },
            auth: false,
          });
          setTokens({
            accessToken: data.accessToken,
            refreshToken: data.refreshToken,
          });
          const me = await api('/api/admin/me');
          state.admin = me;
          state.loginBusy = false;
          await loadDashboard();
          return;
        }
      } catch (err) {
        state.loginError =
          err.status === 403
            ? 'Logged in, but this account is not a platform admin. Add your userId to ADMIN_USER_IDS on Railway.'
            : formatApiError(err) || 'Login failed';
        if (err.status === 403) clearTokens();
      }
      state.loginBusy = false;
      renderLogin();
    });

    const change = document.getElementById('change-phone');
    if (change) {
      change.addEventListener('click', () => {
        state.loginStep = 'phone';
        state.otp = '';
        state.loginError = '';
        renderLogin();
      });
    }
  }

  async function loadDashboard() {
    state.error = '';
    try {
      const verifiedParam =
        state.filter === 'pending'
          ? 'pending'
          : state.filter === 'verified'
            ? 'true'
            : '';
      const activeParam = state.filter === 'inactive' ? 'false' : '';
      const qs = new URLSearchParams();
      if (verifiedParam) qs.set('verified', verifiedParam);
      if (activeParam) qs.set('active', activeParam);
      if (state.q.trim()) qs.set('q', state.q.trim());
      qs.set('limit', '100');
      const [overview, list, growth, retention, infrastructure] =
        await Promise.all([
          api('/api/admin/overview'),
          api(`/api/admin/users?${qs}`),
          api('/api/admin/growth?days=30'),
          api('/api/admin/retention'),
          api('/api/admin/infrastructure'),
        ]);
      state.overview = overview;
      state.growth = growth;
      state.retention = retention;
      state.infrastructure = infrastructure;
      state.users = list.users || [];
      state.pagination = list.pagination || null;
    } catch (err) {
      state.error = err.message || 'Failed to load admin data';
      if (err.status === 401 || err.status === 403) {
        clearTokens();
        state.admin = null;
        render();
        return;
      }
    }
    renderDashboard();
  }

  function growthBars(series) {
    if (!series?.length) return '<p class="muted">No growth data yet.</p>';
    const max = Math.max(1, ...series.map((d) => d.newUsers));
    return `<div class="bars">${series
      .map((d) => {
        const h = Math.round((d.newUsers / max) * 64);
        return `<div class="bar-col" title="${escapeHtml(d.date)}: ${d.newUsers}">
          <div class="bar" style="height:${h}px"></div>
        </div>`;
      })
      .join('')}</div>
      <p class="muted foot">Last ${series.length} days · ${state.growth?.totalNew ?? 0} new users</p>`;
  }

  function renderDashboard() {
    const u = state.overview?.users;
    const h = state.overview?.handoffs;
    const infraOverview = state.overview?.infrastructure;
    const infra = state.infrastructure;
    const ret = state.retention;
    const filters = [
      ['pending', 'Pending'],
      ['verified', 'Verified'],
      ['all', 'All'],
      ['inactive', 'Inactive'],
    ];
    const connectBanner = isLocalApi
      ? `<p class="banner info">Connected to <strong>${escapeHtml(API_BASE)}</strong> — local API. Without Atlas <code>MONGODB_URI</code> this is an empty in-memory DB, not beta doctors. To see real Vocle users, point <code>config.js</code> at Railway after deploying admin routes. See <code>CONNECT.md</code>.</p>`
      : `<p class="banner info">Connected to production API <strong>${escapeHtml(API_BASE)}</strong> — reading live Vocle Mongo data.</p>`;

    const alertsHtml = (infra?.alerts || [])
      .map(
        (a) =>
          `<p class="banner ${a.level === 'warn' ? 'warn' : 'info'}">${escapeHtml(a.message)}</p>`
      )
      .join('');

    root.innerHTML = `
      <div class="app-shell">
        <header class="topbar">
          <div>
            <p class="eyebrow">Vocle · Platform admin</p>
            <h1>Ops dashboard</h1>
          </div>
          <div class="topbar-right">
            <span class="who">${escapeHtml(state.admin?.name || 'Admin')} · ${escapeHtml(state.admin?.phone || '')}</span>
            <button type="button" class="ghost" id="logout">Log out</button>
          </div>
        </header>
        ${connectBanner}
        ${alertsHtml}
        ${state.error ? `<p class="banner error">${escapeHtml(state.error)}</p>` : ''}
        <section class="stats">
          ${stat('Total users', u?.total)}
          ${stat('Active this week', u?.activeThisWeek)}
          ${stat('New this week', u?.newThisWeek)}
          ${stat('Pending verify', u?.pendingVerification)}
          ${stat('Spaces', state.overview?.spaces?.total)}
          ${stat('Messages', state.overview?.messages?.total)}
          ${stat('Handoffs ack', h ? `${h.acknowledged}/${h.total}` : '—', h ? `${h.ackRatePercent}%` : undefined)}
          ${stat('Media tracked', infraOverview ? `${infraOverview.storageUsedMb} MB` : '—', 'Sum of uploads since tracking started')}
        </section>
        <section class="phase2-grid">
          <div class="panel">
            <div class="panel-head"><h2>Growth (30d)</h2></div>
            ${growthBars(state.growth?.series)}
          </div>
          <div class="panel">
            <div class="panel-head"><h2>Retention</h2></div>
            <div class="stats compact">
              ${stat('D1', ret?.d1?.ratePercent != null ? `${ret.d1.ratePercent}%` : '—', `n=${ret?.d1?.cohortSize ?? 0}`)}
              ${stat('D7', ret?.d7?.ratePercent != null ? `${ret.d7.ratePercent}%` : '—', `n=${ret?.d7?.cohortSize ?? 0}`)}
              ${stat('D30', ret?.d30?.ratePercent != null ? `${ret.d30.ratePercent}%` : '—', `n=${ret?.d30?.cohortSize ?? 0}`)}
              ${stat('Churn risk', ret?.churnRisk14d, 'No activity 14d')}
            </div>
          </div>
          <div class="panel">
            <div class="panel-head"><h2>Infrastructure</h2></div>
            <div class="stats compact">
              ${stat('Storage', infra ? `${infra.storage.usedMb} MB` : '—')}
              ${stat('₹ / active user', infra?.costEstimate?.costPerActiveUserInr != null ? `₹${infra.costEstimate.costPerActiveUserInr}` : '—', 'Railway Hobby estimate')}
              ${stat('DB', infra?.dbName || infra?.database || '—')}
              ${stat('Cloudinary', infra?.cloudinaryConfigured ? 'Configured' : 'Off')}
            </div>
            <p class="muted foot">Estimates from Vocle counters. Exact bills: Atlas / Cloudinary / Railway consoles.</p>
          </div>
        </section>
        <section class="panel">
          <div class="panel-head">
            <h2>Users</h2>
            <div class="filters">
              ${filters
                .map(
                  ([key, label]) =>
                    `<button type="button" class="chip ${state.filter === key ? 'active' : ''}" data-filter="${key}">${label}</button>`
                )
                .join('')}
              <input class="search" id="search" placeholder="Search name / phone / institution" value="${escapeHtml(state.q)}" />
              <button type="button" class="ghost" id="refresh">Refresh</button>
            </div>
          </div>
          <div class="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Name</th><th>Role</th><th>Phone</th><th>Joined</th><th>Last seen</th>
                  <th>Msgs</th><th>Handoffs</th><th>Storage</th><th>Status</th><th>Actions</th>
                </tr>
              </thead>
              <tbody>
                ${
                  state.users.length === 0
                    ? `<tr><td colspan="10" class="empty">No users match this filter.</td></tr>`
                    : state.users
                        .map((row) => {
                          const status = !row.isActive
                            ? '<span class="badge bad">Deactivated</span>'
                            : row.isVerifiedDoctor
                              ? '<span class="badge ok">Doctor ✓</span>'
                              : '<span class="badge warn">Pending</span>';
                          const actions = [];
                          if (row.isActive && !row.isVerifiedDoctor) {
                            actions.push(
                              `<button type="button" data-verify="${row.id}" data-val="true" ${state.busyId === row.id ? 'disabled' : ''}>Verify</button>`
                            );
                          }
                          if (row.isActive && row.isVerifiedDoctor) {
                            actions.push(
                              `<button type="button" class="ghost" data-verify="${row.id}" data-val="false" ${state.busyId === row.id ? 'disabled' : ''}>Unverify</button>`
                            );
                          }
                          if (row.isActive) {
                            actions.push(
                              `<button type="button" class="danger" data-active="${row.id}" data-val="false" ${state.busyId === row.id ? 'disabled' : ''}>Deactivate</button>`
                            );
                          } else {
                            actions.push(
                              `<button type="button" data-active="${row.id}" data-val="true" ${state.busyId === row.id ? 'disabled' : ''}>Reactivate</button>`
                            );
                          }
                          return `<tr class="${row.isActive ? '' : 'dim'}">
                            <td><strong>${escapeHtml(row.name || '—')}</strong>${
                              row.institution
                                ? `<div class="muted">${escapeHtml(row.institution)}</div>`
                                : ''
                            }</td>
                            <td>${escapeHtml(row.role || '—')}</td>
                            <td class="mono">${escapeHtml(row.phone)}</td>
                            <td>${row.createdAt ? escapeHtml(new Date(row.createdAt).toLocaleDateString()) : '—'}<div class="muted">${escapeHtml(row.joinedVia || 'direct')}</div></td>
                            <td>${escapeHtml(formatRelative(row.lastSeenAt))}</td>
                            <td>${row.messageCount}</td>
                            <td>${row.handoffCount}</td>
                            <td>${row.storageUsedMb ?? 0} MB</td>
                            <td>${status}</td>
                            <td class="actions">${actions.join('')}</td>
                          </tr>`;
                        })
                        .join('')
                }
              </tbody>
            </table>
          </div>
          ${
            state.pagination
              ? `<p class="muted foot">Showing ${state.users.length} of ${state.pagination.total} users</p>`
              : ''
          }
        </section>
      </div>
    `;

    document.getElementById('logout').onclick = () => {
      clearTokens();
      state.admin = null;
      render();
    };
    document.getElementById('refresh').onclick = () => loadDashboard();
    document.querySelectorAll('[data-filter]').forEach((btn) => {
      btn.onclick = () => {
        state.filter = btn.getAttribute('data-filter');
        loadDashboard();
      };
    });
    let searchTimer;
    document.getElementById('search').addEventListener('input', (e) => {
      state.q = e.target.value;
      clearTimeout(searchTimer);
      searchTimer = setTimeout(() => loadDashboard(), 350);
    });
    document.querySelectorAll('[data-verify]').forEach((btn) => {
      btn.onclick = async () => {
        const id = btn.getAttribute('data-verify');
        const verified = btn.getAttribute('data-val') === 'true';
        state.busyId = id;
        renderDashboard();
        try {
          await api(`/api/admin/users/${id}/verify`, {
            method: 'PUT',
            body: { verified },
          });
          await loadDashboard();
        } catch (err) {
          state.error = err.message;
          state.busyId = '';
          renderDashboard();
        }
      };
    });
    document.querySelectorAll('[data-active]').forEach((btn) => {
      btn.onclick = async () => {
        const id = btn.getAttribute('data-active');
        const active = btn.getAttribute('data-val') === 'true';
        if (
          !active &&
          !window.confirm('Deactivate this user? They cannot log in until restored.')
        ) {
          return;
        }
        state.busyId = id;
        renderDashboard();
        try {
          await api(`/api/admin/users/${id}/deactivate`, {
            method: 'PUT',
            body: { active },
          });
          await loadDashboard();
        } catch (err) {
          state.error = err.message;
          state.busyId = '';
          renderDashboard();
        }
      };
    });
  }

  function render() {
    if (!state.ready) {
      root.innerHTML = `<div class="login-shell"><p class="muted">Loading…</p></div>`;
      return;
    }
    if (!state.admin) {
      renderLogin();
      return;
    }
    renderDashboard();
  }

  async function bootstrap() {
    if (!getAccessToken()) {
      state.admin = null;
      state.ready = true;
      render();
      return;
    }
    try {
      state.admin = await api('/api/admin/me');
      state.ready = true;
      await loadDashboard();
    } catch {
      clearTokens();
      state.admin = null;
      state.ready = true;
      render();
    }
  }

  bootstrap();
})();
