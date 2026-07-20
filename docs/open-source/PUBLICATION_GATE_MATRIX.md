# Publication gate matrix

| Gate | Scope | State | Required resolution |
| --- | --- | --- | --- |
| License approval and root license | Legal/current tree | Blocked | Owner/legal selects a license and its text is adopted. No license is selected. |
| Contributor certificate | Legal | Blocked | Owner/legal decides whether to adopt a DCO or another model. |
| Trademark/naming | Legal | Blocked | Owner/legal records naming and redistribution permissions. |
| Governance | Owner | Blocked | Owner records maintainer, contribution, release, and enforcement authority. |
| Security contact | Owner/security | Blocked | Owner approves a public reporting route and private intake owner. |
| Formal Codex Security scan | Security | Skipped by owner request/blocking | Complete and review a scan, or record explicit publication-risk acceptance through the project’s approval process. |
| Current-tree personal paths | Current tree | Clear | Tracked text contains no workstation-specific absolute home-directory paths; keep the policy check green. |
| Reachable-history exposure | Git history | Blocked | Approve disclosure or separately authorize a coordinated history rewrite. |
| Community build identity | Community build | Configured | Keep the unofficial defaults and validate any override. |
| External Swift dependencies | Current tree | Clear | `Package.swift` declares zero external packages; rerun the generator after dependency changes. |

`python3 script/check_publication_gates.py` is intentionally expected to exit 1 while any blocking row is unresolved.
