# Focused MongoDB/data security lane

Append-only VOCLE-786–816. Run **Vocle MongoDB Data Security** using workflow_dispatch on this fork's master. Production/Atlas/provider credentials are never required or permitted. The workflow installs dependencies/images before running the actual application and MongoDB in a network-none/shared-loopback namespace with a read-only source mount.

Local static checks from medcollab-backend:

```sh
node scripts/security-data/check.js
node scripts/security-data/self-test.js
node scripts/security-manifest-check.js
node scripts/security-media/check.js
node scripts/security-cloudinary/check.js
```

Also run `node --check` on this directory's JS files and inspect workflow YAML. `--freeze` deliberately creates the data manifest; do not use it to conceal changes to frozen IDs/expectations. Previous Cloudinary/media/general manifests remain pinned.

Full execution is `node scripts/security-data/run.js` **inside the workflow's disposable container environment**, not a command to run against a developer or production database. Exact URI/env/provider exclusions and loopback-only network guards fail closed. The runner verifies the local MongoDB TTL background sweep is paused so expired-record visibility assertions are deterministic. Real TTL index definitions/application expiry logic still execute; actual TTL deletion latency is deliberately not tested. Never apply the sweep setting to a deployed database.

`cases.js` separates HTTP, model/index and synthetic handler scopes. `fixtures.js` journals exact IDs and narrowly scopes generated OTP/inbox records to synthetic users, then verifies zero residue. `run.js` supervises the existing local-mode backend entrypoint, discards child logs and records sanitized booleans/counts/statuses. `check.js --artifacts` validates report hygiene/completeness before upload. Actual report exceptions, unsafe I/O, prerequisite failure, incomplete execution and cleanup failures block; unmet application requirements remain observations.

Successful route controls and state assertions must survive any remediation. Review observations separately before enabling strict application gates. This discovery runner preserves its existing observation semantics.

Application schema index conflicts (MongoDB codes 85/86) are recorded separately
as blocking application failures. The runner does not repair or replace indexes;
it verifies the collection remains queryable and continues independent cases
against the real indexes MongoDB created. Other initialization errors still abort.
An original case assertion failure stays FAIL and keeps CI red while remaining
cases run after safety and cleanup verification. Missing application methods are
identified explicitly; unknown exceptions still fail as execution errors.
