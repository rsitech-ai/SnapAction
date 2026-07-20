# Secret audit

An earlier manual review mapped to published rewritten base commit `ed49cf7f3a7ebe4fc8502d9b6462a9193663ff2c` found **no confirmed credential at that audited base** in its tree and history reachable at the time. This historical observation predates the rewrite and is not a conclusion about the current branch or its current reachable history.

The current repository and reachable history are **NOT FORMALLY SCANNED**. The historical observation does not cover later commits, unavailable refs, or external systems and does not remove the need to rotate a credential if one is later validated.

The owner explicitly requested publication without the formal Codex Security scan and accepted the residual risk on 2026-07-20. That omission is disclosed and is not converted into a passing scan result.

The evidence generators do not read arbitrary environment variables, do not emit environment values, and never record suspected secret values. Local signing material and official identity configuration remain ignored by Git.
