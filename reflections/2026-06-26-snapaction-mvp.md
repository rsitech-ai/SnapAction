# Reflection Entry

## Task
- **ID/Title:** SnapAction MVP
- **Date:** 2026-06-26
- **Scope:** greenfield macOS SwiftPM app

## Plan and Risks
- **Planned approach:** Build a package-first macOS app with a testable core library, SwiftUI shell, local-only OCR/AI/action flow, and metadata-only history.
- **Top failure hypotheses:** Foundation Models API surface differs from assumptions; SwiftPM app bundle limitations affect permissions; EventKit APIs require app-bundle context for real writes.
- **Success criteria:** `swift test`, `swift build`, and `script/build_and_run.sh --verify` pass; core actions are gated by validators and explicit confirmation; README documents manual permission smoke tests.

## Candidate Attempts
| Candidate | Summary | Outcome | Signals | Why selected / rejected |
|---|---|---|---|---|
| A | SwiftPM first with testable Swift core and real platform adapters where available. | Selected | Matches requested app shape and fastest reproducible build. | Preserves future Xcode migration while keeping tests simple. |
| B | Xcode project first with app bundle entitlements wired immediately. | Rejected | More moving parts before core behavior exists. | Better later for signing/permissions, worse for initial TDD slice. |

## Reflection
- **Failure modes observed:** Initial red run failed at empty SwiftPM targets before reaching missing core API; Swift 6 rejected a non-Sendable `ISO8601DateFormatter` stored in a `Sendable` validator.
- **Root cause:** SwiftPM requires non-empty targets, and Foundation formatter classes are not Sendable.
- **Fix that resolved it:** Added inert target scaffolding before the real red run, then moved ISO-8601 formatters into local parsing scope.
- **What improved score/quality:** Core behavior was pinned by Swift Testing before implementation; platform APIs were compile-probed before being wired into the app.
- **Useful command-level evidence:** `swift test` passed with 7 tests after the UI polish pass; `swift build` and `script/build_and_run.sh --verify` passed; short `swift run SnapAction` launch smoke built and started the product without launch errors before termination.
- **Branch comparison insight (if multiple attempts):** Not applicable.

## Reusable Lesson
- **Pattern that worked:** Put product contracts in a pure SwiftPM library first, then keep platform services narrow and replaceable.
- **UI pattern that worked:** Use core display semantics to drive confidence, tone, and executability, then keep SwiftUI polish as small native surfaces rather than custom app chrome.
- **Pattern to avoid:** Storing Foundation reference formatters in `Sendable` value types.
- **Where to apply next:** Future Rust parser integration can use the existing request/candidate boundary without changing the UI flow.

## Decision
- **Final chosen approach:** SwiftPM-first local-only MVP.
- **Commit/rollback decision:** Keep work on `feat/andrzej_snapaction-mvp`.
- **Next step / follow-up:** Move to an Xcode app bundle only when signing, entitlements, and packaged permission strings become the next blocker.
