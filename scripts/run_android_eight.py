"""Boot an owned emulator and run the eight LOCAL_ONLY Android device cases."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from test_vocle import session_environment  # noqa: E402
from vocle_bootstrap import Bootstrap  # noqa: E402


CASES = (
    "FR-MED-08,FR-PUSH-05,FR-PUSH-06,FR-NAV-04,"
    "FR-NAV-05,FR-LINK-04,FR-JRN-05,FR-JRN-06"
)


def main() -> int:
    commit = (sys.argv[1] if len(sys.argv) > 1 else None) or subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
    ).strip()
    flutter_hint = sys.argv[2] if len(sys.argv) > 2 else (
        r"C:\Flutter\flutter-3.29.3\flutter\bin\flutter.bat"
    )
    cases = sys.argv[3] if len(sys.argv) > 3 else CASES

    if not os.environ.get("ANDROID_HOME"):
        sdk = Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk"
        if sdk.is_dir():
            os.environ["ANDROID_HOME"] = str(sdk)
    if not os.environ.get("JAVA_HOME"):
        jbr = Path(r"C:\Program Files\Android\Android Studio\jbr")
        if (jbr / "bin" / "java.exe").is_file():
            os.environ["JAVA_HOME"] = str(jbr)

    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ")
    output = ROOT / "test-results" / "android-eight" / f"{stamp}-{commit[:8]}"
    output.mkdir(parents=True, exist_ok=False)
    scratch = Path(tempfile.mkdtemp(prefix="vocle-android-eight-"))
    print(f"Commit: {commit}", flush=True)
    print(f"Output: {output}", flush=True)
    print(f"Cases: {cases}", flush=True)

    env = session_environment(scratch)
    state: dict = {"reproduction": {"scratch": str(scratch)}}
    bootstrap = Bootstrap(scratch, output, env, state)
    print("Selecting Flutter...", flush=True)
    flutter = bootstrap.flutter(flutter_hint if Path(flutter_hint).is_file() else None)
    # On 8GB hosts, Gradle prewarm + qemu together thrash. Prepare host tools,
    # run the device lane with deferred emulator attach, then boot qemu only
    # after ready-for-emulator is written.
    print("Preparing Android host toolchain (no emulator yet)...", flush=True)
    from vocle_android import AndroidRuntime
    bootstrap.details["android"] = {}
    runtime = AndroidRuntime(scratch, output, env, bootstrap.command, bootstrap.details["android"])
    bootstrap.android_runtime = runtime
    runtime.prepare_host()

    device_out = output / "android"
    node = ROOT / "tests" / "functional-regression" / "scripts" / "run-device.mjs"
    cmd = [
        "node",
        str(node),
        f"--source-sha={commit}",
        f"--flutter-bin={flutter}",
        f"--adb-bin={runtime.adb}",
        f"--emulator={runtime.serial}",
        f"--cases={cases}",
        f"--output={device_out}",
    ]

    child_env = dict(runtime.env)
    child_env.update(
        {
            "VOCLE_ANDROID_SERIAL": runtime.serial,
            "VOCLE_ANDROID_AVD": getattr(runtime, "avd_name", "") or "",
            "VOCLE_DEFER_EMULATOR": "1",
        }
    )
    print("Running device lane (emulator deferred until APK prewarm):", " ".join(cmd), flush=True)
    child = subprocess.Popen(cmd, cwd=ROOT, env=child_env)
    code = 1
    try:
        ready = device_out / "ready-for-emulator"
        deadline = time.monotonic() + 40 * 60
        while time.monotonic() < deadline:
            if child.poll() is not None:
                code = child.returncode
                break
            if ready.is_file():
                print("APK prewarm signaled ready; releasing Gradle/Java before qemu...", flush=True)
                # Prewarm children can linger and steal RAM from the AVD.
                if os.name == "nt":
                    for image in ("java.exe", "dart.exe"):
                        subprocess.run(
                            ["taskkill.exe", "/IM", image, "/F"],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                            check=False,
                        )
                    time.sleep(3)
                try:
                    runtime.start_emulator()
                except Exception as boot_error:  # noqa: BLE001
                    print(f"emulator boot failed: {boot_error}", flush=True)
                    child.terminate()
                    try:
                        code = child.wait(timeout=60)
                    except subprocess.TimeoutExpired:
                        child.kill()
                        code = child.wait(timeout=30)
                    raise
                code = child.wait()
                break
            time.sleep(2)
        else:
            print("Timed out waiting for APK prewarm before emulator boot", flush=True)
            child.terminate()
            try:
                code = child.wait(timeout=60)
            except subprocess.TimeoutExpired:
                child.kill()
                code = child.wait(timeout=30)
    finally:
        if child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=30)
            except subprocess.TimeoutExpired:
                child.kill()
        print("Stopping owned emulator...", flush=True)
        try:
            runtime.close()
        except Exception as error:  # noqa: BLE001
            print(f"emulator cleanup: {error}", flush=True)

    results = device_out / "results.json"
    summary = {
        "commit": commit,
        "exitCode": code,
        "output": str(output),
        "deviceOut": str(device_out),
    }
    if results.is_file():
        report = json.loads(results.read_text(encoding="utf-8"))
        summary["counts"] = report.get("counts")
        summary["fullSuccess"] = report.get("fullSuccess")
        print("counts", report.get("counts"), flush=True)
        print("fullSuccess", report.get("fullSuccess"), flush=True)
        for row in report.get("cases") or []:
            if row.get("status") != "PASS":
                print(row.get("id"), row.get("status"), (row.get("error") or "")[:160], flush=True)
        report_md = device_out / "report.md"
        if report_md.is_file():
            print(report_md.read_text(encoding="utf-8"), flush=True)
    else:
        print("No results.json produced", flush=True)
    (output / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return code or 0


if __name__ == "__main__":
    raise SystemExit(main())
