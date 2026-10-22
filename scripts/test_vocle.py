#!/usr/bin/env python3
"""Run Vocle's existing regression harness in a disposable local session.

Python 3.10+ and Git are required. Node, Flutter packages/SDK and a minimal
Docker runtime are prepared automatically. Windows may need one OS restart.
"""

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import shlex
import signal
import stat
import subprocess
import sys
import tempfile
import uuid
import venv

from vocle_bootstrap import Bootstrap, SetupRequired


ROOT = Path(__file__).resolve().parents[1]
VALUE_OPTIONS = ("commit", "previous", "flutter_bin", "docker_bin", "docker_proxy", "gitleaks_bin", "cloudinary_output", "reproduction", "apk", "profile", "repository", "branch_ref", "pr_number")
ENV_KEYS = {
    "PATH", "PATHEXT", "SYSTEMROOT", "SYSTEMDRIVE", "WINDIR", "COMSPEC", "PROGRAMFILES",
    "PROGRAMFILES(X86)", "PROGRAMW6432", "LANG", "LC_ALL", "JAVA_HOME",
    "ANDROID_HOME", "ANDROID_SDK_ROOT", "GITHUB_REPOSITORY", "GITHUB_EVENT_PATH",
    "GITHUB_EVENT_NAME", "GITHUB_REF", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT",
}


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT, help="Checkout, including uncommitted application changes")
    parser.add_argument("--commit", help="Exact 40-character SHA; omit to include working changes")
    parser.add_argument("--output", type=Path, help="New directory for reports; must not exist")
    parser.add_argument("--repository", help="Repository identity for explicit local comparison context")
    parser.add_argument("--branch-ref", help="Full development ref when explicitly known")
    parser.add_argument("--pr-number", type=int, help="Explicit PR comparison identity")
    parser.add_argument("--previous", type=Path, help="Previous Python session or existing evidence directory")
    parser.add_argument("--flutter-bin", help="Explicit Flutter 3.29.3 executable; otherwise discover or install it")
    parser.add_argument("--runtime", choices=("auto", "existing", "managed"), default="auto",
                        help="Reuse local Docker or provision a disposable engine (default: auto)")
    parser.add_argument("--apk", type=Path, help="Record APK evidence (existing runner limitations apply)")
    parser.add_argument("--android", action="store_true", help="Use the existing emulator runner")
    parser.add_argument("--security", action="store_true", help="Include existing isolated security runtime")
    parser.add_argument("--ci-checks", action="store_true", help="Run existing CI tooling contracts and pinned Gitleaks locally")
    parser.add_argument("--all", action="store_true", help="Include Android, offline security and CI checks; requires --commit for Android provenance")
    parser.add_argument("--cloudinary", action="store_true", help="Also prompt privately and run the existing live Cloudinary suite")
    parser.add_argument("--test-cloud", help="Explicitly approved isolated Cloudinary test cloud; used only with --cloudinary")
    parser.add_argument("--profile", choices=("full", "tooling", "backend-smoke", "security"), default="full")
    args = parser.parse_args(argv)
    if args.all:
        args.android = args.security = args.ci_checks = True
    if args.profile == "security":
        args.security = True
    if args.cloudinary and (not args.commit or not args.test_cloud):
        parser.error("--cloudinary requires --test-cloud APPROVED_TEST_CLOUD and --commit EXACT_SHA")
    if args.test_cloud and not args.cloudinary:
        parser.error("--test-cloud requires --cloudinary")
    if args.android and (not args.commit or args.profile != "full"):
        parser.error("Android validation requires --profile full and --commit EXACT_SHA. Use --commit (git rev-parse HEAD) in PowerShell to test the committed revision.")
    for key in ("source", "output", "previous", "apk"):
        value = getattr(args, key)
        if value is not None:
            setattr(args, key, value.expanduser().resolve())
    if args.previous and (args.previous / "evidence").is_dir():
        args.previous /= "evidence"
    if args.flutter_bin and ("/" in args.flutter_bin or "\\" in args.flutter_bin):
        args.flutter_bin = str(Path(args.flutter_bin).expanduser().resolve())
    if args.commit and (len(args.commit) != 40 or any(c not in "0123456789abcdef" for c in args.commit)):
        parser.error("--commit requires a complete lowercase 40-character SHA")
    return args


