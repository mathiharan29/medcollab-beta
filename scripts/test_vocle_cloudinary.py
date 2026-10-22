#!/usr/bin/env python3
"""Run the existing real Cloudinary suite against an explicitly approved test cloud.

Credentials are entered with hidden terminal prompts, held in process memory,
and passed only to the guarded provider processes. No credential file is read.
"""

import argparse
from datetime import datetime, timezone
import getpass
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import uuid
import venv

from test_vocle import ROOT, remove_session, session_environment
from vocle_bootstrap import Bootstrap, checked


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test-cloud", required=True, help="Explicitly approved isolated test cloud name")
    parser.add_argument("--commit", required=True, help="Exact application commit SHA")
    parser.add_argument("--output", type=Path, help="New report directory")
    parser.add_argument("--offline-check", action="store_true", help="Validate preparation and guards without credentials or provider calls")
    parser.add_argument("--resume-cleanup", type=Path, help="Previous sanitized vocle-cloudinary-results directory; retry only its recorded resources")
    args = parser.parse_args(argv)
    if not re.fullmatch(r"[a-f0-9]{40}", args.commit):
        parser.error("--commit requires the complete lowercase SHA")
    if not re.fullmatch(r"[a-z0-9_-]{3,80}", args.test_cloud) or re.search(r"(^|[-_])(prod|production|live)([-_]|$)", args.test_cloud, re.I):
        parser.error("An isolated non-production test cloud name is required")
    return args


def fingerprints(directory):
    return {p.relative_to(directory).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(directory.rglob("*")) if p.is_file()}


