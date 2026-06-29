# Production Plan: SnapAction

## Product Brief

- Target user: Mac knowledge workers who turn screenshots, dashboards, PDFs, chats, and tickets into concrete follow-up actions.
- Primary job: capture visible information and convert it into a confirmed Reminder, Calendar event, or clean text/table payload.
- Core workflow: capture/import -> OCR -> local AI/action extraction -> deterministic validation -> user confirmation -> system write or clipboard restore.
- Business model: paid Mac utility; subscription only for later advanced integrations.
- Supported macOS versions: macOS 26+ for Foundation Models and modern SwiftUI glass treatment.
- Offline behavior: local-first; Vision OCR, Foundation Models availability fallback, EventKit, pasteboard, and file-backed history all run without external services.
- Data handled: OCR text, action candidates, metadata-only history, durable clipboard text/table payloads.
- Privacy posture: no network calls, no screenshot pixel persistence, no raw OCR text in telemetry.
- V1 scope: three actions only: Reminder, Calendar Event, Extract Text/Table.
- Explicitly out of scope: cloud LLM fallback, contact extraction, Jira/Linear, App Store packaging, signed distribution.

## Architecture

- Scene model: `WindowGroup` primary window, `MenuBarExtra`, `Settings`.
- Window roles: main review window plus settings window.
- Layout model: native sidebar-detail split view with detail review surface.
- State ownership: app-wide `@Observable AppState`; local view state for edited candidate title.
- Persistence: JSON files under Application Support for history and clipboard snapshot; corrupt history recovers to an empty writable file.
- Services: Vision OCR, ScreenCaptureKit capture, Foundation Models extraction, EventKit writes, NSPasteboard copy, OSLog telemetry.
- App Intents / Foundation Models / advanced capabilities: Foundation Models structured extraction with deterministic fallback; App Intents deferred.
- Folder/module structure: `SnapActionCore` for testable contracts/stores/workflow; `SnapActionApp` for SwiftUI and platform adapters.

## Build And Run

- Project type: SwiftPM macOS GUI app.
- Build command: `swift build`.
- Run command: `./script/build_and_run.sh`.
- `script/build_and_run.sh` status: stages `dist/SnapAction.app`, kills stale process, launches via `/usr/bin/open -n`, supports `--verify`, `--logs`, and `--telemetry`.
- Codex Run action status: `.codex/environments/environment.toml` points to `./script/build_and_run.sh`.

## Design System

- Native structures: `NavigationSplitView`, toolbar commands, menu bar extra, settings form, native search.
- Adaptive states: ready, processing, no capture, no candidates, validation warning/error, permission unavailable, clipboard cache ready.
- Visual style: system materials plus Liquid Glass where supported, semantic tone colors, native sidebar density.
- Motion rules: no idle continuous animation; motion reserved for processing and state transitions.
- Accessibility requirements: icon buttons use `Label`; primary actions are available by toolbar/menu/keyboard; Reduce Motion still needs a manual VoiceOver pass before release.
- Empty/loading/error/offline/permission states: implemented for capture/import/extraction/write failures; App Store purpose strings deferred until Xcode bundle packaging.

## Test Strategy

- Unit tests: OCR ordering, action validation, AI unavailable fallback, display semantics, history privacy, corrupt history recovery, durable clipboard snapshot, workflow execution gates.
- Integration tests or mocks: fake extractor/executor workflow and file-backed stores.
- UI/manual smoke: launch built `.app`, process presence check, restart loop, telemetry launch check, clipboard cache restart check.
- Release smoke: SwiftPM `.app` launch only; signed/notarized archive deferred.
- Commands: `swift test`, `swift build`, `./script/build_and_run.sh --verify`.

## Observability

- Logger subsystem: `com.s1kor.snapaction`.
- Categories: `Workflow`.
- Key lifecycle/action events: app state initialization, capture requested, import requested, document processed, execution requested/finished, clipboard restored, recoverable errors.
- Sensitive logging exclusions: no screenshot bytes, no raw OCR text, no clipboard text, no user payload contents.

## App Store Readiness

- Bundle ID: local run bundle uses `com.s1kor.snapaction`.
- Signing team: not configured.
- Sandbox/entitlements: not configured; required before App Store distribution.
- Privacy manifest: not created.
- Privacy labels: local OCR/action metadata only; final disclosures pending.
- Assets: app icon/screenshots not created.
- Metadata: not created.
- Review notes: permission use and local-only AI behavior need final wording.
- Known blockers: Xcode app target or package-to-bundle release pipeline, signing, sandbox entitlements, Info.plist usage strings, privacy manifest, app icon, App Store metadata.

## Iteration Log

| Date | Gate | Change | Verification | Next blocker |
| --- | --- | --- | --- | --- |
| 2026-06-29 | Persistence | Added durable clipboard snapshot store and corrupt history recovery. | `swift test` 9 tests passed. | Manual UI restore click still needs human confirmation. |
| 2026-06-29 | Performance | Removed idle continuous animation and kept motion for state changes/processing. | Idle sample dropped from ~18-40% to 0-6.7%, memory ~56-57 MB. | Use Instruments before release-candidate claims. |
| 2026-06-29 | Observability | Added OSLog workflow telemetry without raw OCR/clipboard text. | Telemetry showed `App state initialized ... clipboardReady=true` after restart. | Add more categories if workflows grow. |
| 2026-06-29 | Build/run | Verified staged `.app` launch and restart loop. | `./script/build_and_run.sh --verify`; 3 restart loop passed. | Signed distribution pipeline deferred. |
