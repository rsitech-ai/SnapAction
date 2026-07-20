# GitHub configuration handoff

Target public configuration for `rsitech-ai/SnapAction`, approved on 2026-07-20:

- owner type: organization;
- visibility: public after the rewritten PR is merged and release evidence passes;
- default branch: `main`;
- detected license: Apache-2.0 after merge; private vulnerability reporting: enable before issue intake;
- Actions: enabled, but hosted jobs are externally blocked before execution by the GitHub account billing/spending-limit state;
- no releases or tags existed before the `0.1.0` private-preview pass.

The transfer preserves repository history, pull requests, and redirects. The owner separately authorized sanitizing published history before public visibility.

## Repository metadata

- Description: “Local-first macOS utility that turns screen or image OCR into confirmed Reminders, Calendar events, or clean clipboard output.”
- Topics: `macos`, `swift`, `swiftui`, `ocr`, `vision`, `screen-capture`, `reminders`, `calendar`, `local-first`.
- Homepage: `https://rsitech.ai`.

## Repository settings

- Enable Issues with structured templates and private vulnerability reporting.
- Keep Wiki, Discussions, Projects, Pages, and sponsorship disabled unless each has an accountable maintainer and purpose.
- Restrict Actions to approved, immutable-pinned actions; retain read-only default token permissions.
- After CI proves reliable on `main`, protect it with pull requests, required CI, conversation resolution, force-push prevention, and branch-deletion prevention.
- Enable dependency graph, Dependabot alerts/security updates, secret scanning/push protection, and private vulnerability reporting when the repository plan and visibility support them.
- Recheck every protection and security setting after any visibility change.

Do not add required hosted checks while Actions remains blocked before execution by the account billing/spending-limit state. Re-evaluate protection after the first real hosted green run.
