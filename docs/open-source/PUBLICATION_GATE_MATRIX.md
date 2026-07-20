# Publication gate matrix

| Gate | State | Evidence / rule |
| --- | --- | --- |
| License | Approved | Canonical Apache-2.0 `LICENSE`; copyright and attribution in `NOTICE`. |
| Contribution model | Approved | DCO 1.1 sign-off; Apache-2.0 inbound licensing in `CONTRIBUTING.md`. |
| Trademark/naming | Approved | RSI Tech public brand; Apache Section 6 boundary documented. |
| Governance | Approved | RSI Tech owns maintenance, contribution, release, conduct, and vulnerability-response decisions. |
| Security contact | Approved | GitHub private advisories and `info@rsitech.ai`. |
| Formal Codex Security scan | Skipped / risk accepted | Explicit owner direction; never represent as completed or passed. |
| Current-tree personal paths | Enforced | Repository policy must find none. |
| Published-history paths and email | Rewrite required before publication | `HEAD` must contain no workstation path and only the approved noreply author/committer email. |
| Community build identity | Configured | Local source build remains neutral and ad-hoc signed. |
| Official direct-download identity | Configured | `SnapAction`, `ai.rsitech.snapaction`, arm64, Developer ID Application team `2NY8A789TN`. |
| External Swift dependencies | Clear | `Package.swift` declares zero external packages. |

`python3 script/check_publication_gates.py` must pass on the exact rewritten publication commit. Separate binary gates must report signing, hardened runtime, notarization, and Gatekeeper truth.
