param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,

    [string]$SocketUrl = "",

    [switch]$SkipAnalyze
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")

Write-Host "Building MedCollab release APK"
Write-Host "  API_BASE_URL: $ApiBaseUrl"
if ($SocketUrl) {
    Write-Host "  SOCKET_URL:   $SocketUrl"
}

if (-not $SkipAnalyze) {
    Write-Host "`n==> flutter analyze"
    flutter analyze
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$defines = @(
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=ENABLE_API_LOGGING=false"
)
if ($SocketUrl) {
    $defines += "--dart-define=SOCKET_URL=$($SocketUrl.TrimEnd('/'))"
}

Write-Host "`n==> flutter build apk --release"
flutter build apk --release @defines

$apk = "build/app/outputs/flutter-apk/app-release.apk"
Write-Host "`nDone. APK: $apk"
Write-Host "Install: adb install -r $apk"
