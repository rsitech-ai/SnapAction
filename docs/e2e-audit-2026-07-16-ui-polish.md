# SnapAction UI Polish E2E Audit

## Scope

- Date: 2026-07-16
- App: `<repository>/dist/SnapAction.app`
- Package / target: SwiftPM `SnapAction` / executable target `SnapActionApp`
- Bundle identifier: `com.s1kor.snapaction`
- Platform: native macOS 26+ SwiftUI app
- Readiness target: polish-ready UI with truthful external and release blockers
- Safe fixture authority: local Demo Capture, local clipboard text, app-local metadata/history changes, and reversible window/settings interactions
- Forbidden without action-time confirmation: Calendar or Reminder writes, Screen Recording permission acceptance/change, appearance or accessibility setting changes, data deletion, and any macOS system-setting mutation

Computer Use interactions were performed exclusively through the `node_repl` `@oai/sky` wrapper. No AppleScript, `osascript`, System Events, or synthetic event utilities were used.

## Commands and evidence

| Check | Command / tool | Result | Evidence |
| --- | --- | --- | --- |
| Unit/integration tests | `swift test` | Passed before the audit and after each TDD fix; remediation suite now contains 46 tests | Terminal output; final fresh count is recorded in the verification section below |
| Build | `swift build` | Passed | Terminal output |
| Bundle launch | `script/build_and_run.sh --verify`; process-path inspection | Passed in the implementation worktree and again after fast-forwarding the primary feature branch | Final process path `<repository>/dist/SnapAction.app/Contents/MacOS/SnapAction` |
| Native UI | Computer Use through `node_repl` + `@oai/sky` | Real AX state read after each interaction | Scenario matrix below |
| Telemetry | `script/build_and_run.sh --telemetry` | Live subsystem events captured; no raw OCR or clipboard payload | `.artifacts/ui-polish-2026-07-16/telemetry-subsystem.log` |
| Motion source scan | `rg` over animation and accessibility APIs | No explicit animation call sites, loops, unscoped implicit animation, or custom duration | Strict motion review below |
| Current appearance | `defaults read -g AppleInterfaceStyle` | `Dark` | Read-only terminal result |
| Accessibility preferences | read-only `defaults read com.apple.universalaccess ...` | Keys were absent; no system value was changed | Runtime variants marked blocked/partial below |

Screenshots are intentionally gitignored under `.artifacts/ui-polish-2026-07-16/`:

- `01-empty-permission-blocked.png` — dark empty state and contextual Screen Recording recovery
- `02-review-fallback.png` — historical pre-hardening populated fallback review; retained for chronology, not used as proof of the new provenance copy
- `03-empty-title-disabled.png` — empty-title validation path
- `04-edited-title-persisted.png` — corrected current candidate, editor, result, and history state
- `05-settings.png` — settings surface
- `07-review-large-window.jpeg` and `08-review-typical-window.jpeg` — zoomed large and typical layouts
- `10-review-split-minimum.jpeg` — clamped review split
- `11-keyboard-focus.jpeg` — keyboard traversal evidence
- `13-settings-minimum.png` — current 1-day lower boundary
- `14-settings-maximum.png` — current explicit 90-day upper boundary; supersedes ambiguous `12-settings-maximum.jpeg`
- `15-review-foundation-models.png` — post-hardening two-candidate Foundation Models review
- `16-import-failure-empty.png` — visible image-import failure, retry, and dismiss controls in the empty capture state
- `17-import-failure-stale-review.png` — visible image-import failure above an intact stale review candidate and OCR document
- `retention-boundaries-ax.md` — frozen full AX text for 1, 90, restored 30, and relaunched 30 plus sidecar proof

## Scenario matrix