def session_environment(scratch, environment=None):
    original = os.environ if environment is None else environment
    env = {k.upper(): v for k, v in original.items() if k.upper() in ENV_KEYS}
    locations = {
        "HOME": "home", "USERPROFILE": "home", "APPDATA": "appdata",
        "LOCALAPPDATA": "localappdata", "PUB_CACHE": "pub-cache",
        "NPM_CONFIG_CACHE": "npm-cache", "GRADLE_USER_HOME": "gradle",
        "PIP_CACHE_DIR": "pip-cache",
        "TMP": "tmp", "TEMP": "tmp", "TMPDIR": "tmp",
    }
    # Preserve discovery of a preinstalled Android SDK before isolating HOME.
    if not env.get("ANDROID_HOME") and not env.get("ANDROID_SDK_ROOT"):
        base = original.get("LOCALAPPDATA") if os.name == "nt" else original.get("HOME")
        candidate = Path(base or "") / "Android/Sdk"
        if sys.platform == "darwin":
            candidate = Path(base or "") / "Library/Android/sdk"
        if base and candidate.is_dir():
            env["ANDROID_HOME"] = str(candidate.resolve())
    for key, folder in locations.items():
        directory = scratch / folder
        directory.mkdir(exist_ok=True)
        env[key] = str(directory)
    bin_dir = scratch / "venv" / ("Scripts" if os.name == "nt" else "bin")
    env["VIRTUAL_ENV"] = str(scratch / "venv")
    env["PATH"] = str(bin_dir) + os.pathsep + env.get("PATH", "")
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env["PSModuleAnalysisCachePath"] = str(scratch / "powershell-module-cache")
    env["GIT_TERMINAL_PROMPT"] = "0"
    env["GCM_INTERACTIVE"] = "never"
    # Docker uses the existing local engine/context, never an application .env.
    docker_config = Path(original.get("DOCKER_CONFIG") or (Path(original.get("USERPROFILE") or original.get("HOME") or "~") / ".docker"))
    if docker_config.is_dir():
        env["DOCKER_CONFIG"] = str(docker_config.resolve())
    return env


def reproduction_command(args):
    # Reproduce through the launcher: resolved Docker/SDK paths disappear during
    # cleanup. A new invocation must create a fresh output/session directory.
    argv = ["python", str(ROOT / "scripts/test_vocle.py"), "--source", str(args.source)]
    for name in ("commit", "previous", "flutter_bin", "apk"):
        if getattr(args, name, None):
            argv += ["--" + name.replace("_", "-"), str(getattr(args, name))]
    argv += ["--runtime", args.runtime, "--profile", args.profile]
    for name in (("all",) if args.all else ("android", "security", "ci_checks")):
        if getattr(args, name):
            argv.append("--" + name.replace("_", "-"))
    if args.cloudinary:
        argv += ["--cloudinary", "--test-cloud", "APPROVED_TEST_CLOUD"]
    quote = (lambda value: "'" + value.replace("'", "''") + "'") if os.name == "nt" else shlex.quote
    return ("& " if os.name == "nt" else "") + " ".join(quote(value) for value in argv)


class ManagedCommand:
    """Forward cancellation so the Node harness can finish its own cleanup."""

    def __init__(self):
        self.child = None
        self.interrupted = False

    def cancel(self, _signum, _frame):
        self.interrupted = True
        if self.child and self.child.poll() is None:
            print("Stopping checks and waiting for disposable-resource cleanup...", flush=True)
            try:
                self.child.send_signal(signal.CTRL_BREAK_EVENT if os.name == "nt" else signal.SIGTERM)
            except ProcessLookupError:
                pass
        else:
            raise KeyboardInterrupt

    def run(self, argv, *, env, cwd):
        names = [signal.SIGINT, signal.SIGTERM]
        if os.name == "nt":
            names.append(signal.SIGBREAK)
        saved = {name: signal.signal(name, self.cancel) for name in names}
        try:
            self.child = subprocess.Popen(
                argv, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0,
            )
            # Windows can defer Python signal handlers during an infinite OS wait.
            # Short bounded waits let Ctrl+C reach the harness while it is running.
            while True:
                try:
                    code = self.child.wait(timeout=0.2)
                    break
                except subprocess.TimeoutExpired:
                    continue
            return 130 if self.interrupted else code
        finally:
            for name, handler in saved.items():
                signal.signal(name, handler)


