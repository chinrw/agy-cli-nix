import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import textwrap
import unittest


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]


class UpdateScriptTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmpdir.cleanup)
        self.work = pathlib.Path(self.tmpdir.name) / "repo"
        self.work.mkdir()

        shutil.copy2(REPO_ROOT / "flake.nix", self.work / "flake.nix")
        shutil.copy2(REPO_ROOT / "package.nix", self.work / "package.nix")
        (self.work / "scripts").mkdir()
        shutil.copy2(REPO_ROOT / "scripts" / "update.sh", self.work / "scripts" / "update.sh")
        (self.work / "scripts" / "update.sh").chmod(0o755)

        self.bin_dir = pathlib.Path(self.tmpdir.name) / "bin"
        self.bin_dir.mkdir()
        self.state_file = pathlib.Path(self.tmpdir.name) / "calls.log"

    def _write_stub(self, name: str, script: str) -> None:
        path = self.bin_dir / name
        path.write_text(textwrap.dedent(script), encoding="utf-8")
        path.chmod(0o755)

    def _run_update(self, *args: str, env_overrides=None):
        env = os.environ.copy()
        env["PATH"] = f"{self.bin_dir}:{env['PATH']}"
        env["STUB_LOG"] = str(self.state_file)
        if env_overrides:
            env.update(env_overrides)
        bash_bin = shutil.which("bash") or "bash"
        return subprocess.run(
            [bash_bin, str(self.work / "scripts" / "update.sh"), *args],
            cwd=self.work,
            env=env,
            capture_output=True,
            text=True,
        )

    def test_already_up_to_date(self):
        current = self._read_version()
        self._install_gh_stub(current)
        self._install_nix_stub({})

        before = (self.work / "package.nix").read_text(encoding="utf-8")
        result = self._run_update()
        after = (self.work / "package.nix").read_text(encoding="utf-8")

        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertEqual(before, after)

    def test_check_detects_newer_version_without_modifying(self):
        self._install_gh_stub("9.9.9")
        self._install_nix_stub({})

        before = (self.work / "package.nix").read_text(encoding="utf-8")
        result = self._run_update("--check")
        after = (self.work / "package.nix").read_text(encoding="utf-8")

        self.assertEqual(result.returncode, 1)
        self.assertEqual(before, after)
        self.assertIn("9.9.9", result.stdout)

    def test_updates_version_and_all_four_hashes(self):
        self._install_gh_stub("1.6.0")
        expected_hashes = {
            "linux_x64": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
            "linux_arm64": "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
            "mac_x64": "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=",
            "mac_arm64": "sha256-DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=",
        }
        self._install_nix_stub(expected_hashes)

        result = self._run_update()
        self.assertEqual(result.returncode, 0, msg=result.stderr)

        updated = (self.work / "package.nix").read_text(encoding="utf-8")
        self.assertIn('version = "1.6.0";', updated)
        self.assertIn(f'x86_64-linux = "{expected_hashes["linux_x64"]}";', updated)
        self.assertIn(f'aarch64-linux = "{expected_hashes["linux_arm64"]}";', updated)
        self.assertIn(f'x86_64-darwin = "{expected_hashes["mac_x64"]}";', updated)
        self.assertIn(f'aarch64-darwin = "{expected_hashes["mac_arm64"]}";', updated)

        calls = self.state_file.read_text(encoding="utf-8").splitlines()
        self.assertIn("build .#antigravity-cli --no-link", calls)
        self.assertIn("flake update", calls)

    def test_prefetch_failure_leaves_package_unchanged(self):
        self._install_gh_stub("1.6.0")
        self._install_nix_stub(
            {"linux_x64": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="},
            fail_on="linux_arm64",
        )

        before = (self.work / "package.nix").read_text(encoding="utf-8")
        result = self._run_update("--version", "1.6.0")
        after = (self.work / "package.nix").read_text(encoding="utf-8")

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(before, after)
        calls = self.state_file.read_text(encoding="utf-8").splitlines()
        self.assertNotIn("build .#antigravity-cli --no-link", calls)

    def test_build_failure_restores_package_nix(self):
        self._install_gh_stub("1.6.0")
        self._install_nix_stub(
            {
                "linux_x64": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
                "linux_arm64": "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",
                "mac_x64": "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=",
                "mac_arm64": "sha256-DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=",
            },
            fail_build=True,
        )

        before = (self.work / "package.nix").read_text(encoding="utf-8")
        result = self._run_update("--version", "1.6.0")
        after = (self.work / "package.nix").read_text(encoding="utf-8")

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(before, after)
        calls = self.state_file.read_text(encoding="utf-8").splitlines()
        self.assertIn("build .#antigravity-cli --no-link", calls)

    def _read_version(self) -> str:
        for line in (self.work / "package.nix").read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if stripped.startswith('version = "') and stripped.endswith('";'):
                return stripped.split('"')[1]
        self.fail("Could not find version in package.nix")

    def _install_gh_stub(self, tag: str) -> None:
        bash_bin = shutil.which("bash") or "/usr/bin/env bash"
        self._write_stub(
            "gh",
            f"""\
            #!{bash_bin}
            printf '%s\\n' "{tag}"
            """,
        )

    def _install_nix_stub(self, hashes: dict, fail_on: str = "", fail_build: bool = False) -> None:
        python_bin = shutil.which("python3") or "/usr/bin/env python3"
        hashes_json = json.dumps(hashes)
        fail_build_flag = "1" if fail_build else "0"
        self._write_stub(
            "nix",
            f"""\
            #!{python_bin}
            import json
            import os
            import sys

            log_path = os.environ["STUB_LOG"]
            with open(log_path, "a", encoding="utf-8") as fh:
                fh.write(" ".join(sys.argv[1:]) + "\\n")

            args = sys.argv[1:]
            hashes = json.loads({hashes_json!r})
            fail_on = {fail_on!r}
            fail_build = {fail_build_flag!r} == "1"

            if args[:2] == ["store", "prefetch-file"]:
                url = args[-1]
                if fail_on and fail_on in url:
                    sys.exit(1)
                for key, value in hashes.items():
                    if f"agy_cli_{{key}}.tar.gz" in url:
                        print(json.dumps({{"hash": value}}))
                        sys.exit(0)
                sys.exit(1)
            if args and args[0] == "build":
                sys.exit(1 if fail_build else 0)
            if args[:2] == ["flake", "update"]:
                sys.exit(0)
            sys.exit(1)
            """,
        )


if __name__ == "__main__":
    unittest.main()
