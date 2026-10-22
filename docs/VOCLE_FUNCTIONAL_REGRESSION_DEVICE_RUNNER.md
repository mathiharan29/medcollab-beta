# Android device regression runner

The eight device catalog cases use an Android emulator, the real application
widgets/repositories/Socket.IO client and a real disposable Express/MongoDB
backend. Firebase and picker/camera **inputs** are test-owned. Secure storage,
preferences, local notification display, Android lifecycle and file opening use
native implementations. Injected notifications do not prove FCM/APNs delivery.
No iOS implementation or execution is claimed.

## Prerequisites

- Flutter **3.29.3**, Dart **3.7.2**, matching the committed application lockfile.
- Node 22 or newer, Git, `tar`, npm, and the target backend's locked dependencies.
- Exactly one online Android emulator and no physical device in `adb devices`.
- Android SDK/JDK/Gradle dependencies needed by the committed Android build.
- An emulator with an external PDF viewer/handler for `FR-MED-08`. Its absence is
  an infrastructure limitation, never an invented successful file open.
- Disposable local MongoDB 7, either downloaded by MongoMemoryServer or an
  explicitly supplied `--mongo-bin` test binary. No Mongo connection URI input.

Hosted PR coverage lists these eight cases as `LOCAL_ONLY`, `executed: false`
and underlying `SKIP`; they do not contribute hosted PASS or executed totals.
Run locally with the selected `JAVA_HOME` and optional `VOCLE_ANDROID_TRUSTSTORE`.
The selected JDK/CA settings replace machine-specific Gradle arguments only inside
the disposable build workspace. TLS verification is preserved.

## Run

From the repository root (example paths must be adapted to the local host):

```powershell
node tests/functional-regression/scripts/run-device.mjs `
  --emulator=emulator-5580 `
  --flutter-bin=C:/path/to/flutter-3.29.3/bin/flutter.bat `
  --mongo-bin=C:/path/to/disposable/mongod.exe
```

Run a focused case with `--cases=FR-NAV-05`; a comma-separated exact catalog ID
list selects a subset. Optional `--source-sha=<40-character-local-commit>` pins a
commit already present in the local repository checkout. This runner does not
fetch, push or write any remote repository.

The runner archives that exact committed revision into a fresh `vocle-device-*`
OS temporary directory and retains diagnostics in the repository's ignored output
directory. It copies the device assertions/driver with content hashes, adds
`integration_test` and existing plugin interfaces as **test-only dependency
overlays**, and verifies every original package version/source/hash stayed
unchanged after resolution. It leaves the user's pubspec, lockfile, Android
files, application source and other working edits untouched.

The isolated test APK uses `com.vocle.regression` and debug cleartext permission
for `http://10.0.2.2:<allocated-port>`. Release builds are rejected: the current
application's release configuration hardcodes its production API. No real
Firebase options, Google Services configuration, MSG91 widget or Cloudinary
credentials are supplied. The backend uses the existing provider interception
and loopback-only outbound guard. Each device case gets a separate backend
process/database, synthetic identities and patient aliases.

Current-chat component cases seed their protected destination through the actual
AppRouter's queued deep-link entry before authentication, and the invite case
starts at its scanner route. These are declared navigation prerequisites;
they do not credit Home startup or an additional successful journey. The native
restart and cold handoff cases still exercise ordinary startup. The previously
observed Home skeleton/render failures remain failures in those cases and in
the Flutter tier. Session fixtures are written before dependency initialization
so initial unauthenticated badge requests cannot erase a newly seeded session.

`flutter drive --keep-app-running --no-dds` runs the native integration binding. **Do not replace it with
`flutter test` for restart cases:** that command uninstalls the app on completion
and destroys the session evidence. Plain `flutter drive` also uninstalls by
default; the explicit keep flag is required. The host force-stops only the
dedicated regression app between native phases. Restart proof requires distinct
Android process IDs and matching run/phase checkpoints; no storage write occurs
before the restoration assertion. The test package is removed after execution.

