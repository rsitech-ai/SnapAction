# Reflection Entry

## Task

- **ID / title:** SnapAction UI polish review hardening
- **Date:** 2026-07-16
- **Scope:** Correct the rejected Task 7 deadline, fallback-provenance, retention, and evidence claims.
- **Authority boundary:** Local code, tests, app-local metadata settings, reversible native UI interaction, and repo evidence only. No permission mutation, external Calendar/Reminder write, destructive GUI action, push, or PR.

## Success and Risk

- **Success criteria:** A bounded caller response with cancellation propagation and non-overlap; typed fallback truth that survives validation/editing; persisted calendar-day retention observed by UI and workflow; 35-test/build/bundle verification; conservative real-UI evidence.
- **Hypothesis 1:** Canceling an unstructured model task is enough to guarantee the operation terminates by the deadline.
- **Hypothesis 2:** A warning in `ValidationState` is sufficient to preserve and present deterministic fallback truth.
- **Hypothesis 3:** A Stepper-bound integer is sufficient to describe retention behavior without a store-level policy.
- **Rollback path:** Revert each focused remediation commit independently (`cb7190f`, `e409463`, `a1067d7`) while retaining the prior UI fixes; restore the default 30-day sidecar value if retention behavior regresses.

## Candidate Directions

| Candidate | Expected benefit | Main risk | Evidence before choice | Decision |
|---|---|---|---|---|
| Rename the deadline contract, return promptly, propagate cancellation, and hold a single-flight gate until real model completion | Truthful semantics without overlapping surviving attempts | A cancellation-insensitive in-process call may outlive the caller | Review rejection correctly noted Swift cannot force such work to terminate | Selected |
| Continue claiming a hard task-lifetime timeout | Minimal code change | False safety claim and repeated model overlap | Existing helper canceled tasks but never proved termination | Rejected |
| Add typed provenance beside validation | Fallback reason survives validators, title edits, persistence, and AppState refresh | Schema migration | `ActionCandidate` is Codable and legacy history exists | Selected with optional backward-compatible field |
| Keep fallback reason only in validation copy | No schema change | Validator intentionally replaces the field | Full path review reproduced the erasure | Rejected |
| Persist retention beside history and enforce it inside `HistoryStore` | UI and workflow share one source of truth | Cutoff and atomic-write mistakes | Existing Stepper never touched storage | Selected with clock-controlled tests |
| Prune only in the Settings view | Small UI edit | Workflow append and relaunch bypass the policy | `CaptureWorkflow` owns a copied `HistoryStore` | Rejected |

## Evidence

- **First meaningful failure signal:** Review rejected the hard timeout claim, observed availability copy hiding fallback truth, showed the Stepper was nonfunctional, and found the 90-day screenshot did not visibly prove 90.
- **Commands or runtime checks:** Focused red/green Swift Testing runs; repeated `swift test`; `swift build`; `script/build_and_run.sh --verify`; exact worktree process path; `@oai/sky` 30→1→90→30 Settings sweep and relaunch; two live Demo reruns; frozen AX boundary evidence.
- **What the evidence ruled in or out:** Cancellation tests prove bounded caller response and propagation, not forced task termination. Current live Demo runs proved Foundation Models success and two-candidate switching, but did not naturally reach timeout/failure presentation. Store and AppState tests plus relaunch prove retention beyond display copy.

## Decision

- **Root cause or remaining unknown:** The original task conflated caller latency with child-task lifetime, coupled fallback truth to a mutable validation field, and treated retention as presentation-only state. Whether a future Foundation Models call ignores cancellation and for how long remains framework-controlled.
- **Retained fix / direction:** Caller-response deadline plus winding-down single-flight gate; optional typed extraction provenance; atomic file-backed 1...90-day retention enforced at the store boundary.
- **Why alternatives were rejected:** They either preserved false claims, allowed overlapping model work, lost fallback truth, or bypassed retention in workflow/relaunch paths.
- **Residual risk:** A cancellation-insensitive Foundation Models call can still consume resources after fallback, though it blocks a second model attempt. Live timeout/failure presentation is integration-proven but was not naturally reached in the final runtime pass.
- **Rollback trigger:** Regressed responsiveness, history corruption/pruning beyond the selected calendar cutoff, legacy decode failure, or a reproducible gate deadlock.

## Reusable Lesson

- **Pattern to retain:** Name concurrency guarantees at the boundary actually controlled; keep operational provenance separate from validation; enforce persisted policy in the storage layer shared by every caller.
- **Pattern to avoid:** Treating `Task.cancel()` as forced termination, overloading one UI field with unrelated truth, and documenting settings from screenshots that do not visibly show the claimed value.
- **Where it applies next:** Other on-device model calls, cancellable macOS workflows, and any app setting that promises data lifecycle behavior.
