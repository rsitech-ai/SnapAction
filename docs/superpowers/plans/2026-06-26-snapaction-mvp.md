# SnapAction MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local-only macOS SwiftPM MVP that turns OCR text into confirmed Reminder, Calendar, or text/table actions.

**Architecture:** SwiftUI owns desktop UI, capture flow, permission surfaces, and user confirmation. SnapActionCore owns OCR normalization, AI extraction contracts, deterministic validation, execution protocols, and metadata-only history so the future Rust parser can replace the validator boundary cleanly.

**Tech Stack:** SwiftPM, SwiftUI, AppKit, Vision, ScreenCaptureKit, Foundation Models, EventKit, XCTest.

---

### Task 1: Project Foundation
- [x] Initialize git and branch `feat/andrzej_snapaction-mvp`.
- [x] Add SwiftPM library, executable, tests, Codex run config, and reflection.

### Task 2: Core Behavior
- [x] Write failing tests for OCR ordering, AI fallback, validation, history privacy, and fake execution gates.
- [x] Implement the smallest core library that passes those tests.

### Task 3: macOS Shell
- [x] Add a SwiftUI app with `WindowGroup`, `MenuBarExtra`, `Settings`, command shortcuts, and a stub/demo capture path.
- [x] Add platform services for Vision OCR, Foundation Models extraction, EventKit execution, pasteboard copy, and screen capture where SwiftPM can compile them.

### Task 4: Verification and Docs
- [x] Run `swift test`, `swift build`, and `script/build_and_run.sh --verify`.
- [x] Add README install/run/permission notes and close the reflection with actual evidence.

### Task 5: Native Future UI Polish
- [x] Add test-backed display semantics for validation tone, confidence band, and executability.
- [x] Add grouped Liquid Glass panels, animated status rail, live empty states, confidence gauges, and searchable history while preserving native macOS split-view structure.
- [x] Verify with `swift build`, `swift test`, `script/build_and_run.sh --verify`, and a short launch smoke.
