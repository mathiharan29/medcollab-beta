# One-time setup: import Avast (or other HTTPS-scanning) root CA into a
# Gradle-local truststore. Required when Java PKIX fails but browsers work.
#
# Run from android/:  powershell -ExecutionPolicy Bypass -File setup_gradle_truststore.ps1

$ErrorActionPreference = 'Stop'
$androidDir = $PSScriptRoot
$jbr = 'C:\Program Files\Android\Android Studio\jbr'
$keytool = Join-Path $jbr 'bin\keytool.exe'
$sourceCacerts = Join-Path $jbr 'lib\security\cacerts'
$truststore = Join-Path $androidDir 'gradle-truststore.jks'
$exportPath = Join-Path $androidDir 'avast-root.cer'

if (-not (Test-Path $keytool)) {
    Write-Error "Android Studio JBR not found at $jbr. Install Android Studio or set JAVA_HOME."
}

$avast = Get-ChildItem Cert:\LocalMachine\Root, Cert:\CurrentUser\Root -ErrorAction SilentlyContinue |
    Where-Object { $_.Subject -match 'Avast Web/Mail Shield Root' } |
    Select-Object -First 1

if (-not $avast) {
    Write-Warning 'No Avast SSL scanning root found. If PKIX errors persist, disable HTTPS scanning in your antivirus or import its root CA manually.'
    exit 1
}

Export-Certificate -Cert $avast -FilePath $exportPath | Out-Null
Copy-Item $sourceCacerts $truststore -Force
& $keytool -importcert -alias avast-web-mail-shield-root -file $exportPath -keystore $truststore -storepass changeit -noprompt

Write-Host "Created $truststore with Avast root CA. Re-run: flutter run"
