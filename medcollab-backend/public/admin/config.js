// API base URL for the admin portal.
// - Local static server (:5173) → talk to local API
// - Served from Railway at /admin → same origin as the API (no CORS hassle)
(function () {
  const host = window.location.hostname;
  const port = window.location.port;
  const isLocalPortal =
    (host === 'localhost' || host === '127.0.0.1') && port === '5173';

  window.VOCLE_ADMIN_API =
    window.VOCLE_ADMIN_API ||
    (isLocalPortal ? 'http://localhost:5000' : window.location.origin);
})();
