# SwiftUI Polish Audit Report: SnapAction

## Scope

- Date: 2026-06-29
- Auditor: Codex
- Platform: macOS
- Project: `/Users/s1kor/dev/andrzej/SnapAction`
- Product: SwiftPM executable `SnapAction`, app bundle staged at `dist/SnapAction.app`
- Configuration: Debug app-bundle smoke plus Release compile check
- Readiness target: end-to-end SwiftUI polish audit beyond unit tests
- Official Apple references: SwiftUI performance with Instruments, app responsiveness, XCTest

## Commands And Evidence

| Check | Command or Tool | Result | Evidence |
| --- | --- | --- | --- |
| HQ warmup | `/Users/s1kor/.codex/scripts/session-bootstrap.sh` | passed | mandatory docs and daily memory files present |
| Project discovery | `swift package describe --type json` | verified | SwiftPM, macOS 26.0, products `SnapAction` and `SnapActionCore` |
| Full tests | `swift test` | passed | 9 Swift Testing tests passed after fixes |
| Debug build | `swift build` | passed | compile completed |
| Release build | `swift build -c release` | passed | production compile completed |
| App launch verify | `./script/build_and_run.sh --verify` | passed | staged bundle launched and process verified |
| Running process | `pgrep -fl SnapAction`, `ps -o pid,etime,%cpu,rss,comm` | verified | one staged `dist/SnapAction.app` process; final sample 0.0% CPU, about 98 MB RSS |
| Empty-state screenshot | `screencapture` | verified after fix | `/tmp/snapaction-audit-2026-06-29-fixed-empty.png` |
| Demo extraction screenshot | `Command-Shift-2`, `screencapture` | verified after fixes | `/tmp/snapaction-audit-2026-06-29-demo-final.png` |
| Settings screenshot | SnapAction menu `Settings...`, `screencapture` | verified | `/tmp/snapaction-audit-2026-06-29-settings-valid.png` |
| Screen Recording denied path | SnapAction menu `Capture Screen`, `screencapture` | verified | `/tmp/snapaction-audit-2026-06-29-capture-final.png` |
| Logs | `log show --last 5m --predicate 'subsystem == "com.s1kor.snapaction" OR process == "SnapAction"'` | reviewed | expected ScreenCaptureKit/TCC denial; user-facing UI uses recovery copy |
| Restore Clipboard click | System Events button lookup and coordinate click | blocked | button lookup failed; coordinate click returned `-25200`; store-level tests pass |

Apple references consulted for audit framing:

- https://developer.apple.com/documentation/Xcode/understanding-and-improving-swiftui-performance
- https://developer.apple.com/documentation/xcode/improving-app-responsiveness
- https://developer.apple.com/documentation/xctest

## Feature Matrix

| Workflow / Feature | State Tested | Status | Notes |
| --- | --- | --- | --- |
| App bundle launch | default/restart | verified | launch uses project script and staged `.app` bundle |
| Process cleanup | repeated launch | verified | one `SnapAction` process remained |
| Main empty state | no capture | verified | clipped sidebar copy fixed |
| Toolbar/menu capture demo | success path | verified | demo produced OCR text and two candidates |
| AI extraction safety | bad relative-date proposal | fixed/verified | validator now blocks mismatched `tomorrow` dates; demo now uses explicit timestamps |
| Candidate preview | valid reminder candidate | verified | clean field list after generated-field filtering |
| Candidate write gate | code/test path | partially verified | disabled invalid writes verified visually; direct button click blocked by macOS automation |
| Clipboard cache | persisted store | verified | durable store tests pass; UI restore click still manual |
| Settings | permission/status surface | verified | visible, no clipped shortcut rows in current screenshot |
| Image import | open/cancel shortcut | partially verified | command path exercised, but focus drift made screenshot evidence unreliable |
| Screen capture | permission denied | verified | fails closed with recovery text |
| EventKit reminder/calendar write | permission/write path | not verified | requires real Calendar/Reminders permission run |
| History search | empty state | partially verified | search field visible; populated-history search not smoked |
| Light mode | appearance variant | not verified | only Dark appearance inspected |
| VoiceOver/accessibility | manual pass | not verified | accessibility labels added, but System Events still reported unnamed top-level buttons |

## Interaction Sweep