def runner_arguments(config):
    argv = [config["node"], str(ROOT / "tests/developer-workflow/run.mjs"),
            "--source", str(config["source"]), "--output", str(Path(config["output"]) / "evidence")]
    for key in VALUE_OPTIONS:
        if config.get(key):
            argv.extend(["--" + key.replace("_", "-"), str(config[key])])
    for key in ("android", "security", "ci_checks"):
        if config.get(key):
            argv.append("--" + key.replace("_", "-"))
    return argv


def worker(config_path):
    config = json.loads(Path(config_path).read_text(encoding="utf-8"))
    if sys.prefix == sys.base_prefix:
        raise RuntimeError("Disposable Python venv was not activated")
    print("Running existing tests from disposable Python environment.", flush=True)
    return ManagedCommand().run(runner_arguments(config), env=dict(os.environ), cwd=ROOT)


def remove_session(scratch):
    # Only delete the exact directory allocated by mkdtemp in the system temp root.
    resolved = scratch.resolve()
    if resolved.parent != Path(tempfile.gettempdir()).resolve() or not resolved.name.startswith("vocle-python-"):
        raise RuntimeError("Refusing unsafe disposable-session cleanup: " + str(resolved))

    def writable_retry(function, filename, _exc):
        path = Path(filename)
        canonical = Path(str(path.resolve()).removeprefix("\\\\?\\")) if os.name == "nt" else path.resolve()
        if not canonical.is_relative_to(resolved):
            raise RuntimeError("Cleanup path escaped the disposable session")
        error = _exc[1] if isinstance(_exc, tuple) else _exc
        if isinstance(error, FileNotFoundError):
            return  # A stopped build may have already removed a transient file.
        os.chmod(path, stat.S_IWRITE | stat.S_IREAD | stat.S_IEXEC)
        function(filename)

    # Gradle dependency names exceed MAX_PATH even in a short session folder.
    # Validate the ordinary absolute path above, then use Windows' extended form.
    target = "\\\\?\\" + str(resolved) if os.name == "nt" else resolved
    if sys.version_info >= (3, 12):
        shutil.rmtree(target, onexc=writable_retry)
    else:
        shutil.rmtree(target, onerror=writable_retry)


