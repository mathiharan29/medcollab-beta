# Host side of on-device journeys (integration_test/vocle_beta_1114_test.dart).
# Watches `flutter` logcat lines from the test and:
#   SHOT_<name>          -> screenshot to $OutDir\<name>.png
#   DO_NET_SLOW / _FAST  -> emulator network latency on / off (speed checks)
#   DO_SHADE_REPLY:<txt> -> real notification shade: expand, tap Reply,
#                           type <txt>, send (Android inline reply)
#   DO_ALLOW_MIC         -> screenshot + tap Allow on the system mic dialog
# Ends on $Done or a test failure. Emulator only.
param(
  [string]$OutDir = "$PSScriptRoot\..\device-shots",
  [string]$Done = 'BETA1114_DONE',
  [string]$Package = 'com.example.medcollab_app',
  [string]$Delay = '200:400',
  # `flutter test` forwards the test's print() to the host, not logcat:
  # pass the file its output is redirected to.
  [string]$LogFile = '',
  # Leave the microphone ungranted so the app's own permission prompt is
  # exercised (DO_ALLOW_MIC taps Allow on the real system dialog).
  [switch]$NoMicGrant
)
$adb = (Get-Command adb -ErrorAction Stop).Source
New-Item -ItemType Directory -Force $OutDir | Out-Null
& $adb logcat -c
$handled = @{}
$granted = $false

function DismissAnr() {
  # Starved emulators show "<app> isn't responding" over the app; tap Wait.
  $xml = Dump
  if ($xml -match "isn't responding") {
    $wait = NodeCenter $xml 'text' 'Wait'
    if ($wait) { & $adb shell input tap $wait[0] $wait[1]; Start-Sleep 1; "dismissed ANR dialog" }
  }
}

function Shot([string]$name) {
  DismissAnr
  & $adb shell screencap -p /sdcard/vocle_shot.png
  & $adb pull /sdcard/vocle_shot.png (Join-Path $OutDir "$name.png") | Out-Null
  "shot $name"
}

function NodeCenter([string]$xml, [string]$attr, [string]$value) {
  $m = [regex]::Match($xml, "<node[^>]*$attr=""$([regex]::Escape($value))""[^>]*bounds=""\[(\d+),(\d+)\]\[(\d+),(\d+)\]""")
  if (-not $m.Success) { return $null }
  $x = ([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2
  $y = ([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2
  return @([int]$x, [int]$y)
}

function Dump() {
  & $adb shell uiautomator dump /sdcard/vocle_ui.xml | Out-Null
  return (& $adb shell cat /sdcard/vocle_ui.xml) -join ''
}

function ShadeReply([string]$text) {
  & $adb shell cmd statusbar expand-notifications
  Start-Sleep 2
  $xml = Dump
  $btn = NodeCenter $xml 'text' 'Reply'
  if (-not $btn) { $btn = NodeCenter $xml 'text' 'REPLY' }
  if (-not $btn) { "shade: no Reply button"; Shot 'shade_missing_reply'; return }
  Shot '30_shade_notification'
  & $adb shell input tap $btn[0] $btn[1]
  Start-Sleep 2
  & $adb shell input text ($text -replace ' ', '%s')
  Start-Sleep 1
  Shot '31_shade_typing_reply'
  $xml = Dump
  $send = NodeCenter $xml 'content-desc' 'Send'
  if ($send) { & $adb shell input tap $send[0] $send[1] } else { & $adb shell input keyevent 66 }
  Start-Sleep 6
  Shot '32_shade_after_reply'
  & $adb shell cmd statusbar collapse
}

function AllowMic() {
  for ($k = 0; $k -lt 20; $k++) {
    $xml = Dump
    $btn = $null
    foreach ($label in 'While using the app', 'WHILE USING THE APP', 'Allow', 'ALLOW', 'Only this time') {
      $btn = NodeCenter $xml 'text' $label
      if ($btn) { break }
    }
    if ($btn) {
      Shot '70_system_mic_prompt'
      & $adb shell input tap $btn[0] $btn[1]
      "mic allowed"
      return
    }
    Start-Sleep -Milliseconds 700
  }
  "mic dialog not found"; Shot 'mic_dialog_missing'
}

for ($i = 0; $i -lt 20000; $i++) {
  if (-not $granted) {
    & $adb shell pm grant $Package android.permission.POST_NOTIFICATIONS 2>$null
    if (-not $NoMicGrant) { & $adb shell pm grant $Package android.permission.RECORD_AUDIO 2>$null }
    if ($LASTEXITCODE -eq 0) { $granted = $true; "granted permissions" }
  }
  $log = if ($LogFile) {
    Get-Content $LogFile -ErrorAction SilentlyContinue
  } else {
    & $adb logcat -d -s flutter 2>$null
  }
  foreach ($raw in $log) {
    # adb output on Windows keeps a trailing CR on each line.
    $line = "$raw".TrimEnd("`r", "`n", ' ')
    if ($line -match '(SHOT_\w+|DO_NET_SLOW|DO_NET_FAST|DO_ALLOW_MIC|DO_SHADE_REPLY:.+|TIMING .+|STEP .+)$') {
      $tok = $Matches[1].Trim()
      if ($handled.ContainsKey($tok)) { continue }
      $handled[$tok] = 1
      switch -regex ($tok) {
        '^SHOT_(\w+)' { Shot $Matches[1] }
        '^DO_NET_SLOW' { & $adb emu network delay $Delay | Out-Null; "network delay $Delay ms" }
        '^DO_NET_FAST' { & $adb emu network delay none | Out-Null; "network delay off" }
        '^DO_SHADE_REPLY:(.+)' { ShadeReply $Matches[1] }
        '^DO_ALLOW_MIC' { AllowMic }
        default { $tok }
      }
    }
  }
  if ($log -match $Done) { "journey done"; break }
  if ($log -match 'Some tests failed|Test failed|══╡ EXCEPTION') { "journey FAILED"; Shot 'zz_failure'; break }
  Start-Sleep -Milliseconds 300
}
& $adb emu network delay none | Out-Null
"watcher exit after $i polls"
