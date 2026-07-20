# GitHub configuration handoff

Observed on 2026-07-20 for `rsitech-ai/SnapAction` after the authorized private transfer:

- owner type: organization;
- visibility: private;
- default branch: `main`;
- detected license, branch protection, and private vulnerability reporting: not configured;
- Actions: enabled, but hosted jobs are externally blocked before execution by the GitHub account billing/spending-limit state;
- no releases or tags existed before the `0.1.0` private-preview pass.

The transfer preserves repository history, pull requests, redirects, and existing private visibility. Public visibility remains prohibited until the legal and publication gates clear.

## Repository metadata

- Description: “Local-first macOS utility that turns screen or image OCR into confirmed Reminders, Calendar events, or clean clipboard output.”
- Topics: `macos`, `swift`, `swiftui`, `ocr`, `vision`, `screen-capture`, `reminders`, `calendar`, `local-first`.
- Keep the homepage empty until an owner-approved stable destination exists.

## Settings deferred until publication blockers clear

- Enable Issues only after contribution governance and private vulnerability intake are ready.
- Keep Wiki, Discussions, Projects, Pages, and sponsorship disabled unless each has an accountable maintainer and purpose.
- Restrict Actions to approved, immutable-pinned actions; retain read-only default token permissions.
- After CI proves reliable on `main`, protect it with pull requests, required CI, conversation resolution, force-push prevention, and branch-deletion prevention.
- Enable dependency graph, Dependabot alerts/security updates, secret scanning/push protection, and private vulnerability reporting when the repository plan and visibility support them.
- Recheck every protection and security setting after any visibility change.

Do not make the repository public, enable public intake, add required hosted checks, or change profile content until the corresponding owner/legal and infrastructure gates are resolved. The authorized `0.1.0` private prerelease does not clear any public-publication gate.
