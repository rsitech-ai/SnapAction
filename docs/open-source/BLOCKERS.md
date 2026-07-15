# Publication blockers

The machine-readable blocker codes are stable identifiers emitted by `script/check_publication_gates.py`:

- `LICENSE_APPROVAL_REQUIRED`
- `ROOT_LICENSE_MISSING`
- `DCO_DECISION_REQUIRED`
- `TRADEMARK_DECISION_REQUIRED`
- `GOVERNANCE_APPROVAL_REQUIRED`
- `SECURITY_CONTACT_REQUIRED`
- `FORMAL_SECURITY_SCAN_DEFERRED`
- `CURRENT_TREE_PERSONAL_PATH_REVIEW_REQUIRED`
- `REACHABLE_HISTORY_EXPOSURE_DECISION_REQUIRED`

These are not implementation failures. They are explicit legal, owner, security, current-tree, or history gates that this local hardening branch is not authorized to resolve unilaterally.