def run_session(args):
    if not args.offline_check and os.environ.get("GITHUB_ACTIONS") == "true":
        raise RuntimeError("Use the existing guarded Cloudinary workflow in GitHub Actions; the local launcher requires a developer terminal.")
    if not args.offline_check and not sys.stdin.isatty():
        raise RuntimeError("Run this command in your own terminal for hidden credential entry; credentials cannot be supplied in chat, arguments or files.")
    output = (args.output or ROOT / "test-results/cloudinary" / (
        datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%M-%SZ") + "-" + uuid.uuid4().hex[:8])).resolve()
    output.mkdir(parents=True, exist_ok=False)
    print("Reports for this invocation: " + str(output), flush=True)
    state = {"sourceSha": args.commit, "executionMode": "local", "status": "ERROR", "cleanup": "NOT_STARTED", "providerExecuted": False}
    scratch = None
    setup = None
    provider_env = {}
    secrets = []
    keep_scratch = False
    try:
        scratch = Path(tempfile.mkdtemp(prefix="vocle-python-"))
        venv.EnvBuilder(with_pip=False).create(scratch / "venv")
        env = session_environment(scratch)
        setup = Bootstrap(scratch, output, env, state)
        node = setup.node()
        target = scratch / "target"
        checked(["git", "clone", "--no-hardlinks", "--no-checkout", "--", ROOT, target], env=env)
        checked(["git", "-C", target, "checkout", "--detach", args.commit], env=env)
        state["harnessSha"] = checked(["git", "-C", ROOT, "rev-parse", "HEAD"], env=env)[1].strip()
        # Use the existing suite and this checkout's explicit local guard adapter.
        suite = Path("medcollab-backend/scripts/security-cloudinary")
        shutil.copytree(ROOT / suite, target / suite, dirs_exist_ok=True)
        state["harnessFiles"] = fingerprints(target / suite)
        backend = target / "medcollab-backend"
        runner_temp = scratch / "provider"
        runner_temp.mkdir()
        provider_env = env | {"NODE_ENV": "test", "VOCLE_CLOUDINARY_LIVE": "isolated-synthetic-only",
                              "VOCLE_CLOUDINARY_LOCAL": "isolated-synthetic-only",
                              "VOCLE_LOCAL_APPROVED_CLOUD": args.test_cloud,
                              "VOCLE_LOCAL_RUN_ID": str(uuid.uuid4().int), "VOCLE_LOCAL_SOURCE": args.commit,
                              "CLOUDINARY_TEST_CLOUD_NAME": args.test_cloud, "CLOUDINARY_CLOUD_NAME": args.test_cloud,
                              "RUNNER_TEMP": str(runner_temp)}
        results = runner_temp / "vocle-cloudinary-results"
        if args.resume_cleanup:
            previous = args.resume_cleanup.resolve()
            safety = json.loads((previous / "safety.json").read_text(encoding="utf-8"))
            if safety.get("executionMode") != "local" or safety["source"] != args.commit:
                raise RuntimeError("Cleanup evidence must be from a local run of this exact source SHA")
            results.mkdir()
            for name in ("safety.json", "resources.json"):
                shutil.copyfile(previous / name, results / name)
            provider_env["VOCLE_LOCAL_RUN_ID"] = safety["runId"]
        # Install packages without any provider credentials, as in the workflow.
        npm = str(Path(node).with_name("npm.cmd" if os.name == "nt" else "npm")) if Path(node).is_absolute() else ("npm.cmd" if os.name == "nt" else "npm")
        if not Path(npm).exists() and os.path.isabs(npm):
            npm = shutil.which("npm.cmd" if os.name == "nt" else "npm", path=env["PATH"])
        old_directory = Path.cwd()
        os.chdir(backend)
        try:
            # This checks cloud approval, mode, identity and credential-file
            # isolation before installing anything. It performs no provider I/O.
            checked([node, str(target / suite / "guard.js")], env=provider_env | {
                "CLOUDINARY_API_KEY": "offline-key-sentinel", "CLOUDINARY_API_SECRET": "offline-secret-sentinel"})
            checked([npm, "ci", "--ignore-scripts", "--no-audit", "--no-fund"], env=env, timeout=600, log=output / "setup.log")
            for script in ("check.js", "self-test.js", "transport-test.js"):
                checked([node, str(target / suite / script)], env=env, log=output / "offline.log")
            if args.offline_check:
                state.update(status="PASS", providerExecuted=False, offlineChecks="PASS")
                return 0
            print("Enter the credentials for the isolated test cloud. Both values are hidden and kept only in memory.", flush=True)
            secrets = [getpass.getpass("Cloudinary test API key: "), getpass.getpass("Cloudinary test API secret: ")]
            if not all(s.strip() for s in secrets):
                raise RuntimeError("Both test credentials are required")
            provider_env.update(CLOUDINARY_API_KEY=secrets[0], CLOUDINARY_API_SECRET=secrets[1])

            def provider_step(script, *arguments, timeout=120):
                # Capture output and never let raw SDK errors reach logs/console.
                try:
                    code, text = checked([node, str(target / suite / script), *arguments], env=provider_env, timeout=timeout, check=False)
                except Exception:
                    return 1
                for value in [args.test_cloud, *secrets]:
                    text = text.replace(value, "[REDACTED]")
                with (output / "provider.log").open("a", encoding="utf-8") as log:
                    log.write(text + "\n")
                return code

            if provider_step("guard.js") != 0:
                raise RuntimeError("Provider safety preflight rejected configuration; see sanitized provider.log")
            run_code = 1
            cleanup_code = 1
            try:
                if not args.resume_cleanup:
                    state["providerExecuted"] = True
                    run_code = provider_step("run.js", timeout=540)
                else:
                    run_code = 0
            finally:
                if (results / "resources.json").exists():
                    cleanup_code = provider_step("run.js", "--cleanup-only", timeout=180)
                else:
                    cleanup_code = 0  # Guard ran, no resource operation was journaled.
                hygiene = provider_step("check.js", "--artifacts")
                if hygiene == 0:
                    shutil.copytree(results, output / "vocle-cloudinary-results")
                else:
                    keep_scratch = True
                    state["privateEvidenceDirectory"] = str(results)
                    raise RuntimeError("Artifact hygiene failed; private recovery journal retained; reports were not exported")
            report = results / "results.json"
            if report.exists():
                state["counts"] = json.loads(report.read_text(encoding="utf-8"))["counts"]
            post_cleanup = results / "post-job-cleanup.json"
            state["providerCleanup"] = "PASS" if cleanup_code == 0 and (not (results / "resources.json").exists() or post_cleanup.exists() and json.loads(post_cleanup.read_text(encoding="utf-8")).get("proven") is True) else "ERROR"
            if args.resume_cleanup:
                complete = state["providerCleanup"] == "PASS"
            else:
                counts = state.get("counts", {})
                complete = counts.get("executed") == counts.get("registered") == 34
            state["status"] = "PASS" if run_code == 0 and complete and state["providerCleanup"] == "PASS" else "NON_SUCCESS"
        finally:
            os.chdir(old_directory)
        return 0 if state["status"] == "PASS" else 1
    except KeyboardInterrupt:
        state["status"] = "INTERRUPTED"
        return 130
    except Exception as error:
        # Only this script's fixed messages are persisted; dependency errors may
        # contain paths but provider exceptions are discarded in provider_step.
        message = str(error)
        for value in [args.test_cloud, *secrets]:
            message = message.replace(value, "[REDACTED]")
        state["error"] = message
        return 1
    finally:
        provider_env.clear()
        secrets.clear()
        if setup:
            try:
                setup.close()
            except Exception:
                keep_scratch = True
                state["error"] = "Disposable runtime cleanup failed; recovery directory retained"
        if scratch and not keep_scratch:
            try:
                remove_session(scratch)
                state["cleanup"] = "PASS"
            except Exception:
                state.update(cleanup="ERROR", status="ERROR", temporaryDirectory=str(scratch))
        elif keep_scratch:
            state.update(cleanup="RECOVERY_REQUIRED", status="ERROR")
        (output / "local-session.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        print(f"Reports: {output}\nSession: {state['status']}; cleanup: {state['cleanup']}", flush=True)
        if state.get("error"):
            print(state["error"], file=sys.stderr)
        if state["cleanup"] != "PASS":
            raise RuntimeError("Local Cloudinary cleanup requires recovery; see local-session.json")


if __name__ == "__main__":
    try:
        sys.exit(run_session(parse_args()))
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
