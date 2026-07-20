# SnapAction

SnapAction is a local-first macOS utility that turns screen or image OCR into a confirmed action: create a Reminder, create a Calendar event, or copy clean text/table output.

## Publication Status

This repository is **not yet licensed or approved for open-source publication**. No project license has been selected; there is no adopted root license, contributor certificate, governance model, trademark decision, security contact, or completed formal security scan. External contributions are not yet accepted. See [open-source status](docs/open-source/OPEN_SOURCE_STATUS.md), [security policy status](SECURITY.md), and [publication blockers](docs/open-source/BLOCKERS.md).

## Requirements

- macOS 26+
- Xcode 26+
- Swift 6.2+
- Apple Intelligence enabled for AI-first extraction

The app remains useful without Apple Intelligence: it falls back to safe text/table extraction and does not silently create Reminder or Calendar candidates.

## Current Limitations

- The capture shortcut takes the first display; there is no display picker yet.
- The repository stages a local ad-hoc-signed development bundle. It does not produce a notarized, sandboxed, Developer ID, or Mac App Store artifact.
- Foundation Models availability depends on the local macOS and Apple Intelligence configuration.
- System-wide shortcut monitoring can be limited by macOS privacy settings; focused menu commands remain available.
- Public contributions, releases, and redistribution are closed until the legal, governance, security-intake, and naming gates are resolved.

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
- The last copied text/table payload is cached locally for up to seven days so it can be restored after closing, reopening, or restarting the app. It can be cleared independently in Settings.
- Local history stores only minimal action summaries: timestamp, action title and kind, and a bounded outcome. It does not persist OCR text, structured candidates, EventKit identifiers, or screenshot pixels. History expires according to the 1–90 day setting and can be cleared in Settings.

## Permission Notes

Screen capture requires macOS Screen Recording permission. If capture fails, use SnapAction Settings to request permission or open Privacy Settings, then restart the app if macOS requires it.

Calendar and Reminders permissions are requested only when a confirmed EventKit write is attempted. Denial is treated as a recoverable result and is not recorded as a successful action.

The global hotkey monitor uses macOS event monitoring. The menu commands always work while SnapAction is focused; system-wide key monitoring may require Accessibility permission depending on local privacy settings.

## Clipboard Recovery

When a text/table action is confirmed, SnapAction saves the copied payload to:

`~/Library/Application Support/SnapAction/clipboard.json`

Use `Restore Clipboard` in the review surface to put the last saved payload back onto the macOS clipboard. The cache stores text only, never screenshot pixels.

The clipboard cache expires after seven days and can be cleared from Settings without clearing action history. Its containing directory and file are restricted to the current user where supported.

## Community Builds

`script/build_and_run.sh` stages an unofficial `SnapAction Community` bundle with the neutral identifier `org.example.snapaction.community` unless a developer supplies validated overrides. See [community build configuration](docs/community-build/README.md). Official identity, signing credentials, Team IDs, and App Store credentials are not part of this repository.

## Repository Checks

```bash
swift test
swift build -c release
bash script/test_build_configuration.sh
python3 -m unittest discover -s Tests/ToolingTests -v
python3 script/check_repository_policy.py
python3 script/check_publication_gates.py # expected to exit 1 until owner/legal/security gates are resolved
```

The generated source manifest is at `docs/open-source/OPEN_SOURCE_MANIFEST.json`; the CycloneDX source SBOM is at `artifacts/sbom/snapaction.cdx.json`.

## Troubleshooting

- If screen capture is denied, open SnapAction Settings, follow the Screen Recording guidance, and restart the app if macOS requests it.
- If Calendar or Reminders writes are denied, review the corresponding macOS Privacy & Security permission; the app will not record the action as successful.
- If the default bundle identity was overridden incorrectly, run `script/build_and_run.sh --print-config`; invalid values fail before build or process changes.
- If stale clipboard data should be removed, use **Clear clipboard cache** in Settings. History has a separate clear control.

## Project Policies

- [Contributing](CONTRIBUTING.md) — mechanics and the current closed contribution gate.
- [Security](SECURITY.md) — no approved private intake route yet; do not disclose vulnerabilities publicly.
- [Support](SUPPORT.md) — safe support boundaries.
- [Releasing](RELEASING.md) — owner-controlled release gates.
- [Changelog](CHANGELOG.md) — factual unreleased changes.

Version `0.1.0` is the proposed first community-development milestone, not a published release. There is no adopted license, so the repository currently grants no open-source use or redistribution rights.

## Architecture

- `SnapActionCore`: OCR document model, action candidates, validation, extraction contracts, execution protocol, metadata-only history, and workflow orchestration.
- `SnapActionApp`: SwiftUI macOS app, menu bar extra, settings, Vision OCR, Foundation Models extraction, ScreenCaptureKit snapshot capture, EventKit writes, and pasteboard copy.

Rust is intentionally not part of v1. The future Rust boundary mirrors `ActionExtractionRequest` in and `[ActionCandidate]` plus validation diagnostics out.
