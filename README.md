# SnapAction

SnapAction is a local-first macOS utility that turns screen or image OCR into a confirmed action: create a Reminder, create a Calendar event, or copy clean text/table output.

## Requirements

- macOS 26+
- Xcode 26+
- Swift 6.2+
- Apple Intelligence enabled for AI-first extraction

The app remains useful without Apple Intelligence: it falls back to safe text/table extraction and does not silently create Reminder or Calendar candidates.

## Run

```bash
swift test
swift build
script/build_and_run.sh
```

For a non-interactive verification pass:

```bash
script/build_and_run.sh --verify
```

## Current MVP Behavior

- `Command-Shift-1`: capture the first display through ScreenCaptureKit, OCR it with Vision, then suggest actions.
- `Command-Shift-2`: run the built-in demo capture without needing Screen Recording permission.
- `Command-Shift-I`: import an image and run Vision OCR.
- Suggested actions are capped to three candidates and must be reviewed before execution.
- Reminders and Calendar writes use EventKit and request permission on first write.
- Text/table extraction copies to the macOS pasteboard.
- The last copied text/table payload is cached locally so it can be restored after closing, reopening, or restarting the app.
- Local history stores OCR text, structured candidates, timestamps, and execution results. It does not store screenshot pixels.

## Permission Notes

Screen capture requires macOS Screen Recording permission. If capture fails, use SnapAction Settings to request permission or open Privacy Settings, then restart the app if macOS requires it.

Calendar and Reminders permissions are requested only when a confirmed EventKit write is attempted. Denial is treated as a recoverable result and is not recorded as a successful action.

The global hotkey monitor uses macOS event monitoring. The menu commands always work while SnapAction is focused; system-wide key monitoring may require Accessibility permission depending on local privacy settings.

## Clipboard Recovery

When a text/table action is confirmed, SnapAction saves the copied payload to:

`~/Library/Application Support/SnapAction/clipboard.json`

Use `Restore Clipboard` in the review surface to put the last saved payload back onto the macOS clipboard. The cache stores text only, never screenshot pixels.

## Architecture

- `SnapActionCore`: OCR document model, action candidates, validation, extraction contracts, execution protocol, metadata-only history, and workflow orchestration.
- `SnapActionApp`: SwiftUI macOS app, menu bar extra, settings, Vision OCR, Foundation Models extraction, ScreenCaptureKit snapshot capture, EventKit writes, and pasteboard copy.

Rust is intentionally not part of v1. The future Rust boundary mirrors `ActionExtractionRequest` in and `[ActionCandidate]` plus validation diagnostics out.
