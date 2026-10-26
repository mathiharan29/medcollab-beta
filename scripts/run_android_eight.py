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
    print("Booting owned emulator...", flush=True)
    bootstrap.android()
    runtime = bootstrap.android_runtime
    assert runtime and runtime.serial and runtime.adb

    device_out = output / "android"
    node = ROOT / "tests" / "functional-regression" / "scripts" / "run-device.mjs"
    cmd = [
        sys.executable.replace("python.exe", "node.exe")
        if False
        else "node",
        str(node),
        f"--source-sha={commit}",
        f"--flutter-bin={flutter}",
        f"--adb-bin={runtime.adb}",
        f"--emulator={runtime.serial}",
        f"--cases={cases}",
        f"--output={device_out}",
    ]
    # Prefer PATH node.
    cmd[0] = "node"

    child_env = dict(runtime.env)
    child_env.update(
        {
            "VOCLE_ANDROID_SERIAL": runtime.serial,
            "VOCLE_ANDROID_AVD": getattr(runtime, "avd_name", "") or "",
        }
    )
    print("Running device lane:", " ".join(cmd), flush=True)
    try:
        completed = subprocess.run(cmd, cwd=ROOT, env=child_env, check=False)
        code = completed.returncode
    finally:
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
    return code


if __name__ == "__main__":
    raise SystemExit(main())
