# Public/private boundary

| Scope | Intended public content | Excluded or unresolved content |
| --- | --- | --- |
| Current tree | Source, tests, community build configuration, documentation, generated evidence | Local signing credentials and official identity files are ignored; workstation-specific absolute paths have been removed from tracked text. |
| Reachable history | Only history the owner explicitly approves for disclosure | Existing personal/workstation references require an exposure decision or authorized rewrite. |
| Community build | Unofficial `SnapAction Community` identity using `org.example.snapaction.community` by default | Official bundle identity, signing identity, App Store credentials, and production release authority. |
| External/manual gates | Repository records the unresolved state | Legal approval, trademark permission, governance authority, security intake ownership, formal scan approval, repository visibility, and publication actions remain outside this branch's authority. |

No secret value should ever be added to an inventory, generated artifact, issue, log, or commit.
