"""Prepare an owned Android emulator for the existing eight-case runner."""

import os
import hashlib
import string
from pathlib import Path
import shutil
import socket
import subprocess
import time
import uuid

from vocle_bootstrap import SetupRequired, LOCK, download, extract


class AndroidRuntime:
    def __init__(self, scratch, output, env, command, state):
        self.scratch, self.output, self.env = scratch, output, env
        self.command, self.state = command, state
        self.process = self.log = self.adb = self.serial = None

    def prepare(self):
        self.prepare_host()
        self.start_emulator()

    def prepare_host(self):
        """Gradle/JDK/adb only — no AVD. Lets APK prewarm finish before qemu RAM."""
        suffix = ".exe" if os.name == "nt" else ""
        sdk = Path(self.env.get("ANDROID_HOME") or self.env.get("ANDROID_SDK_ROOT") or "")
        self.adb = sdk / "platform-tools" / ("adb" + suffix)
        self.emulator_bin_path = sdk / "emulator" / ("emulator" + suffix)
        self.avd_managers = sorted((sdk / "cmdline-tools").glob("*/bin/avdmanager" + (".bat" if os.name == "nt" else "")))
        if not sdk.is_absolute() or not self.adb.is_file() or not self.emulator_bin_path.is_file() or not self.avd_managers:
            raise SetupRequired("Android tests need an Android SDK with platform-tools, emulator and command-line tools. Set ANDROID_HOME to its directory.")
        java = Path(self.env.get("JAVA_HOME") or "")
        if not (java / "bin" / ("java" + suffix)).is_file() and os.name == "nt":
            java = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Android/Android Studio/jbr"
        if not (java / "bin" / ("java" + suffix)).is_file():
            raise SetupRequired("Android tests need the Android Studio JDK or JAVA_HOME.")
        self.env.update(ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk), JAVA_HOME=str(java))
        self.env["PATH"] = str(java / "bin") + os.pathsep + self.env["PATH"]
        # The committed Gradle arguments refer to this relative truststore.
        # Provide the JDK's trusted CAs only in the disposable build workspace.
        # On Windows, also import desktop AV HTTPS-inspection roots (e.g. Avast)
        # so plugin portal / dependency downloads do not fail TLS verify.
        truststore = self.scratch / "android-truststore.jks"
        shutil.copyfile(java / "lib/security/cacerts", truststore)
        if os.name == "nt":
            cache = Path(os.environ.get("LOCALAPPDATA") or "") / "vocle-runtime-cache"
            keytool = java / "bin" / "keytool.exe"
            for alias, name in (("vocle-avast-root", "avast-web-shield-root.pem"),
                                ("vocle-windows-roots", "windows-roots.pem")):
                pem = cache / name
                if pem.is_file() and keytool.is_file():
                    self.command([
                        str(keytool), "-importcert", "-noprompt", "-alias", alias,
                        "-file", str(pem), "-keystore", str(truststore), "-storepass", "changeit",
                    ], check=False)
        self.env["VOCLE_ANDROID_TRUSTSTORE"] = str(truststore)
        self.prepare_gradle()
        # Reset adb and kill orphaned qemu from prior Vocle runs so stale
        # emulator-* rows do not block an otherwise empty machine.
        if os.name == "nt":
            for image in ("qemu-system-x86_64-headless.exe", "qemu-system-x86_64.exe", "emulator.exe"):
                subprocess.run(["taskkill.exe", "/IM", image, "/F"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            time.sleep(2)
        self.command([self.adb, "kill-server"], check=False)
        self.command([self.adb, "start-server"], check=False)
        _, devices = self.command([self.adb, "devices"])
        if any(line.strip() and not line.startswith(("List of devices", "*")) for line in devices.splitlines()):
            raise SetupRequired("Close other Android emulators and disconnect physical devices before the isolated Android run. adb devices:\n" + devices)
        images = sorted((sdk / "system-images").glob("*/*/x86_64/package.xml"), reverse=True)
        if not images:
            raise SetupRequired("Install an x86_64 Android system image using Android Studio's SDK Manager before the Android lane.")
        image = images[0].parent
        self.system_image_package = "system-images;" + ";".join(image.relative_to(sdk / "system-images").parts)
        home, avds = self.scratch / "android-home", self.scratch / "android-avd"
        home.mkdir(exist_ok=True)
        avds.mkdir(exist_ok=True)
        self.env.update(ANDROID_USER_HOME=str(home), ANDROID_AVD_HOME=str(avds))
        self.java_home = java
        self.sdk_root = sdk
        # Reserve serial/port before qemu starts so the device lane can wait on it.
        port = None
        for candidate in range(5580, 5650, 2):
            with socket.socket() as console, socket.socket() as transport:
                try:
                    console.bind(("127.0.0.1", candidate))
                    transport.bind(("127.0.0.1", candidate + 1))
                    port = candidate
                    break
                except OSError:
                    continue
        if port is None:
            raise SetupRequired("No free local port for the owned Android emulator")
        self.serial = "emulator-" + str(port)
        self.emulator_port = port
        self.avd_name = "VocleLocal" + uuid.uuid4().hex[:10]
        self.env.update(VOCLE_ANDROID_SERIAL=self.serial, VOCLE_ANDROID_AVD=self.avd_name)
        self.state.update(kind="disposable-emulator", serial=self.serial, systemImage=self.system_image_package,
                          ramMb=1024, cpuCores=2,
                          sdk=str(sdk), java=str(java), userAvdReused=False, cleanup="PENDING",
                          deferredBoot=True)

    def start_emulator(self):
        """Create and boot the disposable AVD (call after APK prewarm on 8GB hosts)."""
        if not self.serial or not self.avd_name:
            raise SetupRequired("prepare_host() must run before start_emulator()")
        directory = Path(self.env["ANDROID_AVD_HOME"]) / (self.avd_name + ".avd")
        print("Creating a disposable Android emulator from installed image: " + self.system_image_package, flush=True)
        self.command([self.avd_managers[-1], "create", "avd", "--force", "--name", self.avd_name, "--path", directory,
                      "--package", self.system_image_package, "--device", "pixel"], timeout=120, input_text="no\n")
        # Keep the disposable AVD lean on 8GB Windows hosts (WHPX + WSL Docker).
        # 1024MB leaves headroom when Cursor/AV leave ~2GB free physical RAM.
        with (directory / "config.ini").open("a", encoding="utf-8") as config:
            config.write("\nhw.ramSize=1024\nhw.cpu.ncore=2\ndisk.dataPartition.size=4G\n")
        self.command([self.adb, "start-server"], check=False)
        self.log = (self.output / "android-emulator.log").open("wb")
        # Prefer DETACHED_PROCESS over CREATE_NO_WINDOW: the latter has been
        # observed to make qemu exit immediately (status 4294967295) on this host.
        win_flags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
        self.process = subprocess.Popen([str(self.emulator_bin_path), "-avd", self.avd_name, "-port", str(self.emulator_port),
                                         "-no-window", "-no-audio", "-no-snapshot", "-no-boot-anim",
                                         "-gpu", "swiftshader_indirect"],
                                        env=self.env, stdin=subprocess.DEVNULL, stdout=self.log,
                                        stderr=subprocess.STDOUT, creationflags=win_flags,
                                        close_fds=False)
        self.state["deferredBoot"] = False
        # Cold boot of a Play Store image under WHPX often exceeds five minutes.
        deadline = time.monotonic() + 900
        last_report = 0
        while time.monotonic() < deadline:
            exit_code = self.process.poll()
            if exit_code is not None:
                try:
                    self.log.flush()
                except Exception:
                    pass
                raise SetupRequired(
                    f"Owned Android emulator stopped (exit {exit_code}); see android-emulator.log"
                )
            code, boot = self.command([self.adb, "-s", self.serial, "shell", "getprop", "sys.boot_completed"], timeout=15, check=False)
            token = (boot or "").strip().split()[0] if boot else ""
            if code == 0 and token == "1":
                self.command([self.adb, "-s", self.serial, "shell", "input", "keyevent", "82"], check=False)
                print("Disposable Android emulator ready: " + self.serial, flush=True)
                return
            elapsed = int(time.monotonic() - (deadline - 900))
            if elapsed - last_report >= 60:
                print("Waiting for Android emulator boot (" + str(elapsed) + "s)...", flush=True)
                last_report = elapsed
            time.sleep(2)
        raise SetupRequired("Owned Android emulator did not boot in fifteen minutes; see android-emulator.log")

    def prepare_gradle(self):
        asset = LOCK["gradle"]
        # Gradle's wrapper keys its distribution cache by base-36 MD5 of the URL.
        value = int.from_bytes(hashlib.md5(asset["wrapperUrl"].encode()).digest(), "big")
        key = ""
        while value:
            value, remainder = divmod(value, 36)
            key = (string.digits + string.ascii_lowercase)[remainder] + key
        filename = asset["wrapperUrl"].rsplit("/", 1)[-1]
        folder = filename.removesuffix(".zip")
        user_cache = Path(os.environ.get("GRADLE_USER_HOME") or (Path(os.environ.get("USERPROFILE") or os.environ.get("HOME") or "~") / ".gradle"))
        cached = user_cache / "wrapper/dists" / folder / key / filename
        archive = None
        if cached.is_file():
            with cached.open("rb") as stream:
                digest = hashlib.sha256()
                while chunk := stream.read(1024 * 1024):
                    digest.update(chunk)
            if digest.hexdigest() == asset["sha256"]:
                archive = cached
        if archive is None:
            archive = download(asset, self.scratch / filename)
        destination = Path(self.env["GRADLE_USER_HOME"]) / "wrapper/dists" / folder / key
        destination.mkdir(parents=True, exist_ok=True)
        extended = Path("\\\\?\\" + str(destination.resolve())) if os.name == "nt" else destination
        print("Preparing verified Gradle " + asset["version"] + " in the disposable cache...", flush=True)
        extract(archive, extended)
        (destination / (filename + ".ok")).touch()
        self.state["gradle"] = {"version": asset["version"], "sha256": asset["sha256"], "source": "verified-existing-archive" if archive == cached else "verified-download"}

    def close(self):
        try:
            # Node may have parked then restarted the AVD under a new PID while
            # self.process still points at the original (already-exited) handle.
            # Always stop by serial, then force-kill leftover qemu if needed.
            if self.adb and self.serial:
                self.command([self.adb, "-s", self.serial, "emu", "kill"], timeout=15, check=False)
            if self.process and self.process.poll() is None:
                try:
                    self.process.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    self.process.terminate()
                    try:
                        self.process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        pass
            # Windows often keeps qemu lock files briefly after emu kill.
            deadline = time.monotonic() + 90
            while time.monotonic() < deadline:
                alive = self.process and self.process.poll() is None
                if not alive and os.name == "nt":
                    # Detached restart from run.mjs leaves qemu without our Popen handle.
                    probe = subprocess.run(
                        ["tasklist.exe", "/FI", "IMAGENAME eq qemu-system-x86_64-headless.exe"],
                        capture_output=True, text=True, check=False)
                    if "qemu-system-x86_64-headless.exe" not in (probe.stdout or ""):
                        probe = subprocess.run(
                            ["tasklist.exe", "/FI", "IMAGENAME eq qemu-system-x86_64.exe"],
                            capture_output=True, text=True, check=False)
                        if "qemu-system-x86_64.exe" not in (probe.stdout or ""):
                            break
                elif not alive:
                    break
                time.sleep(1)
            if os.name == "nt":
                if self.process and self.process.poll() is None:
                    subprocess.run(["taskkill.exe", "/pid", str(self.process.pid), "/T", "/F"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
                    try:
                        self.process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        pass
                for image in ("qemu-system-x86_64-headless.exe", "qemu-system-x86_64.exe", "emulator.exe"):
                    subprocess.run(["taskkill.exe", "/IM", image, "/F"],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            time.sleep(5)
            self.state["cleanup"] = "PASS"
        finally:
            if self.log:
                self.log.close()