| Surface | Scenario | Actual result | Status |
| --- | --- | --- | --- |
| Fresh bundle | Build, verify launch, process path | Primary feature-branch `.app` built and launched after the implementation fast-forward; process proof passed | Verified |
| Empty workspace | First/relaunch state | Capture-first hierarchy, local-processing note, permission recovery, history, and conditional clipboard restore were readable and unclipped | Verified |
| Empty workspace | Import Image cancel | Open panel appeared and Cancel returned without state loss | Verified |
| Empty workspace | Invalid supported image import | Typed `Image couldn’t be read` banner rendered in pixels and AX; retry reopened the native panel, Cancel preserved the error, and Dismiss removed it | Verified after fix |
| Empty workspace | Demo Capture | Initially remained indefinitely from the caller's perspective. `cb7190f` bounds caller response; `27ad7d8` scopes gate acquisition and `defer` cleanup to the actual model operation, including pre-cancelled callers, while preventing overlap without claiming forced termination. Two live reruns completed Foundation Models before the deadline. | Verified with split live/test evidence |
| Processing | Demo progress | Honest `Finding safe actions` progress state shown; no duplicate operation accepted | Verified |
| Toolbar | Capture Screen | Permission denial returned to explicit Screen Recording recovery without a prompt acceptance or setting change | Verified |
| Toolbar / shortcut | Import Image and Command-Shift-I cancel | Native Open panel appeared and cancelled safely; one toolbar attempt also exposed a transient Computer Use pipe failure, resolved by relaunch | Verified with tool caveat |
| Capture shortcuts | Command-Shift-1 and Command-Shift-2 | Capture denial and Demo Capture paths invoked correctly | Verified |
| Capture menu | Menu inventory and Demo Capture | Capture Screen, Demo Capture, and Import Image entries were present; Demo executed from the menu | Partially verified; other entries share already verified handlers |
| Candidate review | Pointer/keyboard selection | Post-hardening Demo produced Reminder and Calendar candidates; pointer selection changed the active review form to Planning sync. Earlier keyboard focus traversal remained visible. | Pointer switching verified; multi-candidate keyboard traversal not repeated |
| Candidate review | Invalid image over an existing review | The typed image failure rendered above the action pane while the one-block OCR document and `File expenses` candidate remained visible; dismiss removed only the banner | Verified after fix |
| Candidate review | Edit title | Empty/whitespace title now shows `Action title is required.` and disables Copy Text | Verified after fix |
| Candidate review | Confirm edited title | Copy Text preserves the trimmed edited title in the selected candidate, editor, snapshot status, and new history row | Verified after fix |
| Safe action | Copy Text | Clipboard received exact demo OCR text; UI showed typed success feedback | Verified |
| Persistence | Restore Clipboard after relaunch | External fixture replaced clipboard; Restore Clipboard restored the exact saved SnapAction payload | Verified |
| History | Match / no match / clear | Matching result remained; no-match now reads `No matching history`; clearing restored all rows | Verified after fix |
| Settings | Open, close, reopen | Native Settings window remained stable and reflected access/model/clipboard status | Verified |
| Settings | Retention Stepper | Real 30→1→90→30 pass showed singular `1 day`, explicit `90 days`, and restored 30; relaunch restored 30 from `history.retention.json`. Store pruning is clock-tested on load/append and immediate AppState changes. | Verified after fix |
| Settings | Request Access / Open Privacy Settings | Buttons, labels, hints, and recovery copy were inspected; stopped before permission navigation/mutation | Blocked by explicit authority boundary |
| Main window | Typical / zoomed large | Both layouts retained OCR, editor, confirmation, toolbar, and history without overlap | Verified |
| Main window | Minimum / toolbar overflow | Coordinate resize could not engage the window border through AX; source minimum is 980 x 640 | Blocked by Computer Use window-border limitation |
| Sidebar | Resize, collapse, restore | AX splitter moved from 148 to 250; toolbar collapse/restore preserved selection and content | Verified |
| Review split | Narrow / restore | AX split moved from 830 to 448, clamped against pane minima, then restored to 900 | Verified |
| Keyboard | Tab traversal | Title text became selected, next traversal returned focus to the selected candidate; focus remained visible in screenshots | Verified |
| Long content | Long edited title | Long title remained editable and persisted without leaking/reverting | Verified |
| Long content | Large OCR fixture | Demo OCR was selectable and monospaced, but no separate large OCR image fixture was imported | Not verified in this pass |
| Appearance | Current Dark | Empty, review, permission, settings, typical, and large states captured in current Dark appearance | Verified |
| Appearance | Light | Not changed because system appearance mutation was forbidden and no dedicated in-app appearance override exists | Blocked |
| Accessibility | Reduce Motion | No custom animation call sites exist; native system controls own their motion | Source-verified; runtime preference variant blocked |
| Accessibility | Reduce Transparency / increased contrast | Surfaces explicitly consume `accessibilityReduceTransparency` and `colorSchemeContrast`; system preference keys were not changed | Source-verified; runtime variants blocked |
| Menu bar extra | Capture/Demo/Import/Settings/Quit | SwiftUI scene and shared handlers are present; SystemUIServer AX inspection timed out, so status-item clicks were not claimed | Blocked by AX limitation |
| Quit/relaunch | Relaunch through project script | Process terminated, fresh worktree bundle launched, history and clipboard snapshot persisted | Verified |
| Calendar / Reminder | Candidate review and write | Live post-hardening Demo produced and switched between Reminder and Calendar review forms. No external write or permission request was attempted. | Review verified; write blocked by authority |

