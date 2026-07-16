# SnapAction UI Polish E2E Audit

## Scope

- Date: 2026-07-16
- App: `/Users/s1kor/dev/andrzej/SnapAction/.worktrees/ui-ux-polish/dist/SnapAction.app`
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
| Unit/integration tests | `swift test` | Passed before the audit (16 tests), after each TDD fix, and with 22 tests before the final documentation pass | Terminal output; final fresh count is recorded in the verification section below |
| Build | `swift build` | Passed | Terminal output |
| Bundle launch | `script/build_and_run.sh --verify`; `pgrep -x SnapAction` | Passed; launched the worktree bundle, not the original checkout | Process path `/Users/s1kor/dev/andrzej/SnapAction/.worktrees/ui-ux-polish/dist/SnapAction.app/Contents/MacOS/SnapAction` |
| Native UI | Computer Use through `node_repl` + `@oai/sky` | Real AX state read after each interaction | Scenario matrix below |
| Telemetry | `script/build_and_run.sh --telemetry` | Live subsystem events captured; no raw OCR or clipboard payload | `.artifacts/ui-polish-2026-07-16/telemetry-subsystem.log` |
| Motion source scan | `rg` over animation and accessibility APIs | No explicit animation call sites, loops, unscoped implicit animation, or custom duration | Strict motion review below |
| Current appearance | `defaults read -g AppleInterfaceStyle` | `Dark` | Read-only terminal result |
| Accessibility preferences | read-only `defaults read com.apple.universalaccess ...` | Keys were absent; no system value was changed | Runtime variants marked blocked/partial below |

Screenshots are intentionally gitignored under `.artifacts/ui-polish-2026-07-16/`:

- `01-empty-permission-blocked.png` — dark empty state and contextual Screen Recording recovery
- `02-review-fallback.png` — initial populated review after deterministic fallback
- `03-empty-title-disabled.png` — empty-title validation path
- `04-edited-title-persisted.png` — corrected current candidate, editor, result, and history state
- `05-settings.png` — settings surface
- `07-review-large-window.jpeg` and `08-review-typical-window.jpeg` — zoomed large and typical layouts
- `10-review-split-minimum.jpeg` — clamped review split
- `11-keyboard-focus.jpeg` — keyboard traversal evidence
- `12-settings-maximum.jpeg` — 90-day upper boundary

## Scenario matrix

| Surface | Scenario | Actual result | Status |
| --- | --- | --- | --- |
| Fresh bundle | Build, verify launch, process path | Worktree `.app` built and launched; process proof passed | Verified |
| Empty workspace | First/relaunch state | Capture-first hierarchy, local-processing note, permission recovery, history, and conditional clipboard restore were readable and unclipped | Verified |
| Empty workspace | Import Image cancel | Open panel appeared and Cancel returned without state loss | Verified |
| Empty workspace | Demo Capture | Initially remained indefinitely in Foundation Models; after `0d44b6e`, deterministic fallback populated review within the 10-second bound | Verified after fix |
| Processing | Demo progress | Honest `Finding safe actions` progress state shown; no duplicate operation accepted | Verified |
| Toolbar | Capture Screen | Permission denial returned to explicit Screen Recording recovery without a prompt acceptance or setting change | Verified |
| Toolbar / shortcut | Import Image and Command-Shift-I cancel | Native Open panel appeared and cancelled safely; one toolbar attempt also exposed a transient Computer Use pipe failure, resolved by relaunch | Verified with tool caveat |
| Capture shortcuts | Command-Shift-1 and Command-Shift-2 | Capture denial and Demo Capture paths invoked correctly | Verified |
| Capture menu | Menu inventory and Demo Capture | Capture Screen, Demo Capture, and Import Image entries were present; Demo executed from the menu | Partially verified; other entries share already verified handlers |
| Candidate review | Pointer/keyboard selection | Single deterministic fallback candidate was selectable and keyboard focus returned to it | Verified for one candidate; multi-candidate switching blocked by local model timeout |
| Candidate review | Edit title | Empty/whitespace title now shows `Action title is required.` and disables Copy Text | Verified after fix |
| Candidate review | Confirm edited title | Copy Text preserves the trimmed edited title in the selected candidate, editor, snapshot status, and new history row | Verified after fix |
| Safe action | Copy Text | Clipboard received exact demo OCR text; UI showed typed success feedback | Verified |
| Persistence | Restore Clipboard after relaunch | External fixture replaced clipboard; Restore Clipboard restored the exact saved SnapAction payload | Verified |
| History | Match / no match / clear | Matching result remained; no-match now reads `No matching history`; clearing restored all rows | Verified after fix |
| Settings | Open, close, reopen | Native Settings window remained stable and reflected access/model/clipboard status | Verified |
| Settings | Retention Stepper | Clamped at 1 and 90; singular `1 day` fixed; setting restored to 30 | Verified after fix |
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
| Calendar / Reminder | Confirmation and write | No candidate of these kinds was produced after bounded fallback; no external write or permission request was attempted | Blocked by environment and authority |

