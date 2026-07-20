#!/usr/bin/env python3
"""Repository-derived facts shared by the publication evidence tools."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import subprocess
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = REPO_ROOT / "docs/open-source/OPEN_SOURCE_MANIFEST.json"
SBOM_PATH = REPO_ROOT / "artifacts/sbom/snapaction.cdx.json"
APACHE_2_LICENSE_SHA256 = "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30"
APPROVED_GIT_EMAIL = "24563931+s1korrrr@users.noreply.github.com"
ALLOWED_GITHUB_SERVICE_EMAILS = frozenset(
    {
        "49699333+dependabot[bot]@users.noreply.github.com",
        "noreply@github.com",
    }
)
ALLOWED_HISTORY_EMAILS = ALLOWED_GITHUB_SERVICE_EMAILS | {APPROVED_GIT_EMAIL}


def publication_blockers(
    personal_path_documents: list[str],
    history_has_personal_paths: bool,
    unexpected_history_emails: list[str] | None = None,
    apache_license_valid: bool = True,
) -> list[dict[str, str]]:
    blockers: list[dict[str, str]] = []
    if personal_path_documents:
        blockers.append(
            {
                "code": "CURRENT_TREE_PERSONAL_PATH_REVIEW_REQUIRED",
                "detail": "Tracked text contains workstation-specific absolute paths.",
                "gate": "owner",
                "scope": "current_tree",
            }
        )
    if history_has_personal_paths:
        blockers.append(
            {
                "code": "PUBLISHED_HISTORY_PATH_REWRITE_REQUIRED",
                "detail": "Published HEAD history still contains workstation-specific absolute paths.",
                "gate": "owner",
                "scope": "reachable_history",
            }
        )
    if unexpected_history_emails:
        blockers.append(
            {
                "code": "PUBLISHED_HISTORY_IDENTITY_REWRITE_REQUIRED",
                "detail": "Published HEAD history contains an author or committer email outside the approved personal noreply identity and allowed GitHub service identities.",
                "gate": "owner",
                "scope": "reachable_history",
            }
        )
    if not apache_license_valid:
        blockers.append(
            {
                "code": "APACHE_2_LICENSE_INVALID",
                "detail": "The root LICENSE does not match the canonical Apache License 2.0 text.",
                "gate": "legal",
                "scope": "current_tree",
            }
        )
    return sorted(blockers, key=lambda blocker: blocker["code"])


def canonical_json_bytes(document: dict[str, Any]) -> bytes:
    return (json.dumps(document, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")


def write_json(document: dict[str, Any], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(canonical_json_bytes(document))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_imports() -> list[str]:
    imports: set[str] = set()
    for path in sorted((REPO_ROOT / "Sources").rglob("*.swift")):
        for line in path.read_text(encoding="utf-8").splitlines():
            match = re.fullmatch(r"\s*import\s+([A-Za-z_][A-Za-z0-9_]*)\s*", line)
            if match:
                imports.add(match.group(1))
    return sorted(imports)


def internal_targets() -> list[str]:
    return sorted(path.name for path in (REPO_ROOT / "Sources").iterdir() if path.is_dir())


def external_swift_packages() -> list[str]:
    package = (REPO_ROOT / "Package.swift").read_text(encoding="utf-8")
    declarations = re.findall(r"\.package\s*\(", package)
    return ["UNPARSED_EXTERNAL_PACKAGE"] * len(declarations)


def swiftpm_manifest_tools_version() -> str:
    first_line = (REPO_ROOT / "Package.swift").read_text(encoding="utf-8").splitlines()[0]
    match = re.fullmatch(r"// swift-tools-version:\s*([0-9]+(?:\.[0-9]+)*)", first_line)
    if not match:
        raise ValueError("Package.swift does not declare a parseable SwiftPM manifest tools version")
    return match.group(1)


def application_version() -> str:
    example = (REPO_ROOT / "Config/Community.example.env").read_text(encoding="utf-8")
    match = re.search(r'^export SNAP_ACTION_VERSION="([0-9]+(?:\.[0-9]+){0,2})"$', example, re.MULTILINE)
    if not match:
        raise ValueError("Config/Community.example.env does not declare SNAP_ACTION_VERSION")
    return match.group(1)


def tracked_personal_path_documents() -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "ls-files", "-z"],
        check=True,
        capture_output=True,
    )
    affected: list[str] = []
    user_home_marker = "/" + "Users/"
    for raw_path in result.stdout.split(b"\0"):
        if not raw_path:
            continue
        relative_path = raw_path.decode("utf-8")
        path = REPO_ROOT / relative_path
        try:
            content = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        if user_home_marker in content:
            affected.append(relative_path)
    return sorted(affected)


def reachable_history_has_personal_paths() -> bool:
    user_home_marker = "/" + "Users/"
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "log", "HEAD", f"-S{user_home_marker}", "--format=%H"],
        check=True,
        capture_output=True,
        text=True,
    )
    return bool(result.stdout.strip())


def reachable_history_unapproved_emails() -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "log", "HEAD", "--format=%ae%n%ce"],
        check=True,
        capture_output=True,
        text=True,
    )
    return sorted(
        {
            email.strip()
            for email in result.stdout.splitlines()
            if email.strip() and email.strip() not in ALLOWED_HISTORY_EMAILS
        }
    )


def apache_2_license_valid(repo_root: Path = REPO_ROOT) -> bool:
    license_path = repo_root / "LICENSE"
    return license_path.is_file() and sha256(license_path) == APACHE_2_LICENSE_SHA256


def evidence_input_hashes() -> dict[str, str]:
    paths = [
        REPO_ROOT / "Package.swift",
        REPO_ROOT / "Config/Community.example.env",
        REPO_ROOT / "script/build_and_run.sh",
        REPO_ROOT / "script/check_publication_gates.py",
        REPO_ROOT / "script/check_repository_policy.py",
        REPO_ROOT / "script/generate_open_source_manifest.py",
        REPO_ROOT / "script/generate_sbom.py",
        REPO_ROOT / "script/package_release.sh",
        REPO_ROOT / "script/publication_evidence.py",
        REPO_ROOT / "script/test_release_package.sh",
        REPO_ROOT / "docs/build/README.md",
        REPO_ROOT / "docs/community-build/README.md",
        REPO_ROOT / "docs/release/0.1.0.md",
        REPO_ROOT / "docs/release/MAC_APP_STORE_RELEASE_PLAYBOOK.md",
        REPO_ROOT / ".editorconfig",
        REPO_ROOT / ".gitattributes",
        REPO_ROOT / ".gitleaksignore",
        REPO_ROOT / ".gitignore",
        REPO_ROOT / ".github/dependabot.yml",
        REPO_ROOT / "CHANGELOG.md",
        REPO_ROOT / "CONTRIBUTING.md",
        REPO_ROOT / "LICENSE",
        REPO_ROOT / "NOTICE",
        REPO_ROOT / "PRIVACY.md",
        REPO_ROOT / "README.md",
        REPO_ROOT / "RELEASING.md",
        REPO_ROOT / "ROADMAP.md",
        REPO_ROOT / "SECURITY.md",
        REPO_ROOT / "SUPPORT.md",
    ]
    github_configuration = REPO_ROOT / ".github"
    if github_configuration.exists():
        paths.extend(path for path in github_configuration.rglob("*") if path.is_file())
    open_source_docs = REPO_ROOT / "docs/open-source"
    if open_source_docs.exists():
        paths.extend(path for path in open_source_docs.glob("*.md") if path.is_file())
    paths.extend(path for path in (REPO_ROOT / "Sources").rglob("*.swift"))
    paths.extend(path for path in (REPO_ROOT / "Tests").rglob("*.swift"))
    return {
        path.relative_to(REPO_ROOT).as_posix(): sha256(path)
        for path in sorted(paths)
    }


def build_manifest() -> dict[str, Any]:
    external_packages = external_swift_packages()
    frameworks = [module for module in source_imports() if module not in internal_targets()]
    personal_path_documents = tracked_personal_path_documents()
    history_has_personal_paths = reachable_history_has_personal_paths()
    unexpected_history_emails = reachable_history_unapproved_emails()
    license_valid = apache_2_license_valid()
    blockers = publication_blockers(
        personal_path_documents,
        history_has_personal_paths,
        unexpected_history_emails,
        license_valid,
    )
    return {
        "application": {
            "build_system": "Swift Package Manager",
            "community_name": "SnapAction Community",
            "minimum_macos_version": "26.0",
            "name": "SnapAction",
            "platform": "macOS",
            "source_targets": internal_targets(),
            "version": application_version(),
        },
        "dependencies": {
            "apple_system_frameworks": frameworks,
            "external_swift_package_count": len(external_packages),
            "external_swift_packages": external_packages,
            "redistributed_third_party_packages": [],
        },
        "evidence_inputs": evidence_input_hashes(),
        "evidence_scopes": {
            "community_build": {
                "identity": "unofficial",
                "source": "Config/Community.example.env",
                "status": "CONFIGURED",
            },
            "current_tree": {
                "personal_path_documents": personal_path_documents,
                "personal_path_review_complete": not personal_path_documents,
                "status": "REVIEW_REQUIRED" if personal_path_documents else "REVIEWED",
            },
            "external_manual_gates": {
                "status": "APPROVED",
                "unresolved_count": 0,
            },
            "reachable_history": {
                "personal_path_exposure_detected": history_has_personal_paths,
                "approved_git_email": APPROVED_GIT_EMAIL,
                "allowed_github_service_emails": sorted(ALLOWED_GITHUB_SERVICE_EMAILS),
                "unexpected_emails": unexpected_history_emails,
                "owner_exposure_decision": "REWRITE_AUTHORIZED",
                "status": "REVIEW_REQUIRED" if history_has_personal_paths or unexpected_history_emails else "REVIEWED",
            },
        },
        "governance": {
            "copyright_owner": "Rafal Sikora",
            "maintainer": "RSI Tech",
            "project_contact": "info@rsitech.ai",
            "website": "https://rsitech.ai",
        },
        "licensing": {
            "approved_spdx_id": "Apache-2.0",
            "dco_adopted": True,
            "license_sha256": APACHE_2_LICENSE_SHA256,
            "root_license_present": (REPO_ROOT / "LICENSE").is_file(),
            "root_license_valid": license_valid,
        },
        "publication": {
            "blockers": blockers,
            "status": "BLOCKED" if blockers else "READY_WITH_ACCEPTED_RISK",
        },
        "schema_version": 2,
        "security": {
            "credential_review": {
                "current_reachable_history_status": "GITLEAKS_SCANNED_NO_CONFIRMED_CREDENTIAL",
                "current_repository_status": "GITLEAKS_SCANNED_NO_CONFIRMED_CREDENTIAL",
                "formal_scan_coverage": False,
                "gitleaks": {
                    "false_positive_class": "sha256_content_digests_in_open_source_manifest",
                    "scope": "working tree and reachable published history",
                    "status": "NO_CONFIRMED_CREDENTIAL",
                    "tool": "gitleaks",
                    "version": "8.30.1",
                },
                "historical_observation": {
                    "anchor_commit": "ed49cf7f3a7ebe4fc8502d9b6462a9193663ff2c",
                    "conclusion": "NO_CONFIRMED_CREDENTIAL_AT_AUDITED_BASE",
                    "method": "prior manual repository and reachable-history audit, mapped to the rewritten public base",
                    "scope": "tree and history reachable from the anchored base at the audit point",
                },
            },
            "formal_codex_security_scan": {
                "completed": False,
                "risk_accepted_by_owner": True,
                "risk_accepted_date": "2026-07-20",
                "status": "SKIPPED_BY_OWNER_ACCEPTED_RISK",
            },
            "security_contact": "info@rsitech.ai",
        },
        "source_manifest": {
            "meaning": "source-declared SwiftPM manifest compatibility requirement; not installed toolchain evidence",
            "swiftpm_tools_version": swiftpm_manifest_tools_version(),
        },
        "verification_commands": sorted(
            [
                "python3 -m json.tool artifacts/sbom/snapaction.cdx.json",
                "python3 -m json.tool docs/open-source/OPEN_SOURCE_MANIFEST.json",
                "python3 -m unittest discover -s Tests/ToolingTests -v",
                "python3 script/check_publication_gates.py",
                "python3 script/check_repository_policy.py",
                "python3 script/generate_open_source_manifest.py",
                "python3 script/generate_sbom.py",
                "bash script/test_release_package.sh",
                "swift build",
                "swift test",
            ]
        ),
    }