## Findings and fixes

| Severity | Finding | Root-cause proof | Fix | Re-verification |
| --- | --- | --- | --- | --- |
| High | Demo Capture could remain indefinitely in `Finding safe actions` from the caller's perspective | Reproduced for more than one minute; process sample showed active FoundationModels/TokenGeneration work; extractor awaited it without a response deadline | `0d44b6e` introduced fallback; `cb7190f` adds caller cancellation; `27ad7d8 fix: scope model attempt gate ownership` acquires inside the actual operation, checks cancellation first, maps typed busy, and uses `defer` cleanup | 5 deterministic deadline/cancellation/pre-cancellation/single-flight tests, full suite, rebuild; two live Demo runs completed the model success path before the deadline |
| High | Fallback truth was erased by validation and then hidden by an availability-only AppState refresh | Timeout/failure copy lived in `ValidationState`; `ActionValidator` replaced that field and `refreshPermissionStatus()` reset the UI to availability | `e409463 fix: surface deterministic fallback provenance` adds a backward-compatible typed provenance field and reason-specific app presentation | Legacy decode, validator/edit preservation, exact copy, full AppState presentation, and successful-replacement tests; current live runtime completed the model path, so no artificial timeout was induced |
| High | Whitespace title left Copy Text enabled and could reach the executor | AX tree showed an enabled Copy Text button after setting title to whitespace; UI used the original candidate validation | `723392c fix: keep edited actions consistent` revalidates edited titles in UI and at the app-state boundary | Focused red/green tests; AX now shows disabled button, explicit reason, and no executor call |
| High | Confirmed edited title reverted in editor/current candidate/history | Real Copy Text saved the edited snapshot title but AX immediately showed original title and history row | Same `723392c` updates the active candidate before constructing the persisted session | Red/green persistence test and real Copy Text show `Verified edited title persists` across candidate, field, snapshot, and history |
| Polish | History no-match state said `No history` despite stored rows | Reproduced with a nonmatching query while two rows were stored | `60bdf9c fix: clarify filtered history state` | Focused semantics test and live AX now read `No matching history`; clearing restores rows |
| Important | Retention Stepper did not persist or prune history | The value was a plain in-memory `Int`; `HistoryStore` had no retention policy | `a1067d7 fix: persist and enforce history retention` adds atomic sidecar persistence, calendar-day pruning on load/append, shared workflow observation, and immediate AppState pruning | Clock-controlled cutoff, append, shared-workflow, clamp, AppState, and relaunch tests; real 1/90/30 pass plus disk and relaunched UI proof |
| Polish | Stepper minimum read `1 days` | Reproduced at the real 1-day boundary | `8e611af fix: polish retention boundary copy`; `9b105ce` clarifies the retained object | Focused semantics test; final copy is `Retain history for 1 day` |
| Important | Workflow errors were written to dead `statusMessage` state and never rendered after StatusStrip removal | AppState catches mutated `statusMessage`, while no current view read it | `9b105ce fix: surface workflow failures` removes the dead state, adds typed capture-permission/capture/image-import/extraction presentation, and renders a shared dismissible banner in visible phase content | Four AppState failure/clearing tests, typed presentation semantics, two real invalid-image paths, retry/dismiss interaction, and matching AX/pixel evidence |
| Important | A failed replacement preserved stale review content but prematurely erased its deterministic-fallback disclosure | `beginExtraction()` cleared provenance before the replacement had produced a successful session | `a3fe558 fix: preserve stale extraction provenance` makes successful resolution the provenance commit point | Focused pending-success and failed-replacement tests prove stale candidate/provenance/disclosure persistence and correct successful replacement |
| Polish | Screen Recording recovery could stay stale after permission was granted in System Settings | Scene activation refreshed permission state, but failure cleanup existed only in the in-app Request Access action | `a3fe558` centralizes permission-failure cleanup inside `refreshPermissionStatus()` | Scene activation and Request Access now share the same cleanup path; full suite and bundle verification pass |
| Important | A zero-candidate deterministic fallback lost its timeout/failure provenance | Provenance was stored only on candidates, so an empty candidate array had no carrier into `CaptureSession` or AppState | `940fdaa fix: close PR review findings` adds an extraction-result/session provenance boundary independent of candidate count | Core workflow and AppState regressions prove a zero-candidate timeout remains visible and contextual |
| Important | Retention kept one extra calendar date | The cutoff subtracted the full retention count and included that date, so 1 retained today plus yesterday | `940fdaa` changes the inclusive cutoff to `1 - retentionDays` | Focused 1-day and 30-day boundary tests prove exactly N retained calendar dates |
| Polish | Execution results were visible but not explicitly announced to assistive technologies | Candidate feedback was inserted as a label after an asynchronous processing phase without an announcement notification | `940fdaa` posts the candidate-bound result through `AccessibilityNotification.Announcement`, including the initial recreated review state | Announcement-copy regression and full build pass; a live VoiceOver navigation session remains a separate runtime gate |
| Polish | Healthy model status occupied sidebar space, and retention copy described metadata instead of history | Healthy launch AX always showed a redundant model row; retention promise was broader than the label | `9b105ce` makes the model section conditional on fallback and changes copy to `Retain history for N day(s)` | Semantics tests plus healthy launch AX with no Model row |

