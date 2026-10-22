[CmdletBinding()]
param([Parameter(Mandatory)][string]$Result, [switch]$Elevated)
$ErrorActionPreference = 'Stop'
if (!$Elevated) {
  # Elevate this fixed installer only. The test harness itself runs as the user.
  $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Elevated -Result "' + $Result + '"'
  try {
    $installer = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -Wait -PassThru
    exit $installer.ExitCode
  } catch {
    @{ exitCode = 1; error = $_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath $Result -Encoding UTF8
    exit 1
  }
}
try {
  $messages = & "$env:SystemRoot\System32\wsl.exe" --install --no-distribution --web-download 2>&1 | Out-String
  $installCode = $LASTEXITCODE
  $messages = $messages.Replace([string][char]0, '')
  $restartRequired = $installCode -eq 3010 -or $messages -match '(?is)changes will not be effective until.*(?:reboot|restart)'
  @{ exitCode = $installCode; output = $messages; restartMayBeRequired = $true; restartRequired = $restartRequired } | ConvertTo-Json | Set-Content -LiteralPath $Result -Encoding UTF8
  if ($installCode -eq 0 -or $installCode -eq 3010) { exit 0 }
  exit 1
} catch {
  @{ exitCode = 1; error = $_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath $Result -Encoding UTF8
  exit 1
}
