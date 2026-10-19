[CmdletBinding()]
param(
  [string]$Source = (Split-Path $PSScriptRoot -Parent),
  [string]$Commit,
  [string]$Output,
  [string]$Previous,
  [string]$FlutterBin = 'flutter.bat',
  [string]$Apk,
  [switch]$Android,
  [switch]$Security
)
$ErrorActionPreference = 'Stop'
$runnerArgs = @((Join-Path $PSScriptRoot '../tests/developer-workflow/run.mjs'), '--source', $Source, '--flutter-bin', $FlutterBin)
foreach ($pair in @(@('--commit', $Commit), @('--output', $Output), @('--previous', $Previous), @('--apk', $Apk))) {
  if ($pair[1]) { $runnerArgs += $pair }
}
if ($Android) { $runnerArgs += '--android' }
if ($Security) { $runnerArgs += '--security' }
& node @runnerArgs
exit $LASTEXITCODE
