# GitHub configuration handoff

Observed on 2026-07-20 for `s1korrrr/SnapAction`:

- owner type: personal account;
- visibility: private;
- default branch: `main`;
- repository description, homepage, topics, detected license, branch protection, and private vulnerability reporting: not configured;
- Actions: enabled; no runs, artifacts, caches, releases, or tags were present at inspection time;
- the matching profile repository `s1korrrr/s1korrrr` was not present.

These external settings were inspected but not changed. The only external Git operation authorized for this pass is pushing the verified `main` commit.

## Proposed repository settings after publication blockers clear

- Description: “Local-first macOS utility that turns screen or image OCR into confirmed Reminders, Calendar events, or clean clipboard output.”
- Topics: `macos`, `swift`, `swiftui`, `ocr`, `vision`, `screen-capture`, `reminders`, `calendar`, `local-first`.
- Keep the homepage empty until an owner-approved stable destination exists.
- Enable Issues only after contribution governance and private vulnerability intake are ready.
- Keep Wiki, Discussions, Projects, Pages, and sponsorship disabled unless each has an accountable maintainer and purpose.
- Restrict Actions to approved, immutable-pinned actions; retain read-only default token permissions.
- After CI proves reliable on `main`, protect it with pull requests, required CI, conversation resolution, force-push prevention, and branch-deletion prevention.
- Enable dependency graph, Dependabot alerts/security updates, secret scanning/push protection, and private vulnerability reporting when the repository plan and visibility support them.
- Recheck every protection and security setting after any visibility change.

Do not make the repository public, enable intake, publish a release, add required checks, or change profile content until the corresponding owner/legal gates are resolved.
