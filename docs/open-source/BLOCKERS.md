# Publication gates

Owner-controlled legal, brand, governance, contribution, security-contact, and history-rewrite decisions were resolved on 2026-07-20.

The publication checker remains fail-closed for repository-derived regressions:

- missing or non-canonical Apache-2.0 root license;
- tracked workstation paths in the current tree;
- workstation paths in the published `HEAD` history;
- personal author or committer email that differs from `24563931+s1korrrr@users.noreply.github.com`; GitHub and Dependabot provider noreply identities remain allowed.

External residual items that are not converted into a false pass:

- Apple notarization credentials are unavailable; Gatekeeper rejects the direct-download prerelease as `Unnotarized Developer ID`.
- The formal Codex Security scan was skipped by explicit owner direction and remains accepted residual risk.

Gitleaks 8.30.1 completed over the current tree and reachable published history with no confirmed credentials (false-positive content digests only).
