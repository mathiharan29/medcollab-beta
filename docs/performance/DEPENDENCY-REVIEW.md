# Phase 01 dependency review

Reviewed on 2026-10-28 using read-only official registry metadata. No dependency code or lifecycle scripts were loaded/executed, and no `node_modules` directory was created.

| Package | Exact pin | Registry engine declaration | Purpose |
|---|---|---|---|
| Artillery | 2.0.34 | Node >=22.18.0 | Future arrival scheduling; no workload/CLI integration executed in this phase. |
| socket.io-client | 4.8.3 | Node >=10.0.0 | Planned protocol observer compatibility with the investigated Socket.IO server; cohorts belong to Phase 03. |

Primary metadata: [Artillery 2.0.34](https://registry.npmjs.org/artillery/2.0.34), [Socket.IO client 4.8.3](https://registry.npmjs.org/socket.io-client/4.8.3). [Artillery installation guidance](https://www.artillery.io/docs/get-started/get-artillery) and [Socket.IO engine documentation](https://www.artillery.io/docs/reference/engines/socketio) were reviewed. The native observer remains necessary for authenticated readiness, same-name join success events, persistent receivers, correlation and recovery offsets. Compatibility is a future authorized characterization, not a result claimed here.

The harness declares Node >=22.20.0 <25, preserving compatibility with the repository's planned 22.20.0 runtime and the selected Artillery minimum. Actual static syntax checks used the existing local Node v24.14.1. No assertion is made that installed Artillery or its full transitive graph has been runtime-validated on either version.

The npm v3 lock contains 468 resolved dependency entries, each with an exact version, official registry URL and SHA-512 integrity. It was generated using the existing npm 11.11.0 CLI:

```text
npm install --package-lock-only --ignore-scripts --no-audit --no-fund --registry=https://registry.npmjs.org/ --cache .npm-cache --logs-dir .npm-logs
```

This was registry metadata resolution only. [npm documents package-lock-only](https://docs.npmjs.com/cli/v11/commands/npm-install/) as operating on the lockfile while ignoring `node_modules`; scripts were separately disabled. No dependency installation, package lifecycle, browser download, security audit, upgrade or workload was run. Metadata cache/log files are ignored local tooling artifacts, not source or results.

The lock records install hooks for browser-chromium, two platform-specific fsevents entries, protobufjs and unix-dgram. None ran. `.npmrc` defaults to ignore-scripts and disables audit/funding calls, but it is not permission to install dependencies. A future separately authorized installation must preserve the exact lock, review any necessary native/browser build steps and keep installation network access separate from isolated workload execution. Runtime readiness, package security assessment and Artillery engine behavior remain unverified; this review does not claim a security-suite pass.
