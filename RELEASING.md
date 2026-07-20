# Releasing

RSI Tech maintains release authority for SnapAction. Public releases must come from a reviewed and merged `main` commit with a clean source tree.

## Direct-download procedure

1. Run every repository check, including `bash script/test_release_package.sh` and `python3 script/check_publication_gates.py`.
2. Confirm the exact local and remote `main` commit and a clean Git status.
3. Run `bash script/package_release.sh --output <clean-directory>`. The default release mode requires an `arm64` host and the installed `Developer ID Application: Rafal Sikora (2NY8A789TN)` identity.
4. Verify the SHA-256 sidecar, archive contents, `ai.rsitech.snapaction` identifier, release configuration, embedded source revision, arm64 binary, hardened runtime, and Developer ID authority/team.
5. Submit the archive for notarization and staple the result only when valid Apple notarization credentials are available. Never label an artifact notarized based on signing alone.
6. Tag the exact verified commit, publish the ZIP, checksum, and source SBOM, then download and verify every published asset again.

An ad-hoc signing mode exists only for deterministic packaging tests on clean source. It is not the official release channel.

## Authority and safety

- Source and first-party documentation are Apache-2.0; retain `LICENSE` and `NOTICE` in redistributions.
- Public maintenance, contribution, release, and security-response authority belongs to RSI Tech. Contact: [info@rsitech.ai](mailto:info@rsitech.ai).
- The Apache license does not grant RSI Tech or SnapAction trademark rights beyond customary origin descriptions.
- The initial formal Codex Security scan was explicitly skipped and accepted as residual risk by the owner. Release notes must not claim it passed.
- Signing private keys, notarization credentials, App Store Connect credentials, and private endpoints must remain outside Git and logs.
- The Mac App Store is a separate channel governed by `docs/release/MAC_APP_STORE_RELEASE_PLAYBOOK.md`.