Windows commands use the initialized SDK's cached Dart executable. Gradle runs
without its persistent daemon or filesystem watcher; Kotlin compilation runs in
process. Console hosts are captured while their test-tool parents are alive and
may be stopped only with matching captured PIDs and creation times. Flutter's
run-owned streaming ADB logcat readers are captured and stopped in the same way;
they were proven to hold the temporary app directory after drive exited. The
shared ADB server and unrelated ADB processes are preserved. Historical `EBUSY`
results remain ERROR; fresh runs must verify automatic removal. These are
harness controls, not application changes.

## Case ownership

| ID | Assertions and native phases |
| --- | --- |
| FR-MED-08 | Image/camera/document cancel sends nothing; injected denial and recovery; actual PDF/image/video selections and previews; unsupported input visibly fails without persistence; exact local PDF bytes and external Android activity. A valid MP4 is recorded from the synthetic test UI with Android `screenrecord`. Q5 remains open for unsupported local upload/message pipelines. |
| FR-PUSH-05 | Inject background messages twice for one channel and once for another; inspect real shade entries and native persisted grouping lines; provider tap opens exact conversation; notification reply uses native token and persists once, then independent repository read. |
| FR-PUSH-06 | Native notification deny/grant and injected provider authorization; app usability; local token registration, refresh, native stored token, backend logout removal, real synthetic OTP relogin and new registration. |
| FR-NAV-04 | Current composer draft persists; local gateway interrupts HTTP/Socket.IO; native Home/foreground cycle delivers pause/resume; socket reconnects; independently created peer message is persisted and displayed; draft survives. |
| FR-NAV-05 | Three process phases: encrypted session seed, force-stop/restore with correct auth route, API logout fault clearing native session, second force-stop and unauthenticated relaunch. |
| FR-LINK-04 | Camera deny/grant; canceled picker and preview cannot join; real QR decoder processes injected live/screenshot frames, raw code and full link; actual join membership; approval request persists once without membership. Q14 presentation remains undecided. |
| FR-JRN-05 | Compose/persist draft, native background with injected local transport outage, resume, UI send, correlated peer reply, independent DB/repository reads, refetch and logout/OTP relogin with one displayed committed message. |
| FR-JRN-06 | Logged-out native cold preparation and force-stop, injected initial handoff notification, actual startup/login route, exact handoff/patient/assignee, UI acknowledgement, listener-before-action sender event/notification and sender API read. |

Transport outage injection occurs at a local test-owned HTTP/Socket.IO gateway;
it does not establish cellular/radio offline behavior. Camera/picker/provider
inputs are injected at documented plugin interfaces; camera hardware recognition
and real provider delivery remain outside this evidence.

## Evidence and non-green outcomes

Each run writes `results.json`, `junit.xml`, `report.md`, `coverage.json`,
`provenance.json`, `cleanup.json`, native phase logs, backend logs and correlated
control/event/request records under `tests/functional-regression/output/d-*`.
Fixture tokens and OTP contents are excluded from control traces; diagnostic JWTs
are redacted. Native phase prerequisites do not add testcase IDs or passing cases.

Only a complete eight-case PASS with verified provenance and cleanup is full
device success. Assertions fail as **FAIL**; SDK/build/control prerequisites are
**ERROR** with `executed=false` when no case ran. Missing product expectations
remain **NEEDS_DECISION** after safe assertions, and block full success. A subset
never constitutes full release coverage. Application source hashes are checked
before the isolated target is removed; diagnostic artifacts remain.

Run harness contracts separately:

```text
node --test tests/functional-regression/scripts/device-contracts.test.mjs
node tests/functional-regression/scripts/validate-catalog.mjs
```

Current results must come from the new run's structured report and logs. Presence
of a test file or a successful build does not establish a passing device case.

## Platform limitations

The activity parser supports Android's topResumedActivity and ResumedActivity
fields. The host waits for the test Activity to reach STOPPED before resuming it;
a resumed launcher alone does not prove that the application stopped. Different
Android versions may require additional validation. Application failures remain
FAIL; missing native handlers, viewers or driver evidence remain infrastructure
errors. iOS and real provider delivery are outside this suite.