def run_session(args):
    planned = 187 if args.profile == "full" and args.android else 179 if args.profile == "full" else 0
    category = "full-187" if planned == 187 else "functional-179" if planned else args.profile
    output = args.output or ROOT / "test-results" / category / (
        datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ") + "-" + uuid.uuid4().hex[:8])
    output.mkdir(parents=True, exist_ok=False)
    state = {"schemaVersion": 1, "startedAt": datetime.now(timezone.utc).isoformat(),
             "status": "ERROR", "profile": args.profile, "source": str(args.source),
             "python": sys.version.split()[0], "cleanup": "NOT_STARTED", "runnerExitCode": None}
    state["reproduction"] = reproduction_command(args)
    state["functionalPlanned"] = planned
    print("Reports for this invocation: " + str(output), flush=True)
    (output / "README.md").write_text(f"# Local test run\n\nRUNNING. Profile: {args.profile}. Functional cases selected: {planned}.\n\nAll results from this invocation will be retained in this folder.\n", encoding="utf-8")
    scratch = None
    bootstrap = None
    code = 1
    try:
        if sys.version_info < (3, 10):
            raise RuntimeError("Python 3.10 or later is required")
        for tool in ("git",):
            if not shutil.which(tool):
                raise RuntimeError("Install prerequisite and put it on PATH: " + tool)
        scratch = Path(tempfile.mkdtemp(prefix="vocle-python-"))
        state["temporaryDirectory"] = str(scratch)
        state["cleanup"] = "PENDING"
        print("Creating disposable venv and package caches: " + str(scratch), flush=True)
        venv.EnvBuilder(with_pip=args.ci_checks).create(scratch / "venv")
        environment = session_environment(scratch)
        bootstrap = Bootstrap(scratch, output, environment, state)
        node = bootstrap.node()
        state["node"] = bootstrap.details["node"]["version"]
        config = {key: str(value) if isinstance(value, Path) else value for key, value in vars(args).items()}
        config.update(output=str(output), node=node, reproduction=state["reproduction"])
        if args.cloudinary:
            # Prompt in the user's terminal before invoking the noninteractive
            # worker. Neither credentials nor the cloud name enter its config.
            from test_vocle_cloudinary import parse_args as provider_args, run_session as provider_session
            provider_output = output / "cloudinary"
            state["cloudinaryExitCode"] = provider_session(provider_args([
                "--test-cloud", args.test_cloud, "--commit", args.commit, "--output", str(provider_output)]))
            if state["cloudinaryExitCode"] == 130:
                raise KeyboardInterrupt
            config["cloudinary_output"] = str(provider_output)
        config.pop("test_cloud", None)
        if args.ci_checks:
            config["gitleaks_bin"] = bootstrap.gitleaks()
            session_python = scratch / "venv" / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
            print("Preparing Python packages used by the existing security environment workflow...", flush=True)
            bootstrap.command([session_python, "-m", "pip", "install", "--disable-pip-version-check", "pytest", "requests", "httpx"], timeout=600)
            _, installed = bootstrap.command([session_python, "-m", "pip", "freeze"])
            bootstrap.details["pythonPackages"] = installed.splitlines()
        if args.profile in ("full", "backend-smoke", "security"):
            print("Preparing local Linux container runtime...", flush=True)
            config["docker_bin"] = bootstrap.docker(args.runtime)
            if os.name == "nt" and config["docker_bin"].endswith(".json"):
                config["docker_proxy"] = config["docker_bin"]
                config["docker_bin"] = sys.executable
        if args.profile == "full":
            print("Selecting or installing pinned Flutter 3.29.3...", flush=True)
            config["flutter_bin"] = bootstrap.flutter(args.flutter_bin)
        if args.android:
            bootstrap.android()
        config_path = scratch / "session.json"
        config_path.write_text(json.dumps(config), encoding="utf-8")
        python = scratch / "venv" / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
        command = ManagedCommand()
        code = command.run([str(python), "-B", str(Path(__file__).resolve()), "--_worker", str(config_path)],
                           env=environment, cwd=ROOT)
        state["runnerExitCode"] = code
        manifest_path = output / "evidence/manifest.json"
        if manifest_path.is_file():
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            state.update(gate=manifest["gate"], releaseGate=manifest.get("releaseGate"))
            report = json.loads((output / "evidence/results.json").read_text(encoding="utf-8"))
            state["counts"] = dict(Counter(row["status"] for row in report["results"]))
            functional_path = output / "functional-summary.json"
            if functional_path.exists():
                functional = json.loads(functional_path.read_text(encoding="utf-8"))
                state.update(functionalExecuted=functional["executed"], functionalCounts=functional["counts"])
                print(f"Functional cases executed: {functional['executed']}/{functional['registered']}; " + ", ".join(f"{key}={value}" for key, value in functional["counts"].items()), flush=True)
            blockers = Counter(row.get("exclusion") or row.get("error") or row["id"] for row in report["results"] if row["required"] and row["status"] == "BLOCKED")
            print("All report rows (functional, tooling and optional coverage): " + ", ".join(f"{status}={count}" for status, count in state["counts"].items()), flush=True)
            optional = [row["id"] for row in report["results"] if not row["required"] and row["status"] == "BLOCKED"]
            if optional:
                print("Optional coverage not executed: " + ", ".join(optional), flush=True)
            for reason, count in blockers.items():
                print(f"Required coverage blocked ({count}): {reason}", flush=True)
        else:
            raise RuntimeError("Runner produced no manifest; see terminal diagnostics")
        state["status"] = "PASS" if code == 0 and state["gate"] == "PASS" else "INTERRUPTED" if code == 130 else "ERROR" if code == 0 else "NON_SUCCESS"
        if state["status"] != "PASS" and code == 0:
            code = 1
    except KeyboardInterrupt:
        state["status"], state["error"], code = "INTERRUPTED", "Cancelled by user", 130
    except SetupRequired as error:
        state["status"], state["error"] = error.status, str(error)
        code = 3 if error.status == "RESTART_REQUIRED" else 1
    except Exception as error:
        state["error"] = str(error)
        code = 1
    finally:
        can_remove = True
        if bootstrap:
            try:
                bootstrap.close()
            except Exception as error:
                can_remove = False
                state["cleanup"], state["cleanupError"], state["status"], code = "ERROR", str(error), "ERROR", 1
        if scratch and can_remove:
            try:
                remove_session(scratch)
                state["cleanup"] = "PASS"
            except Exception as error:
                state["cleanup"], state["cleanupError"], state["status"], code = "ERROR", str(error), "ERROR", 1
        state["finishedAt"] = datetime.now(timezone.utc).isoformat()
        if state["cleanup"] == "ERROR":
            state["testGate"] = state.get("gate")
            state["gate"] = state["releaseGate"] = "ERROR"
        if state["status"] != "PASS":
            (output / "evidence/pass-manifest.json").unlink(missing_ok=True)
        (output / "local-session.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        evidence_links = ("Existing JSON, Markdown, JUnit, ownership and submission evidence: [evidence/](evidence/).\n\n"
                          "Open [the local dashboard](evidence/detailed/vocle-regression-dashboard.html) for test details.\n\n") if (output / "evidence").is_dir() else "Application tests have not started. See [setup.log](setup.log) for automatic setup diagnostics.\n\n"
        (output / "local-session.md").write_text(
            "# Disposable local test session\n\n"
            + f"Session: **{state['status']}**. Profile: {args.profile}. "
            + f"Test gate: {state.get('gate', 'NO_EVIDENCE')}. Cleanup: {state['cleanup']}.\n\n"
            + "Reproduce from the recorded harness revision (replace APPROVED_TEST_CLOUD for a live provider run):\n\n```\n" + state["reproduction"] + "\n```\n\n"
            + evidence_links
            + "A tooling/smoke PASS does not certify the full application or release.\n\n"
            + ("Error: " + state["error"] + "\n" if state.get("error") else "")
            + ("Cleanup error: " + state["cleanupError"] + "\n" if state.get("cleanupError") else ""),
            encoding="utf-8",
        )
        (output / "README.md").write_text(
            "# Local test run\n\n"
            + f"Profile: **{args.profile}**. Functional cases executed: **{state.get('functionalExecuted', 0)}/{planned}**. Cleanup: **{state['cleanup']}**.\n\n"
            + ("Open [the functional dashboard](vocle-regression-dashboard.html) for the selected catalog cases.\n\n" if (output / "vocle-regression-dashboard.html").exists() else "No functional dashboard was produced; inspect the setup/session error.\n\n")
            + "[Session and environment details](local-session.md) · [All checks, logs and original results](evidence/)\n\n"
            + "This folder contains results from this invocation only. Prior runs are not imported.\n",
            encoding="utf-8")
        if planned == 187:
            results_root = ROOT / "test-results"
            results_root.mkdir(exist_ok=True)
            (results_root / "LATEST_FULL_RUN.txt").write_text(str(output) + "\n" + str(output / "vocle-regression-dashboard.html") + "\n" + f"Executed: {state.get('functionalExecuted', 0)}/187; session: {state['status']}; cleanup: {state['cleanup']}\n", encoding="utf-8")
        print(f"Reports: {output}\nSession: {state['status']}; cleanup: {state['cleanup']}", flush=True)
        if state.get("error"):
            print(state["error"], file=sys.stderr)
        if state.get("cleanupError"):
            print("Cleanup failed: " + state["cleanupError"], file=sys.stderr)
    return code


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--_worker":
        sys.exit(worker(sys.argv[2]))
    try:
        sys.exit(run_session(parse_args()))
    except (FileExistsError, PermissionError) as error:
        print("Cannot create a fresh report directory: " + str(error), file=sys.stderr)
        sys.exit(1)
