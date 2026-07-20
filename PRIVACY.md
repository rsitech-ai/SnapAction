# Privacy

This document describes the behavior of the source, local community builds, and the RSI Tech direct-download release. Questions may be sent to [info@rsitech.ai](mailto:info@rsitech.ai). It is not an App Store privacy disclosure.

## Processing

SnapAction processes screen captures and imported images locally with Apple system frameworks. The application source does not contain a network client and does not send screenshot pixels, OCR text, extracted candidates, action history, or clipboard content to a network service.

Screen images and OCR candidates are held for the active workflow and are not written to the app's local history. Confirming an action can write to Apple Reminders, Apple Calendar, or the macOS pasteboard, depending on the action the user chooses.

## Local storage

- History contains only the action timestamp, title, action kind, and a bounded outcome. It excludes screenshot pixels, OCR text, structured candidate fields, EventKit identifiers, and clipboard payloads. Retention is configurable from 1 to 90 days and history can be cleared in Settings.
- The clipboard recovery cache contains the last confirmed text or table payload. It expires after seven days and can be cleared independently in Settings.
- History and clipboard files are stored under `~/Library/Application Support/SnapAction/`. The app restricts these files and their containing directory to the current user where the operating system supports those permissions.
- Operational logs contain bounded state, counts, result kinds, and error domain/code information. They do not intentionally log captured or extracted content.

## Permissions

- Screen Recording is requested for screen capture. Importing an image and the built-in demo do not require this permission.
- Calendar write-only access is requested only when a reviewed Calendar action is confirmed.
- Reminders access is requested only when a reviewed Reminder action is confirmed. EventKit currently requires full Reminders access for this write path.
- System-wide keyboard monitoring may require Accessibility permission, depending on macOS privacy settings. Focused menu commands remain available without system-wide monitoring.

Permission denial is handled as a recoverable result and is not recorded as a successful action.

## Distribution boundary

Local community builds are ad-hoc signed with a neutral identity. The official direct-download archive uses `ai.rsitech.snapaction` and a Developer ID Application signature; each release states its notarization status. Direct-download builds are not sandboxed or App Store packages. No analytics, advertising SDK, crash-reporting SDK, or third-party Swift package is included in the current source manifest.

Do not disclose suspected vulnerabilities in public issues. Follow [SECURITY.md](SECURITY.md) for private GitHub advisory and email reporting routes.