## Findings and fixes

| Severity | Finding | Root-cause proof | Fix | Re-verification |
| --- | --- | --- | --- | --- |
| High | Demo Capture could remain indefinitely in `Finding safe actions` | Reproduced for more than one minute; process sample showed active FoundationModels/TokenGeneration work; extractor awaited it without a bound | `0d44b6e fix: bound local model extraction` adds a tested 10-second deadline and deterministic fallback | 2 focused deadline tests, full suite, rebuild, Demo button, shortcut, and menu each reached review |
| High | Whitespace title left Copy Text enabled and could reach the executor | AX tree showed an enabled Copy Text button after setting title to whitespace; UI used the original candidate validation | `723392c fix: keep edited actions consistent` revalidates edited titles in UI and at the app-state boundary | Focused red/green tests; AX now shows disabled button, explicit reason, and no executor call |
| High | Confirmed edited title reverted in editor/current candidate/history | Real Copy Text saved the edited snapshot title but AX immediately showed original title and history row | Same `723392c` updates the active candidate before constructing the persisted session | Red/green persistence test and real Copy Text show `Verified edited title persists` across candidate, field, snapshot, and history |
| Polish | History no-match state said `No history` despite stored rows | Reproduced with a nonmatching query while two rows were stored | `60bdf9c fix: clarify filtered history state` | Focused semantics test and live AX now read `No matching history`; clearing restores rows |
| Polish | Stepper minimum read `1 days` | Reproduced at the real 1-day boundary | `8e611af fix: polish retention boundary copy` | Focused red/green semantics test; real Settings now reads `Retain metadata for 1 day`; 90-day max and restore to 30 verified |

## Strict motion review

Verdict: **Approve** for the custom motion layer.

- `rg` found no `.animation`, `withAnimation`, `repeatForever`, `repeatCount`, `rotationEffect`, `scaleEffect`, `symbolEffect`, or custom transition call sites under `Sources/`.
- Therefore there is no high-frequency custom animation, looping idle motion, unscoped implicit animation, keyboard-triggered custom animation, or custom UI duration above 300 ms.
- Processing uses the native busy indicator. Button, menu, split-view, toolbar, and settings behavior use system-owned transitions and inherit system Reduce Motion behavior.
- The restrained result is consistent with the Crisp Response requirement: frequent professional actions are immediate, while system controls provide native state feedback.

## Blocked and external gates

- Screen Recording is denied. The permission-specific recovery UI is verified, but changing the TCC setting requires the owner.
- Calendar and Reminder writes and their permission prompts were not attempted because they are external writes outside the safe audit authority.
- The current Apple Intelligence runtime reports available but did not return the small structured response before the 10-second product bound. The deterministic text/table fallback works; multi-candidate and EventKit review states remain unproven live.
- Light appearance, Reduce Transparency, increased contrast, and Reduce Motion runtime variants require a system-setting change or a future app-local QA override. No setting was mutated.
- MenuBarExtra status-item automation and minimum window border drag were blocked by the available AX/Computer Use surface.
- App Store packaging remains outside this pass: signing, sandbox entitlements, usage descriptions, privacy manifest/labels, app icon, screenshots/metadata, notarization, and App Store Connect proof are not complete.

## Readiness

**Weakest truthful label: Smoke-clean (broad safe-surface interaction coverage), not polish-ready and not release-candidate-ready.**

The built app, capture-denied recovery, bounded Demo workflow, review/edit/validation, safe Copy Text, clipboard restore, history search, settings boundaries, sidebar/review splits, relaunch persistence, current Dark appearance, motion source review, and telemetry are proven. The label stays at Smoke-clean because multi-candidate switching, large OCR, Light/accessibility runtime variants, MenuBarExtra clicks, minimum-window overflow, and external Calendar/Reminder paths remain blocked or unverified.

### Fresh completion gate

- `git diff --check` — passed.
- `swift test` — 23 tests passed, 0 failures.
- `swift build` — passed.
- `script/build_and_run.sh --verify` — exit 0; its nested 23-test run passed.
- `pgrep -x SnapAction` — PID `97354` at the final verification time.
- `ps` — executable was the worktree bundle at `/Users/s1kor/dev/andrzej/SnapAction/.worktrees/ui-ux-polish/dist/SnapAction.app/Contents/MacOS/SnapAction`.
- Pre-commit `git status --short` — only `docs/production-plan.md` and `docs/e2e-audit-2026-07-16-ui-polish.md` were intentional tracked/untracked documentation changes; `.artifacts` and `.superpowers` remained ignored.

The next targeted pass should add an app-local QA fixture/launch override for multiple candidate kinds, large OCR, Light/Dark, Reduce Motion/Transparency, and increased contrast; then rerun MenuBarExtra and minimum-window automation with a status-item/window-frame-capable driver.
