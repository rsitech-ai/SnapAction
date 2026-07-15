# Releasing

No public release or publication is currently authorized. This document is a gate checklist, not a grant of release, maintainer, signing, or legal authority.

Before any source or binary release:

1. Obtain and record owner/legal approval for the license, contributor-certificate model, naming, trademark use, and governance.
2. Adopt the approved root license and update the generated evidence; MPL-2.0 remains proposal-only until then.
3. Establish and test an approved private security-reporting channel.
4. Complete the deferred formal security scan, resolve accepted findings, and record the reviewed evidence.
5. Resolve the reachable-history workstation-reference decision. History rewriting requires separate explicit authorization and coordination.
6. Run every command in `docs/open-source/PUBLICATION_GATE_MATRIX.md` and require the publication checker to pass.
7. For binaries, follow `docs/release/MAC_APP_STORE_RELEASE_PLAYBOOK.md`; prove signing, sandboxing, entitlements, notarization or App Store validation, permission behavior, and clean-machine installation.
8. Obtain explicit authority before pushing tags, changing visibility, publishing releases, uploading binaries, or announcing the project.

The community build is unofficial by default. Official product identity, Team IDs, certificates, notarization credentials, App Store credentials, and private endpoints must remain outside Git.
