# Publication GO/NO-GO

Verdict: **GO for public prerelease `v0.1.0`**, with notarization remaining an external blocker for Gatekeeper-clean distribution.

| Area | Status | Evidence / remaining action |
| --- | --- | --- |
| Core build and tests | PASS | Swift, tooling, bundle, package, and policy checks pass locally and on hosted CI for the release commit. |
| Runtime privacy | PASS | Metadata-only history, expiry/clear controls, owner-only persistence, and final write revalidation. |
| License and attribution | PASS | Apache-2.0 `LICENSE`; Rafal Sikora / RSI Tech `NOTICE`. |
| Contribution/governance/trademark | PASS | DCO, RSI Tech authority, and naming boundary documented. |
| Security intake | PASS | Private advisory route and `info@rsitech.ai`. |
| Formal Codex Security scan | ACCEPTED RISK | Explicitly skipped by owner; do not claim a pass. |
| Credential scan (Gitleaks 8.30.1) | PASS | Tree and reachable history scanned; only false-positive content digests in the open-source manifest. |
| Current tree paths | PASS | Repository policy reports none. |
| Published history | PASS | Live `main` history uses the approved maintainer/GitHub service noreply identities and contains no workstation path. |
| Direct-download signing | PASS | `Developer ID Application: Rafal Sikora (2NY8A789TN)` with hardened runtime on the published arm64 archive. |
| Notarization | EXTERNAL | No notarytool credentials/profile available; Gatekeeper reports `Unnotarized Developer ID`. |
| GitHub hosted CI | PASS | Required `build-and-test` check is green on `main` for the release commit. |
