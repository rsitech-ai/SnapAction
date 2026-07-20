# Mac App Store release playbook

## Current verdict

**Not submission-ready.** The repository builds a SwiftPM executable and stages an ad-hoc local `.app` bundle. It has no Xcode archive scheme, App Sandbox entitlements, distribution-signing configuration, notarization evidence, or App Store Connect packaging evidence. A successful community-bundle verification is not proof of those gates.

## Owner-controlled release gates

1. Approve product identity, legal terms, privacy disclosures, support destination, and distribution authority.
2. Add and review a distribution-capable macOS application target and archive scheme while preserving the tested SwiftPM core.
3. Define least-privilege App Sandbox entitlements and prove every feature in a sandboxed build.
4. Configure hardened runtime and Apple distribution signing without committing credentials or Team IDs.
5. Archive and inspect identity, versions, entitlements, architectures, purpose strings, signing chain, and source revision.
6. Validate the intended channel: App Store Connect for store distribution; Developer ID, notarization, stapling, and Gatekeeper for direct distribution.
7. Complete account-side metadata, privacy, export-compliance, review, availability, and release-control decisions.
8. Record the released commit, archive checksum, inputs, validation output, rollback path, and owner acceptance of remaining risk.

## Evidence required before changing the verdict

- Reviewed Xcode application target and archive scheme.
- Sandboxed runtime proof for every product feature.
- Hardened-runtime and distribution-signing verification.
- Archived-bundle inspection with approved identity and source revision.
- App Store validation/upload evidence from the owner-controlled account.
- Completed App Store Connect metadata and privacy decisions.
- Completed security review or explicit owner acceptance of its omission and resulting risk.

Until then, label output **community development bundle**, never “Mac App Store ready,” “notarized,” or “official.”
