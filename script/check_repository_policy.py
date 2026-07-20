#!/usr/bin/env python3
"""Validate repository safeguards without third-party Python dependencies."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re

from publication_evidence import build_manifest


REPO_ROOT = Path(__file__).resolve().parents[1]
FULL_SHA = re.compile(r"^[0-9a-f]{40}$")
ACTION_USE = re.compile(
    r"^\s*(?:-\s+)?uses:\s+([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*)@([^\s#]+)(?:\s+#\s*(.+))?\s*$"
)
ANY_ACTION_USE = re.compile(r"^\s*(?:-\s+)?uses:\s+(.+?)\s*$")

VERIFIED_ACTION_REVISIONS = {
    "actions/checkout": "3d3c42e5aac5ba805825da76410c181273ba90b1",  # v7.0.1
    "actions/dependency-review-action": "a1d282b36b6f3519aa1f3fc636f609c47dddb294",  # v5.0.0
    "github/codeql-action": "99df26d4f13ea111d4ec1a7dddef6063f76b97e9",  # v4.37.0
}

CI_REQUIRED_COMMANDS = (
    "swift test",
    "swift build -c release -Xswiftc -warnings-as-errors",
    "bash script/test_build_configuration.sh",
    "bash script/test_bundle_metadata.sh",
    "bash script/test_release_package.sh",
    "python3 -m unittest discover -s Tests/ToolingTests -v",
    "python3 script/check_repository_policy.py",
)

REQUIRED_DOCUMENTS = (
    ".editorconfig",
    ".gitattributes",
    ".github/ISSUE_TEMPLATE/bug.yml",
    ".github/ISSUE_TEMPLATE/config.yml",
    ".github/ISSUE_TEMPLATE/feature.yml",
    ".github/dependabot.yml",
    ".github/pull_request_template.md",
    "CHANGELOG.md",
    "Config/Community.example.env",
    "CONTRIBUTING.md",
    "PRIVACY.md",
    "README.md",
    "RELEASING.md",
    "ROADMAP.md",
    "SECURITY.md",
    "SUPPORT.md",
    "docs/build/README.md",
    "docs/community-build/README.md",
    "docs/open-source/BLOCKERS.md",
    "docs/open-source/COMMUNITY_BUILD.md",
    "docs/open-source/GOVERNANCE_REVIEW.md",
    "docs/open-source/GITHUB_CONFIGURATION.md",
    "docs/open-source/GO_NO_GO.md",
    "docs/open-source/IP_INVENTORY.md",
    "docs/open-source/LICENSE_MAP.md",
    "docs/open-source/OPEN_SOURCE_MANIFEST.json",
    "docs/open-source/OPEN_SOURCE_STATUS.md",
    "docs/open-source/PUBLICATION_GATE_MATRIX.md",
    "docs/open-source/PUBLIC_PRIVATE_BOUNDARY.md",
    "docs/open-source/PROFILE_PROPOSAL.md",
    "docs/open-source/SECRET_AUDIT.md",
    "docs/open-source/SECURITY_READINESS.md",
    "docs/open-source/SUPPLY_CHAIN_READINESS.md",
    "docs/open-source/THIRD_PARTY_INVENTORY.md",
    "docs/open-source/TRADEMARK_REVIEW.md",
    "docs/release/MAC_APP_STORE_RELEASE_PLAYBOOK.md",
    "docs/release/0.1.0.md",
    "artifacts/sbom/snapaction.cdx.json",
    "script/package_release.sh",
    "script/test_release_package.sh",
)

REQUIRED_WORKFLOW_TRIGGERS = {
    "ci.yml": ("push", "pull_request"),
}

REQUIRED_SECRET_IGNORES = (
    "Config/Official.local.env",
    "Signing/",
    "*.env",
    "*.local.env",
    ".env",
    ".env.*",
    "!Config/Community.example.env",
    "*.key",
    "*.pem",
    "*.p8",
    "*.p12",
    "*.pfx",
    "*.cer",
    "AuthKey_*.p8",
    "*.mobileprovision",
    "*.provisionprofile",
    ".codex/",
)


@dataclass(frozen=True)
class PolicyIssue:
    code: str
    path: str
    detail: str


def _top_level_permissions(content: str) -> list[str] | None:
    lines = content.splitlines()
    for index, line in enumerate(lines):
        if line == "permissions:":
            values: list[str] = []
            for nested in lines[index + 1 :]:
                if nested and not nested.startswith((" ", "\t")):
                    break
                if nested.startswith("  ") and not nested.startswith("    "):
                    values.append(nested.strip())
            return values
    return None


def _declared_triggers(content: str) -> set[str]:
    lines = content.splitlines()
    for index, line in enumerate(lines):
        inline = re.fullmatch(r"on:\s*\[([^]]*)\]\s*", line)
        if inline:
            return {
                trigger.strip().strip("'\"")
                for trigger in inline.group(1).split(",")
                if trigger.strip()
            }
        scalar = re.fullmatch(r"on:\s*([A-Za-z_]+)\s*", line)
        if scalar:
            return {scalar.group(1)}
        if line == "on:":
            triggers: set[str] = set()
            for nested in lines[index + 1 :]:
                if nested and not nested.startswith((" ", "\t")):
                    break
                match = re.match(r"^  ([A-Za-z_]+):", nested)
                if match:
                    triggers.add(match.group(1))
            return triggers
    return set()


def _job_permission_issues(relative_path: str, content: str) -> list[PolicyIssue]:
    issues: list[PolicyIssue] = []
    lines = content.splitlines()

    def containing_job_content(line_index: int) -> str:
        job_start: int | None = None
        for candidate in range(line_index - 1, -1, -1):
            if re.fullmatch(r"  [A-Za-z0-9_.-]+:\s*", lines[candidate]):
                job_start = candidate
                break
        if job_start is None:
            return ""
        job_end = len(lines)
        for candidate in range(job_start + 1, len(lines)):
            nested = lines[candidate]
            if nested.strip() and len(nested) - len(nested.lstrip()) <= 2:
                job_end = candidate
                break
        return "\n".join(lines[job_start:job_end])

    for index, line in enumerate(lines):
        block = re.fullmatch(r"(\s+)permissions:\s*", line)
        inline = re.fullmatch(r"(\s+)permissions:\s*\{([^}]*)\}\s*", line)
        scalar = re.fullmatch(r"(\s+)permissions:\s*(read-all|write-all|\{\})\s*", line)
        if not (block or inline or scalar):
            continue
        indent = len((block or inline or scalar).group(1))
        if indent == 0:
            continue

        permissions: list[tuple[str, str]] = []
        if inline:
            for entry in inline.group(2).split(","):
                if ":" in entry:
                    key, value = entry.split(":", 1)
                    permissions.append((key.strip(), value.strip()))
        elif scalar:
            permissions.append(("*", scalar.group(2)))
        else:
            for nested in lines[index + 1 :]:
                if nested.strip() and len(nested) - len(nested.lstrip()) <= indent:
                    break
                match = re.fullmatch(r"\s+([A-Za-z-]+):\s*([A-Za-z-]+)\s*", nested)
                if match:
                    permissions.append((match.group(1), match.group(2)))

        job_content = containing_job_content(index)
        approved_codeql_analyze = any(
            match is not None
            and match.group(1) == "github/codeql-action/analyze"
            and match.group(2) == VERIFIED_ACTION_REVISIONS["github/codeql-action"]
            for match in (ACTION_USE.match(job_line) for job_line in job_content.splitlines())
        )
        for scope, access in permissions:
            if access == "write" and scope == "security-events" and approved_codeql_analyze:
                continue
            if access in {"write", "write-all"}:
                issues.append(
                    PolicyIssue(
                        "JOB_WRITE_PERMISSION_FORBIDDEN",
                        relative_path,
                        f"job-level permission {scope}: {access} is not an approved least-privilege exception",
                    )
                )
    return issues


def workflow_policy_issues(path: Path, content: str) -> list[PolicyIssue]:
    relative_path = path.as_posix()
    issues: list[PolicyIssue] = []

    if re.search(r"(?m)^\s*pull_request_target\s*:", content):
        issues.append(
            PolicyIssue(
                "FORBIDDEN_PULL_REQUEST_TARGET",
                relative_path,
                "pull_request_target is forbidden for this repository",
            )
        )

    permissions = _top_level_permissions(content)
    if permissions != ["contents: read"]:
        issues.append(
            PolicyIssue(
                "NON_READ_DEFAULT_PERMISSIONS",
                relative_path,
                "top-level permissions must be exactly contents: read",
            )
        )

    issues.extend(_job_permission_issues(relative_path, content))

    action_occurrences: list[tuple[str, int]] = []
    for line_number, line in enumerate(content.splitlines(), start=1):
        any_use = ANY_ACTION_USE.match(line)
        match = ACTION_USE.match(line)
        if any_use and not match:
            reference = any_use.group(1).strip('"\'')
            if not reference.startswith("./"):
                issues.append(
                    PolicyIssue(
                        "ACTION_REFERENCE_UNPARSEABLE",
                        relative_path,
                        f"line {line_number}: external action reference must use unquoted owner/repository@revision form",
                    )
                )
            continue
        if not match:
            continue
        action, revision, version_comment = match.groups()
        action_occurrences.append(("/".join(action.split("/")[:2]), line_number))
        if not FULL_SHA.fullmatch(revision):
            issues.append(
                PolicyIssue(
                    "ACTION_NOT_PINNED",
                    relative_path,
                    f"line {line_number}: {action} is not pinned to a full commit SHA",
                )
            )
        action_repository = "/".join(action.split("/")[:2])
        expected_revision = VERIFIED_ACTION_REVISIONS.get(action_repository)
        if expected_revision is None or revision != expected_revision:
            issues.append(
                PolicyIssue(
                    "ACTION_REVISION_NOT_VERIFIED",
                    relative_path,
                    f"line {line_number}: {action} is not pinned to the repository-reviewed revision",
                )
            )
        if not version_comment or not re.search(r"\bv?\d+(?:\.\d+){1,2}\b", version_comment):
            issues.append(
                PolicyIssue(
                    "ACTION_VERSION_COMMENT_MISSING",
                    relative_path,
                    f"line {line_number}: {action} is missing a human-readable version comment",
                )
            )

    dependency_review_lines = [
        line_number
        for action, line_number in action_occurrences
        if action == "actions/dependency-review-action"
    ]
    checkout_lines = [
        line_number
        for action, line_number in action_occurrences
        if action == "actions/checkout"
    ]
    if dependency_review_lines and not any(
        checkout_line < dependency_line
        for dependency_line in dependency_review_lines
        for checkout_line in checkout_lines
    ):
        issues.append(
            PolicyIssue(
                "DEPENDENCY_REVIEW_CHECKOUT_MISSING",
                relative_path,
                "dependency review must run after a pinned source checkout",
            )
        )

    triggers = _declared_triggers(content)
    if {"pull_request", "pull_request_target"} & triggers:
        secret_reference = re.search(r"\$\{\{\s*secrets\.", content, re.IGNORECASE)
        apple_credential = re.search(
            r"APPLE_(?:API|APP_STORE|ASC|CERT|SIGN|TEAM)|MATCH_PASSWORD|FASTLANE_SESSION",
            content,
            re.IGNORECASE,
        )
        if secret_reference or apple_credential:
            issues.append(
                PolicyIssue(
                    "PULL_REQUEST_SECRET_REFERENCE",
                    relative_path,
                    "pull-request workflows must not reference repository secrets or Apple credentials",
                )
            )

    return issues


def ci_semantic_issues(path: Path, content: str) -> list[PolicyIssue]:
    """Require CI to run the repository's release-critical verification commands."""
    return [
        PolicyIssue(
            "CI_REQUIRED_COMMAND_MISSING",
            path.as_posix(),
            f"CI must run: {command}",
        )
        for command in CI_REQUIRED_COMMANDS
        if command not in content
    ]