## Strict motion review

Verdict: **Approve** for the custom motion layer.

- `rg` found no `.animation`, `withAnimation`, `repeatForever`, `repeatCount`, `rotationEffect`, `scaleEffect`, `symbolEffect`, or custom transition call sites under `Sources/`.
- Therefore there is no high-frequency custom animation, looping idle motion, unscoped implicit animation, keyboard-triggered custom animation, or custom UI duration above 300 ms.
- Processing uses the native busy indicator. Button, menu, split-view, toolbar, and settings behavior use system-owned transitions and inherit system Reduce Motion behavior.
- The restrained result is consistent with the Crisp Response requirement: frequent professional actions are immediate, while system controls provide native state feedback.

## Blocked and external gates

- Screen Recording is denied. The permission-specific recovery UI is verified, but changing the TCC setting requires the owner.
- Calendar and Reminder writes and their permission prompts were not attempted because they are external writes outside the safe audit authority.
- The current Apple Intelligence runtime completed before the caller-response deadline in both remediation reruns and produced a two-candidate Reminder/Calendar review on the second run. The corrected timeout/failure presentation is deterministic integration evidence in this pass because no artificial model failure was introduced.
- Light appearance, Reduce Transparency, increased contrast, and Reduce Motion runtime variants require a system-setting change or a future app-local QA override. No setting was mutated.
- MenuBarExtra status-item automation and minimum window border drag were blocked by the available AX/Computer Use surface.
- App Store packaging remains outside this pass: signing, sandbox entitlements, usage descriptions, privacy manifest/labels, app icon, screenshots/metadata, notarization, and App Store Connect proof are not complete.

## Readiness

**Weakest truthful label: Smoke-clean (broad safe-surface interaction coverage), not polish-ready and not release-candidate-ready.**

The built app, capture-denied recovery, bounded caller response, live multi-candidate review switching, review/edit/validation, safe Copy Text, clipboard restore, history search, enforced retention boundaries and relaunch persistence, sidebar/review splits, current Dark appearance, motion source review, and telemetry are proven. The label stays at Smoke-clean because large OCR, Light/accessibility runtime variants, MenuBarExtra clicks, minimum-window overflow, fallback presentation in a naturally timed-out live attempt, and external Calendar/Reminder writes remain blocked or unverified.

### Fresh completion gate

- `git diff --check` — passed.
- `swift test` — 46 tests passed, 0 failures.
- `swift build` — passed.
- `script/build_and_run.sh --verify` — exit 0; its nested 46-test run passed.
- `pgrep` / `ps` — PID `36312` at the final primary-checkout gate.
- `ps` — executable was the primary feature-branch bundle at `<repository>/dist/SnapAction.app/Contents/MacOS/SnapAction`.
- Pre-commit `git status --short` — only the updated audit, production plan, and review-hardening reflection were intentional tracked changes; `.artifacts` and `.superpowers` remained ignored.

The next targeted pass should add an app-local QA fixture/launch override for multiple candidate kinds, large OCR, Light/Dark, Reduce Motion/Transparency, and increased contrast; then rerun MenuBarExtra and minimum-window automation with a status-item/window-frame-capable driver.
