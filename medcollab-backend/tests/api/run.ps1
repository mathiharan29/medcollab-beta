# Runs API suites, each against its own fresh local backend (in-memory
# MongoDB, OTP bypass). Never touches production.
#   powershell -File tests/api/run.ps1                       # all suites
#   powershell -File tests/api/run.ps1 -Suites privacy-views
param([string[]]$Suites = @(), [string]$Node = 'node', [int]$Port = 5001)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
# `-File` passes "a,b" as one string.
$Suites = @($Suites | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
if ($Suites.Count -eq 0) {
  $Suites = Get-ChildItem $here -Filter *.test.mjs | ForEach-Object { $_.Name -replace '\.test\.mjs$', '' }
}
$env:VOCLE_PORT = "$Port"
$env:VOCLE_API = "http://127.0.0.1:$Port"
$failed = 0
foreach ($s in $Suites) {
  $log = Join-Path ([IO.Path]::GetTempPath()) "vocle-api-$s.log"
  $proc = Start-Process -FilePath $Node -ArgumentList (Join-Path $here 'dev-backend.js') -PassThru -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError "$log.err"
  $t = 0
  while ($t -lt 90) { try { Invoke-WebRequest "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 2 | Out-Null; break } catch { Start-Sleep 2; $t += 2 } }
  "== $s"
  & $Node (Join-Path $here "$s.test.mjs")
  if ($LASTEXITCODE -ne 0) { $failed++ }
  Stop-Process -Id $proc.Id -Force
  Start-Sleep 1
  Remove-Item $log, "$log.err" -ErrorAction SilentlyContinue
}
if ($failed) { "FAILED suites: $failed"; exit 1 } else { "ALL SUITES PASSED" }
