# Changelog

All notable repository changes are recorded here.

## 0.1.0 - 2026-07-20

- Added a deterministic, versioned macOS ZIP packager with source-revision metadata and SHA-256 verification.
- Added CI enforcement for the release-package verification path and updated the pinned checkout action to reviewed version 7.0.1.
- Documented private-preview installation, privacy behavior, and the explicit ad-hoc-signing/notarization boundary.
- Moved the private repository to the `rsitech-ai` organization and removed obsolete internal planning, audit, and reflection artifacts from the current tree.

## Unreleased

- Minimized persisted history to non-sensitive action summaries with configurable expiration and clear controls.
- Added final action revalidation before external writes and bounded operational error copy.
- Added seven-day clipboard-cache expiration, owner-only storage permissions, and a clear-cache control.
- Added safe unofficial community bundle identity and validated build metadata.
- Added deterministic publication evidence, source SBOM generation, fail-closed gates, and repository policy checks.
- Added least-privilege CI with immutable action pinning and deterministic repository-policy checks.
- Recorded code scanning, dependency review, and license adoption as publication gates instead of adding workflows that would fail or run without owner approval.

The `0.1.0` entry describes a private prerelease, not a public or redistributable release.
