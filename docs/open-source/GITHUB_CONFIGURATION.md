# GitHub configuration handoff

Canonical public repository: `https://github.com/rsitech-ai/SnapAction` (organization-owned, Apache-2.0).

Configured on 2026-07-20:

- default branch: `main`;
- visibility: public;
- private vulnerability reporting: enabled;
- secret scanning and push protection: enabled;
- Dependabot security updates: enabled;
- Actions: enabled; hosted `macos-26` CI job `build-and-test` is required on `main`;
- branch protection on `main`: required status check `build-and-test` (strict), enforce admins, dismiss stale reviews, linear history, conversation resolution, no force pushes, no branch deletion;
- required approving review count is `0` so a maintainer can merge after green CI without inventing a second human reviewer on a solo-maintained repo.

## Repository metadata

- Description: “Local-first macOS utility that turns screen or image OCR into confirmed Reminders, Calendar events, or clean clipboard output.”
- Topics: `macos`, `swift`, `swiftui`, `ocr`, `vision`, `screen-capture`, `reminders`, `calendar`, `local-first`.
- Homepage: `https://rsitech.ai`.

## Repository settings

- Issues enabled with structured templates.
- Wiki, Discussions, Projects, Pages, and sponsorship remain disabled unless each has an accountable maintainer and purpose.
- Restrict Actions to approved, immutable-pinned actions; retain read-only default token permissions.
- Recheck every protection and security setting after any visibility or ownership change.

Do not claim notarization, App Store acceptance, or a completed Codex Security scan from GitHub configuration alone.
