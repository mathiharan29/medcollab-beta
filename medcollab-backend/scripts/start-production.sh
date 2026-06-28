#!/usr/bin/env bash
# Production startup — run on Railway or any Node host.
set -euo pipefail

cd "$(dirname "$0")/.."

export NODE_ENV="${NODE_ENV:-production}"

echo "==> Validating environment..."
node scripts/validate-env.js

echo "==> Installing production dependencies..."
npm ci --omit=dev

echo "==> Starting MedCollab API..."
exec node src/server.js
