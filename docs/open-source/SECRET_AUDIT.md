# Secret audit

## Current scan (2026-07-20)

Tool: **Gitleaks 8.30.1** (`gitleaks detect --no-git` on the working tree; `gitleaks git` on reachable history).

Result: **no confirmed credentials**. Gitleaks reported `generic-api-key` hits that are SHA-256 content hashes inside `docs/open-source/OPEN_SOURCE_MANIFEST.json` (`evidence_inputs` file digests). Those digests are integrity evidence, not secrets. Fingerprints are listed in `.gitleaksignore`.

Scope covered:

- current working tree (excluding ignored build products);
- all commits reachable from published `main` / release tags after the authorized history rewrite.

Scope not covered / residual risk:

- unavailable or deleted refs outside the published rewrite;
- external systems, Keychain items, notarization credentials, and local unsigned env files;
- the formal Codex Security scan, which remains skipped by explicit owner direction (accepted residual risk, not a pass).

## Historical observation

An earlier manual review mapped to published rewritten base commit `ed49cf7f3a7ebe4fc8502d9b6462a9193663ff2c` found **no confirmed credential at that audited base** in its tree and history reachable at the time.

If a real credential is later validated, treat it as compromised and rotate it. Evidence generators do not read arbitrary environment variables, do not emit environment values, and never record suspected secret values. Local signing material and official identity configuration remain ignored by Git.
