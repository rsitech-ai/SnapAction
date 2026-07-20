# Releasing

The owner has authorized a private `rsitech-ai` prerelease of the unofficial community bundle. Public release, public visibility, redistribution, official product identity, Developer ID signing, notarization, and App Store publication remain unauthorized and blocked. This document is not a grant of maintainer, signing, or legal authority.

## Private preview procedure

1. Start from the reviewed and merged `main` commit.
2. Run every repository check, including `bash script/test_release_package.sh`.
3. Run `bash script/package_release.sh --output <clean-directory>`.
4. Verify the generated SHA-256 sidecar, archive contents, embedded source revision, and ad-hoc signature.
5. Tag the exact verified commit as `v0.1.0` and publish a private GitHub prerelease containing the ZIP, checksum, and source SBOM.
6. Download the published assets again and repeat checksum, extraction, metadata, and signature verification.

The private preview is intentionally ad-hoc signed and not notarized. Release notes and download instructions must state that macOS may show an unidentified-developer warning. Access to a private repository release is limited to GitHub users who can read the repository.

## Public or official release gates

Before any public, redistributable, or official source or binary release:

1. Obtain and record owner/legal approval for the license, contributor-certificate model, naming, trademark use, and governance.
2. Adopt the approved root license and update the generated evidence. No license is selected today.
3. Establish and test an approved private security-reporting channel.
4. Resolve the recorded owner request to skip the formal security scan: either complete and review a scan or explicitly accept the publication risk through the project’s approval process.
5. Resolve the reachable-history workstation-reference decision. History rewriting requires separate explicit authorization and coordination.
6. Run every command in `docs/open-source/PUBLICATION_GATE_MATRIX.md` and require the publication checker to pass.
7. For binaries, follow `docs/release/MAC_APP_STORE_RELEASE_PLAYBOOK.md`; prove signing, sandboxing, entitlements, notarization or App Store validation, permission behavior, and clean-machine installation.
8. Obtain explicit authority before changing visibility, publishing public releases, uploading official binaries, or announcing the project.

The community build is unofficial by default. Official product identity, Team IDs, certificates, notarization credentials, App Store credentials, and private endpoints must remain outside Git.
