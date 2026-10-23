#Requires -Version 5.1
<#
.SYNOPSIS
  Run Sriram's Vocle local harness and write a push-gate marker for agents.

.DESCRIPTION
  Wrapper around scripts/test_vocle.py. After the run, writes
  test-results/.vocle-push-gate.json (gitignored via /test-results/).

  Profiles:
    full-187     Committed HEAD + Android + CI checks (default pre-push gate)
    wip-179      Working tree + CI checks, no Android (iterate while fixing)
    all-security Committed HEAD + Android + security + CI (--all)
    tooling      Tooling / prerequisite checks only
    backend-smoke Backend smoke only

.EXAMPLE
  .\scripts\run-vocle-local-gate.ps1
  .\scripts\run-vocle-local-gate.ps1 -Profile wip-179
  .\scripts\run-vocle-local-gate.ps1 -Profile full-187 -PythonExe py -PythonArgs '-V:3.13'
#>
[CmdletBinding()]
param(
    [ValidateSet('full-187', 'wip-179', 'all-security', 'tooling', 'backend-smoke')]
    [string]$Profile = 'full-187',

    [string]$PythonExe = 'python',

    [string[]]$PythonArgs = @(),

    [string]$FlutterBin = '',

    [ValidateSet('auto', 'existing', 'managed')]
    [string]$Runtime = 'auto',

    [string]$Output = '',

    [string]$Previous = '',

    [switch]$SkipAdbPrecheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $root = (git rev-parse --show-toplevel 2>$null)
    if (-not $root) {
        throw 'Not inside a Git repository. Run from MedCollab root.'
    }
    return $root.Trim()
}

function Resolve-PythonInvocation {
    param([string]$Exe, [string[]]$Args)
    $probe = & $Exe @Args --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Python not usable via '$Exe $($Args -join ' ')'. Install 3.10+ 64-bit or pass -PythonExe / -PythonArgs."
    }
    Write-Host "Using: $Exe $($Args -join ' ') -> $probe"
}

$repoRoot = Get-RepoRoot
Set-Location $repoRoot

$launcher = Join-Path $repoRoot 'scripts\test_vocle.py'
if (-not (Test-Path -LiteralPath $launcher)) {
    throw "Missing $launcher. Rebase/pull Sriram's testing branch first."
}

if (-not $env:ANDROID_HOME -and (Test-Path -LiteralPath "$env:LOCALAPPDATA\Android\Sdk")) {
    $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
}
if (-not $env:JAVA_HOME) {
    $studioJbr = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path -LiteralPath "$studioJbr\bin\java.exe") {
        $env:JAVA_HOME = $studioJbr
    }
}

Resolve-PythonInvocation -Exe $PythonExe -Args $PythonArgs

$commit = (git rev-parse HEAD).Trim()
$needsCommit = $Profile -in @('full-187', 'all-security', 'tooling', 'backend-smoke')
$dirty = @(git status --porcelain --untracked-files=no)
if ($needsCommit -and $Profile -in @('full-187', 'all-security') -and $dirty.Count -gt 0) {
    Write-Warning "Working tree has uncommitted tracked changes. Profile '$Profile' tests commit $commit only; uncommitted app edits are excluded."
}

if (-not $SkipAdbPrecheck -and $Profile -in @('full-187', 'all-security')) {
    if (-not $env:ANDROID_HOME) {
        throw 'ANDROID_HOME is not set. Install Android Studio SDK or set ANDROID_HOME before full-187.'
    }
    $adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
    if (-not (Test-Path -LiteralPath $adb)) {
        throw "adb not found at $adb"
    }
    $devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne '' }
    if ($devices) {
        throw "adb devices is not empty. Close other emulators/devices before full-187:`n$($devices -join "`n")"
    }
}

$argList = [System.Collections.Generic.List[string]]::new()
foreach ($a in $PythonArgs) { $argList.Add($a) }
$argList.Add($launcher)
$argList.Add('--source')
$argList.Add('.')
$argList.Add('--runtime')
$argList.Add($Runtime)

switch ($Profile) {
    'full-187' {
        $argList.Add('--commit'); $argList.Add($commit)
        $argList.Add('--android'); $argList.Add('--ci-checks')
    }
    'wip-179' {
        $argList.Add('--ci-checks')
    }
    'all-security' {
        $argList.Add('--commit'); $argList.Add($commit)
        $argList.Add('--all')
    }
    'tooling' {
        $argList.Add('--commit'); $argList.Add($commit)
        $argList.Add('--profile'); $argList.Add('tooling')
        $argList.Add('--ci-checks')
    }
    'backend-smoke' {
        $argList.Add('--commit'); $argList.Add($commit)
        $argList.Add('--profile'); $argList.Add('backend-smoke')
    }
}

if ($FlutterBin) {
    $argList.Add('--flutter-bin'); $argList.Add($FlutterBin)
}
if ($Output) {
    $argList.Add('--output'); $argList.Add($Output)
}
if ($Previous) {
    $argList.Add('--previous'); $argList.Add($Previous)
}

$commandDisplay = "$PythonExe $($argList -join ' ')"
Write-Host ""
Write-Host "=== Vocle local gate: $Profile ===" -ForegroundColor Cyan
Write-Host "Commit: $commit"
Write-Host "Command: $commandDisplay"
Write-Host "Started: $(Get-Date -Format o)"
Write-Host ""

$started = Get-Date
& $PythonExe @argList
$exitCode = $LASTEXITCODE
$finished = Get-Date

$resultsRoot = Join-Path $repoRoot 'test-results'
$reportDir = $null
$dashboard = $null
$summary = $null
$latestPointer = Join-Path $resultsRoot 'LATEST_FULL_RUN.txt'
if (Test-Path -LiteralPath $latestPointer) {
    $lines = Get-Content -LiteralPath $latestPointer
    if ($lines.Count -ge 1) { $reportDir = $lines[0] }
    if ($lines.Count -ge 2) { $dashboard = $lines[1] }
    if ($lines.Count -ge 3) { $summary = $lines[2] }
}

$passed = ($exitCode -eq 0)
$gatePath = Join-Path $resultsRoot '.vocle-push-gate.json'
New-Item -ItemType Directory -Path $resultsRoot -Force | Out-Null

$gate = [ordered]@{
    schemaVersion   = 1
    profile         = $Profile
    commit          = $commit
    passed          = $passed
    pushEligible    = ($passed -and $Profile -eq 'full-187')
    exitCode        = $exitCode
    command         = $commandDisplay
    reportDir       = $reportDir
    dashboard       = $dashboard
    summary         = $summary
    startedAt       = $started.ToString('o')
    finishedAt      = $finished.ToString('o')
    durationSeconds = [int]($finished - $started).TotalSeconds
    note            = if ($Profile -eq 'full-187') {
        'Push only after human sign-off when pushEligible is true (exit 0 on full-187 for this commit).'
    } else {
        'This profile is not the pre-push gate. Run -Profile full-187 on a clean committed tree before push.'
    }
}

$gate | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $gatePath -Encoding utf8

Write-Host ""
Write-Host "=== Gate result ===" -ForegroundColor $(if ($passed) { 'Green' } else { 'Yellow' })
Write-Host "Exit code: $exitCode  passed=$passed  pushEligible=$($gate.pushEligible)"
Write-Host "Gate marker: $gatePath"
if ($reportDir) { Write-Host "Report dir: $reportDir" }
if ($dashboard) { Write-Host "Dashboard: $dashboard" }
if ($summary) { Write-Host "Summary: $summary" }
Write-Host ""
Write-Host "Do not push until a human signs off. Agents must wait for explicit push approval."

exit $exitCode
