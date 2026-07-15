import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_GENERATOR = REPO_ROOT / "script" / "generate_open_source_manifest.py"
SBOM_GENERATOR = REPO_ROOT / "script" / "generate_sbom.py"
GATE_CHECKER = REPO_ROOT / "script" / "check_publication_gates.py"
COMMITTED_MANIFEST = REPO_ROOT / "docs" / "open-source" / "OPEN_SOURCE_MANIFEST.json"
COMMITTED_SBOM = REPO_ROOT / "artifacts" / "sbom" / "snapaction.cdx.json"


class PublicationToolTests(unittest.TestCase):
    maxDiff = None

    def run_tool(self, script: Path, *arguments: object, cwd: Path | str = "/", env=None):
        command = [sys.executable, str(script), *(str(argument) for argument in arguments)]
        return subprocess.run(
            command,
            cwd=cwd,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    def generated_bytes(self, script: Path, cwd: Path | str):
        with tempfile.TemporaryDirectory() as temporary_directory:
            output = Path(temporary_directory) / "evidence.json"
            result = self.run_tool(script, "--output", output, cwd=cwd)
            self.assertEqual(result.returncode, 0, result.stderr)
            return output.read_bytes()

    def test_manifest_is_deterministic_cwd_independent_and_contains_no_environment_secret(self):
        secret = "do-not-copy-this-secret-value"
        environment = os.environ.copy()
        environment["SNAP_ACTION_TEST_SECRET"] = secret

        with tempfile.TemporaryDirectory() as first_directory, tempfile.TemporaryDirectory() as second_directory:
            first_output = Path(first_directory) / "manifest.json"
            second_output = Path(second_directory) / "manifest.json"
            first = self.run_tool(MANIFEST_GENERATOR, "--output", first_output, cwd="/", env=environment)
            second = self.run_tool(
                MANIFEST_GENERATOR,
                "--output",
                second_output,
                cwd=REPO_ROOT / "Sources",
                env=environment,
            )

            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(first_output.read_bytes(), second_output.read_bytes())
            self.assertNotIn(secret.encode(), first_output.read_bytes())

    def test_manifest_records_truthful_fail_closed_release_state(self):
        manifest = json.loads(self.generated_bytes(MANIFEST_GENERATOR, cwd="/"))

        self.assertEqual(manifest["publication"]["status"], "BLOCKED")
        self.assertEqual(manifest["application"]["platform"], "macOS")
        self.assertEqual(manifest["application"]["build_system"], "Swift Package Manager")
        self.assertEqual(manifest["licensing"]["proposed_spdx_id"], "MPL-2.0")
        self.assertIsNone(manifest["licensing"]["approved_spdx_id"])
        self.assertEqual(manifest["dependencies"]["external_swift_packages"], [])
        self.assertEqual(manifest["dependencies"]["external_swift_package_count"], 0)
        self.assertEqual(manifest["security"]["formal_codex_security_scan"]["status"], "DEFERRED")
        self.assertFalse(manifest["security"]["formal_codex_security_scan"]["completed"])
        credential_review = manifest["security"]["credential_review"]
        self.assertEqual(credential_review["current_repository_status"], "UNVERIFIED")
        self.assertEqual(
            credential_review["current_reachable_history_status"],
            "NOT_FORMALLY_SCANNED",
        )
        self.assertFalse(credential_review["formal_scan_coverage"])
        self.assertEqual(
            credential_review["historical_observation"]["anchor_commit"],
            "e1f7c0a3c555e941241f710b53bb61dc04e189c3",
        )
        self.assertEqual(
            credential_review["historical_observation"]["conclusion"],
            "NO_CONFIRMED_CREDENTIAL_AT_AUDITED_BASE",
        )
        self.assertNotIn("CURRENT", credential_review["historical_observation"]["conclusion"])
        self.assertNotIn("toolchain", manifest)
        self.assertEqual(
            manifest["source_manifest"],
            {
                "swiftpm_tools_version": "6.2",
                "meaning": "source-declared SwiftPM manifest compatibility requirement; not installed toolchain evidence",
            },
        )
        self.assertIn("current_tree", manifest["evidence_scopes"])
        self.assertIn("reachable_history", manifest["evidence_scopes"])
        self.assertIn("community_build", manifest["evidence_scopes"])
        self.assertIn("external_manual_gates", manifest["evidence_scopes"])
        self.assertEqual(manifest["verification_commands"], sorted(manifest["verification_commands"]))
        self.assertEqual(list(manifest["evidence_inputs"]), sorted(manifest["evidence_inputs"]))
        for tooling_input in (
            "script/check_publication_gates.py",
            "script/generate_open_source_manifest.py",
            "script/generate_sbom.py",
            "script/publication_evidence.py",
        ):
            self.assertIn(tooling_input, manifest["evidence_inputs"])

    def test_sbom_distinguishes_internal_targets_apple_frameworks_and_external_packages(self):
        sbom = json.loads(self.generated_bytes(SBOM_GENERATOR, cwd=REPO_ROOT / "Tests"))

        self.assertEqual(sbom["bomFormat"], "CycloneDX")
        self.assertEqual(sbom["specVersion"], "1.6")
        self.assertEqual(sbom["metadata"]["component"]["name"], "SnapAction")
        self.assertEqual(sbom["metadata"]["component"]["properties"], [
            {"name": "snapaction.build-system", "value": "Swift Package Manager"},
            {"name": "snapaction.platform", "value": "macOS"},
        ])
        components = {component["bom-ref"]: component for component in sbom["components"]}
        self.assertIn("internal:SnapActionApp", components)
        self.assertIn("internal:SnapActionCore", components)
        self.assertIn("apple-framework:AppKit", components)
        self.assertEqual(
            components["apple-framework:AppKit"]["properties"],
            [
                {"name": "snapaction.relationship", "value": "provided-by-platform"},
                {"name": "snapaction.redistributed", "value": "false"},
            ],
        )
        self.assertEqual(
            sbom["properties"],
            [
                {"name": "snapaction.external-swift-package-count", "value": "0"},
                {"name": "snapaction.swiftpm-manifest-tools-version", "value": "6.2"},
            ],
        )
        self.assertFalse(any(component["bom-ref"].startswith("swift-package:") for component in sbom["components"]))
        self.assertNotIn("tools", sbom["metadata"])
        self.assertNotIn("installed toolchain", json.dumps(sbom).lower())

    def test_gate_checker_fails_closed_with_precise_unresolved_blockers(self):
        result = self.run_tool(GATE_CHECKER, cwd=REPO_ROOT / "Sources")

        self.assertEqual(result.returncode, 1)
        self.assertIn("Publication gates: BLOCKED", result.stdout)
        expected_blockers = {
            "LICENSE_APPROVAL_REQUIRED",
            "ROOT_LICENSE_MISSING",
            "DCO_DECISION_REQUIRED",
            "TRADEMARK_DECISION_REQUIRED",
            "GOVERNANCE_APPROVAL_REQUIRED",
            "SECURITY_CONTACT_REQUIRED",
            "FORMAL_SECURITY_SCAN_DEFERRED",
            "CURRENT_TREE_PERSONAL_PATH_REVIEW_REQUIRED",
            "REACHABLE_HISTORY_EXPOSURE_DECISION_REQUIRED",
        }
        reported = {
            line.split(":", 1)[0].removeprefix("- ")
            for line in result.stdout.splitlines()
            if line.startswith("- ")
        }
        self.assertEqual(reported, expected_blockers)

    def test_repository_evidence_blockers_clear_only_when_their_evidence_is_clean(self):
        sys.path.insert(0, str(REPO_ROOT / "script"))
        try:
            from publication_evidence import publication_blockers
        finally:
            sys.path.pop(0)

        clean_codes = {blocker["code"] for blocker in publication_blockers([], False)}
        exposed_codes = {
            blocker["code"]
            for blocker in publication_blockers(["docs/example.md"], True)
        }
        licensed_codes = {
            blocker["code"]
            for blocker in publication_blockers([], False, root_license_present=True)
        }
        evidence_codes = {
            "CURRENT_TREE_PERSONAL_PATH_REVIEW_REQUIRED",
            "REACHABLE_HISTORY_EXPOSURE_DECISION_REQUIRED",
        }
        self.assertTrue(evidence_codes.isdisjoint(clean_codes))
        self.assertTrue(evidence_codes.issubset(exposed_codes))
        self.assertNotIn("ROOT_LICENSE_MISSING", licensed_codes)

    def test_committed_generated_files_match_fresh_generation(self):
        self.assertEqual(COMMITTED_MANIFEST.read_bytes(), self.generated_bytes(MANIFEST_GENERATOR, cwd="/"))
        self.assertEqual(COMMITTED_SBOM.read_bytes(), self.generated_bytes(SBOM_GENERATOR, cwd="/"))


if __name__ == "__main__":
    unittest.main()
