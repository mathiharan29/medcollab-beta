param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,

    [string]$SocketUrl = "",

    [string]$Msg91WidgetId = "366642727548323934353735",

    [Parameter(Mandatory = $true)]
    [string]$Msg91WidgetToken,

    [switch]$SkipAnalyze
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$ApiBaseUrl = $ApiBaseUrl.TrimEnd("/")

Write-Host "Building MedCollab release APK"
Write-Host "  API_BASE_URL:       $ApiBaseUrl"
Write-Host "  MSG91_WIDGET_ID:    $Msg91WidgetId"
if ($SocketUrl) {
    Write-Host "  SOCKET_URL:         $SocketUrl"
}

if (-not $SkipAnalyze) {
    Write-Host "`n==> flutter analyze"
    flutter analyze
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$defines = @(
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=ENABLE_API_LOGGING=false",
    "--dart-define=MSG91_WIDGET_ID=$Msg91WidgetId",
    "--dart-define=MSG91_WIDGET_TOKEN=$Msg91WidgetToken"
)
if ($SocketUrl) {
    $defines += "--dart-define=SOCKET_URL=$($SocketUrl.TrimEnd('/'))"
}

Write-Host "`n==> flutter build apk --release"
flutter build apk --release @defines

$apk = "build/app/outputs/flutter-apk/app-release.apk"
Write-Host "`nDone. APK: $apk"
Write-Host "Install: adb install -r $apk"