def repository_policy_issues(repo_root: Path = REPO_ROOT) -> list[PolicyIssue]:
    issues: list[PolicyIssue] = []
    workflows_directory = repo_root / ".github/workflows"

    for name, required_triggers in REQUIRED_WORKFLOW_TRIGGERS.items():
        path = workflows_directory / name
        if not path.is_file():
            issues.append(PolicyIssue("REQUIRED_WORKFLOW_MISSING", path.relative_to(repo_root).as_posix(), name))
            continue
        content = path.read_text(encoding="utf-8")
        issues.extend(workflow_policy_issues(path.relative_to(repo_root), content))
        if name == "ci.yml":
            issues.extend(ci_semantic_issues(path.relative_to(repo_root), content))
        missing_triggers = set(required_triggers) - _declared_triggers(content)
        if missing_triggers:
            issues.append(
                PolicyIssue(
                    "REQUIRED_TRIGGER_MISSING",
                    path.relative_to(repo_root).as_posix(),
                    ", ".join(sorted(missing_triggers)),
                )
            )

    for path in sorted(workflows_directory.glob("*.y*ml")):
        if path.name not in REQUIRED_WORKFLOW_TRIGGERS:
            issues.extend(workflow_policy_issues(path.relative_to(repo_root), path.read_text(encoding="utf-8")))

    for relative_path in REQUIRED_DOCUMENTS:
        if not (repo_root / relative_path).is_file():
            issues.append(PolicyIssue("REQUIRED_EVIDENCE_MISSING", relative_path, "required file is absent"))

    gitignore_path = repo_root / ".gitignore"
    gitignore_lines = {
        line.strip()
        for line in gitignore_path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }
    for pattern in REQUIRED_SECRET_IGNORES:
        if pattern not in gitignore_lines:
            issues.append(PolicyIssue("SECRET_IGNORE_MISSING", ".gitignore", pattern))

    contribution_path = repo_root / "CONTRIBUTING.md"
    if contribution_path.is_file():
        contribution = contribution_path.read_text(encoding="utf-8")
        if "External contributions are not yet accepted" not in contribution:
            issues.append(
                PolicyIssue(
                    "CONTRIBUTION_GATE_UNCLEAR",
                    "CONTRIBUTING.md",
                    "external contributions must be explicitly closed pending owner decisions",
                )
            )
        if "Signed-off-by:" in contribution or re.search(r"\b(?:DCO|CLA)\s+(?:is|has been)\s+adopted\b", contribution, re.IGNORECASE):
            issues.append(PolicyIssue("UNAPPROVED_CONTRIBUTOR_POLICY", "CONTRIBUTING.md", "DCO or CLA adoption is not approved"))

    issue_templates = list((repo_root / ".github/ISSUE_TEMPLATE").glob("*.yml"))
    for template in issue_templates:
        content = template.read_text(encoding="utf-8")
        if template.name != "config.yml" and "Do not report vulnerabilities in public issues" not in content:
            issues.append(
                PolicyIssue(
                    "VULNERABILITY_WARNING_MISSING",
                    template.relative_to(repo_root).as_posix(),
                    "public issue templates must warn against vulnerability disclosure",
                )
            )

    policy_documents = [repo_root / "CONTRIBUTING.md", repo_root / "SUPPORT.md", repo_root / "RELEASING.md"]
    placeholder_pattern = re.compile(r"(?:<[^>]*(?:email|contact)[^>]*>|TODO|TBD|security@example\.)", re.IGNORECASE)
    for path in policy_documents:
        if path.is_file() and placeholder_pattern.search(path.read_text(encoding="utf-8")):
            issues.append(
                PolicyIssue(
                    "POLICY_PLACEHOLDER_PRESENT",
                    path.relative_to(repo_root).as_posix(),
                    "policy documents must not present placeholders as adopted decisions",
                )
            )

    if not (repo_root / "LICENSE").exists() and not (repo_root / "LICENSE.md").exists() and not (repo_root / "LICENSE.txt").exists():
        license_map = (repo_root / "docs/open-source/LICENSE_MAP.md").read_text(encoding="utf-8")
        if "does not currently grant an open-source license" not in license_map:
            issues.append(PolicyIssue("MISSING_LICENSE_NOT_DISCLOSED", "docs/open-source/LICENSE_MAP.md", "missing root license must remain explicit"))

    return sorted(issues, key=lambda issue: (issue.code, issue.path, issue.detail))


def root_license_present(repo_root: Path = REPO_ROOT) -> bool:
    return any((repo_root / name).is_file() for name in ("LICENSE", "LICENSE.md", "LICENSE.txt"))


def license_gate_blockers(repo_root: Path = REPO_ROOT) -> list[str]:
    blockers: list[str] = []
    if not root_license_present(repo_root):
        blockers.append("ROOT_LICENSE_MISSING")
    approved_spdx_id = build_manifest()["licensing"]["approved_spdx_id"]
    if not approved_spdx_id:
        blockers.append("LICENSE_APPROVAL_REQUIRED")
    return blockers


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--license-gate",
        action="store_true",
        help="fail until an owner-approved root license is present",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    if arguments.license_gate:
        blockers = license_gate_blockers()
        if not blockers:
            print("License compliance: PASS")
            return 0
        print(
            f"License compliance: BLOCKED ({', '.join(blockers)}) - "
            "no owner-approved root license has been adopted and recorded."
        )
        return 1

    issues = repository_policy_issues()
    if issues:
        print("Repository policy: FAIL")
        for issue in issues:
            print(f"- {issue.code} [{issue.path}]: {issue.detail}")
        return 1
    print("Repository policy: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
