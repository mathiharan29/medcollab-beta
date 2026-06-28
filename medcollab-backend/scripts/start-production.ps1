# Production startup — Windows / local prod smoke test
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not $env:NODE_ENV) { $env:NODE_ENV = "production" }

Write-Host "==> Validating environment..."
node scripts/validate-env.js
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Installing production dependencies..."
npm ci --omit=dev

Write-Host "==> Starting MedCollab API..."
node src/server.js
