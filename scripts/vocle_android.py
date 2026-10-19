"""Prepare an owned Android emulator for the existing eight-case runner."""

import os
import hashlib
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
        suffix = ".exe" if os.name == "nt" else ""
        sdk = Path(self.env.get("ANDROID_HOME") or self.env.get("ANDROID_SDK_ROOT") or "")
        self.adb = sdk / "platform-tools" / ("adb" + suffix)
        emulator = sdk / "emulator" / ("emulator" + suffix)
        managers = sorted((sdk / "cmdline-tools").glob("*/bin/avdmanager" + (".bat" if os.name == "nt" else "")))
        if not sdk.is_absolute() or not self.adb.is_file() or not emulator.is_file() or not managers:
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
        truststore = self.scratch / "android-truststore.jks"
        shutil.copyfile(java / "lib/security/cacerts", truststore)
        self.env["VOCLE_ANDROID_TRUSTSTORE"] = str(truststore)
        self.prepare_gradle()
        _, devices = self.command([self.adb, "devices"])
        if any(line.strip() and not line.startswith(("List of devices", "*")) for line in devices.splitlines()):
            raise SetupRequired("Close other Android emulators and disconnect physical devices before the isolated Android run.")
        images = sorted((sdk / "system-images").glob("*/*/x86_64/package.xml"), reverse=True)
        if not images:
            raise SetupRequired("Install an x86_64 Android system image using Android Studio's SDK Manager before the Android lane.")
        image = images[0].parent
        package = "system-images;" + ";".join(image.relative_to(sdk / "system-images").parts)
        home, avds = self.scratch / "android-home", self.scratch / "android-avd"
        home.mkdir()
        avds.mkdir()
        self.env.update(ANDROID_USER_HOME=str(home), ANDROID_AVD_HOME=str(avds))
        name = "VocleLocal" + uuid.uuid4().hex[:10]
        directory = avds / (name + ".avd")
        print("Creating a disposable Android emulator from installed image: " + package, flush=True)
        self.command([managers[-1], "create", "avd", "--force", "--name", name, "--path", directory,
                      "--package", package, "--device", "pixel"], timeout=120, input_text="no\n")
        with (directory / "config.ini").open("a", encoding="utf-8") as config:
            config.write("\nhw.ramSize=4096\nhw.cpu.ncore=4\ndisk.dataPartition.size=4G\n")
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
        self.log = (self.output / "android-emulator.log").open("wb")
        self.process = subprocess.Popen([str(emulator), "-avd", name, "-port", str(port), "-no-window", "-no-audio",
                                         "-no-snapshot", "-no-boot-anim", "-gpu", "swiftshader_indirect"],
                                        env=self.env, stdin=subprocess.DEVNULL, stdout=self.log,
                                        stderr=subprocess.STDOUT, **({"creationflags": subprocess.CREATE_NO_WINDOW} if os.name == "nt" else {}))
        self.state.update(kind="disposable-emulator", serial=self.serial, systemImage=package,
                          ramMb=4096, cpuCores=4,
                          sdk=str(sdk), java=str(java), userAvdReused=False, cleanup="PENDING")
        deadline = time.monotonic() + 300
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise SetupRequired("Owned Android emulator stopped; see android-emulator.log")
            code, boot = self.command([self.adb, "-s", self.serial, "shell", "getprop", "sys.boot_completed"], timeout=15, check=False)
            if code == 0 and boot == "1":
                self.command([self.adb, "-s", self.serial, "shell", "input", "keyevent", "82"], check=False)
                print("Disposable Android emulator ready: " + self.serial, flush=True)
                return
            time.sleep(2)
        raise SetupRequired("Owned Android emulator did not boot in five minutes; see android-emulator.log")

    def prepare_gradle(self):
        asset = LOCK["gradle"]
        # Gradle's wrapper keys its distribution cache by base-36 MD5 of the URL.
        value = int.from_bytes(hashlib.md5(asset["wrapperUrl"].encode()).digest(), "big")
        key = ""
        while value:
            value, remainder = divmod(value, 36)
            key = "0123456789abcdefghijklmnopqrstuvwxyz"[remainder] + key
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
            if self.process and self.process.poll() is None:
                self.command([self.adb, "-s", self.serial, "emu", "kill"], timeout=15, check=False)
                try:
                    self.process.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    self.process.terminate()
                    self.process.wait(timeout=15)
            self.state["cleanup"] = "PASS"
        finally:
            if self.log:
                self.log.close()