| Surface | Control / Action | Expected Response | Actual Response | Status | Evidence / Notes |
| --- | --- | --- | --- | --- | --- |
| Main toolbar/menu | Capture Demo | process sample OCR and suggestions | valid OCR/candidates shown | verified | `/tmp/snapaction-audit-2026-06-29-demo-final.png` |
| Main toolbar/menu | Capture Screen | fail closed when Screen Recording denied | friendly recovery message shown | verified | `/tmp/snapaction-audit-2026-06-29-capture-final.png` |
| Main toolbar/menu | Import Image | open image picker, cancel cleanly | shortcut exercised; screenshot focus unreliable | partially verified | needs manual image selection |
| Settings | Settings menu item | open Settings scene | Settings window opened | verified | `/tmp/snapaction-audit-2026-06-29-settings-valid.png` |
| Settings | Request / Open Privacy Settings | permission recovery actions | visible and labeled | not clicked | avoid changing system settings during audit |
| Candidate card | Create Reminder | enabled only for valid candidate | enabled for valid demo; disabled for invalid date candidate | verified visually | demo/fail-closed screenshots |
| Candidate card | Test Gate | non-writing confirmation failure | direct coordinate click blocked | blocked | System Events `-25200` |
| Clipboard shelf | Restore Clipboard | restore persisted clipboard payload | direct coordinate click blocked | blocked | store-level tests only |
| Search field | Search history | filter history rows | visible | not verified | no populated history state from real write |

## Visual And Animation Review

- Layout: main empty, demo, settings, and denied-permission states were visually inspected. The sidebar empty label no longer truncates.
- Backgrounds/materials: glass panels and status pills are consistent across main and candidate states.
- Typography/control sizing: current visible states fit at the audited window size; Settings shortcut rows are readable.
- Adaptive sizing: HSplitView is present and resizable; minimum/large window sweeps were not completed in this pass.
- Animation: processing halo is scoped to active work; no always-on idle animation regression observed. No Instruments hitch trace was captured.
- Light/Dark: Dark mode inspected; Light mode not verified.
- Accessibility: explicit accessibility labels were added to primary toolbar, candidate, clipboard, and Settings buttons, but full VoiceOver proof remains open.

## Performance Review

- Baseline: prior hardening removed always-running idle animation that had caused high idle CPU.
- Current sample: final `ps` sample showed one SnapAction process at 0.0% CPU and about 98 MB RSS after rebuild/capture-denied smoke.
- Foundation Models path: local demo run temporarily raised memory during extraction, then settled back down.
- Remaining risk: this is process sampling, not a Release Instruments trace. Do not claim release-grade responsiveness until Instruments confirms the capture/demo workflows.

## Issues Found And Fixed

| Severity | Area | Finding | Evidence | Fix |
| --- | --- | --- | --- | --- |
| high | AI safety | Foundation Models mapped `tomorrow` to the wrong date and the validator initially accepted it. | `/tmp/snapaction-audit-2026-06-29-demo-labelled.png` showed Jan 2027 for a tomorrow reminder | Added deterministic `tomorrow` date validation and prompt capture timestamp. |
| medium | Candidate preview | Generated reminder candidates displayed irrelevant fields from the model. | `/tmp/snapaction-audit-2026-06-29-demo-after-date-fix.png` | Filter generated fields by action kind at conversion boundary. |
| medium | Demo reliability | Built-in demo used relative dates, making the demo dependent on model inference. | invalid red candidate after field filter | Demo now emits explicit runtime ISO timestamps. |
| medium | Permission UX | Screen Recording denied state exposed raw TCC wording. | `/tmp/snapaction-audit-2026-06-29-capture-valid.png` | UI now shows friendly recovery copy; detailed OS error remains in logs. |
| polish | Visual | Sidebar empty suggestion text truncated in normal layout. | `/tmp/snapaction-audit-2026-06-29-main.png` | Changed copy to `No suggestions`. |
| polish | Accessibility | Primary controls lacked explicit labels in code. | System Events reported unnamed buttons | Added explicit labels/help to main controls and Settings buttons. |

## Remaining Risks

| Severity | Area | Risk | Next Action |
| --- | --- | --- | --- |
| medium | External writes | Real EventKit Reminder/Calendar writes were not exercised. | Run with Calendar/Reminders permission prompts and verify create/cancel/failure states. |
| medium | Capture | Granted ScreenCaptureKit path was not exercised because Screen Recording is denied. | Grant Screen Recording and run `Capture Screen` against a sample region. |
| medium | Clipboard UI | `Restore Clipboard` visible button could not be clicked by automation. | Manual click verification; optionally add a lightweight UI test harness later. |
| medium | Accessibility | VoiceOver pass was not completed. | Run VoiceOver navigation and inspect named controls. |
| polish | Appearance/adaptive | Light mode, large/minimum window sweeps, and full keyboard navigation remain open. | Run appearance/resizing matrix before calling polish-ready. |
| polish | Maintainability | `ContentView.swift` remains large. | Split into focused Sidebar, Detail, Candidate, and EmptyState view files. |

## Final Readiness Label

- Label: **Smoke-clean, not polish-ready**
- Why: build/test/release compile, staged app launch, empty state, demo extraction, fail-closed date validation, Settings, denied Screen Recording recovery, logs, and basic process sampling were verified with screenshots and commands.
- Why not higher: external writes, granted capture, Restore Clipboard button click, VoiceOver, Light mode, adaptive resize matrix, and Release Instruments profiling are still not proven.
