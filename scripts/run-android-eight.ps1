#Requires -Version 5.1
<#
.SYNOPSIS
  Boot an owned emulator and run the 8 LOCAL_ONLY Android device cases only.
#>
[CmdletBinding()]
param(
    [string]$Commit = '',
    [string]$FlutterBin = 'C:\Flutter\flutter-3.29.3\flutter\bin\flutter.bat',
    [string]$Cases = 'FR-MED-08,FR-PUSH-05,FR-PUSH-06,FR-NAV-04,FR-NAV-05,FR-LINK-04,FR-JRN-05,FR-JRN-06'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

if (-not $env:ANDROID_HOME -and (Test-Path "$env:LOCALAPPDATA\Android\Sdk")) {
    $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
}
if (-not $env:JAVA_HOME) {
    $studioJbr = 'C:\Program Files\Android\Android Studio\jbr'
    if (Test-Path "$studioJbr\bin\java.exe") { $env:JAVA_HOME = $studioJbr }
}
if (-not $Commit) { $Commit = (git rev-parse HEAD).Trim() }

$stamp = Get-Date -Format 'yyyy-MM-ddTHH-mm-ssZ'
# Use a UTC-ish folder name without colons for Windows friendliness
$stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH-mm-ssZ') -replace ':', '-'
$output = Join-Path $repoRoot "test-results\android-eight\$stamp-$($Commit.Substring(0,8))"
New-Item -ItemType Directory -Force -Path $output | Out-Null

$adb = Join-Path $env:ANDROID_HOME 'platform-tools\adb.exe'
$devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne '' }
if ($devices) {
    throw "adb devices must be empty before android-eight:`n$($devices -join "`n")"
}

Write-Host "=== Android-eight ==="
Write-Host "Commit: $Commit"
Write-Host "Output: $output"
Write-Host "Cases: $Cases"

$bootPy = @'
import json, os, sys, tempfile, time, venv
from pathlib import Path

repo = Path(sys.argv[1])
output = Path(sys.argv[2])
sys.path.insert(0, str(repo / "scripts"))
from vocle_bootstrap import Bootstrap

scratch = Path(tempfile.mkdtemp(prefix="vocle-android-eight-"))
print("scratch", scratch, flush=True)
env = os.environ.copy()
state = {"reproduction": {"scratch": str(scratch)}}
bootstrap = Bootstrap(scratch, output, env, state)
print("Selecting Flutter...", flush=True)
flutter = bootstrap.flutter(sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else None)
print("Booting owned emulator...", flush=True)
bootstrap.android()
runtime = bootstrap.android_runtime
marker = {
    "flutter_bin": flutter,
    "adb_bin": str(runtime.adb),
    "serial": runtime.serial,
    "avd": getattr(runtime, "avd_name", None),
    "emulator_bin": getattr(runtime, "emulator_bin", None),
    "emulator_port": getattr(runtime, "emulator_port", None),
    "env": {
        "ANDROID_HOME": runtime.env.get("ANDROID_HOME"),
        "JAVA_HOME": runtime.env.get("JAVA_HOME"),
        "ANDROID_USER_HOME": runtime.env.get("ANDROID_USER_HOME"),
        "ANDROID_AVD_HOME": runtime.env.get("ANDROID_AVD_HOME"),
        "GRADLE_USER_HOME": runtime.env.get("GRADLE_USER_HOME"),
        "VOCLE_ANDROID_TRUSTSTORE": runtime.env.get("VOCLE_ANDROID_TRUSTSTORE"),
        "VOCLE_ANDROID_SERIAL": runtime.serial,
        "VOCLE_ANDROID_AVD": getattr(runtime, "avd_name", None),
    },
    "scratch": str(scratch),
}
(output / "android-eight-runtime.json").write_text(json.dumps(marker, indent=2), encoding="utf-8")
print("READY", runtime.serial, flush=True)
# Keep process alive until parent kills us — hold the Popen handle.
while runtime.process and runtime.process.poll() is None:
    time.sleep(5)
'@

$bootPyPath = Join-Path $output 'boot-emulator.py'
Set-Content -LiteralPath $bootPyPath -Value $bootPy -Encoding UTF8

$bootLog = Join-Path $output 'boot-emulator.log'
$bootProc = Start-Process -FilePath python -ArgumentList @(
    $bootPyPath, $repoRoot, $output, $FlutterBin
) -PassThru -NoNewWindow -RedirectStandardOutput $bootLog -RedirectStandardError $bootLog

try {
    $deadline = (Get-Date).AddMinutes(20)
    $serial = $null
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $bootLog) {
            $tail = Get-Content $bootLog -Tail 5 -ErrorAction SilentlyContinue
            foreach ($line in $tail) {
                if ($line -match '^READY (emulator-\d+)') {
                    $serial = $Matches[1]
                    break
                }
            }
        }
        if ($serial) { break }
        if ($bootProc.HasExited) {
            Get-Content $bootLog -ErrorAction SilentlyContinue
            throw "Emulator bootstrap exited early (code $($bootProc.ExitCode))"
        }
        Start-Sleep 5
    }
    if (-not $serial) { throw "Emulator did not become READY in 20 minutes" }

    $runtime = Get-Content (Join-Path $output 'android-eight-runtime.json') -Raw | ConvertFrom-Json
    foreach ($key in @('ANDROID_HOME','JAVA_HOME','ANDROID_USER_HOME','ANDROID_AVD_HOME','GRADLE_USER_HOME','VOCLE_ANDROID_TRUSTSTORE','VOCLE_ANDROID_SERIAL','VOCLE_ANDROID_AVD')) {
        $val = $runtime.env.$key
        if ($val) { Set-Item -Path "Env:$key" -Value $val }
    }

    Write-Host "Emulator ready: $serial — starting device lane"
    $deviceOut = Join-Path $output 'android'
    $nodeArgs = @(
        (Join-Path $repoRoot 'tests\functional-regression\scripts\run-device.mjs'),
        "--source-sha=$Commit",
        "--flutter-bin=$($runtime.flutter_bin)",
        "--adb-bin=$($runtime.adb_bin)",
        "--emulator=$serial",
        "--cases=$Cases",
        "--output=$deviceOut"
    )
    & node @nodeArgs
    $code = $LASTEXITCODE
    Write-Host "android-eight exit=$code"
    if (Test-Path (Join-Path $deviceOut 'report.md')) {
        Get-Content (Join-Path $deviceOut 'report.md')
    }
    if (Test-Path (Join-Path $deviceOut 'results.json')) {
        python -c "import json; d=json.load(open(r'$($deviceOut -replace '\\','/')/results.json',encoding='utf-8')); print('counts', d.get('counts')); print('fullSuccess', d.get('fullSuccess'));
[print(c.get('id'), c.get('status'), (c.get('error') or '')[:120]) for c in d.get('cases',[]) if c.get('status')!='PASS']"
    }
    exit $code
}
finally {
    Write-Host "Stopping emulator bootstrap..."
    if ($bootProc -and -not $bootProc.HasExited) {
        Stop-Process -Id $bootProc.Id -Force -ErrorAction SilentlyContinue
    }
    & $adb emu kill 2>$null
    Get-Process qemu*,emulator -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
