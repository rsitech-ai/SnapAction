# SnapAction UI/UX Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved capture-first Quiet Focus interface with Warm Signals, Crisp Response motion, contextual recovery, adaptive native Mac layout, and real end-to-end verification through `dist/SnapAction.app`.

**Architecture:** Keep `AppState` as the single workflow owner and `NavigationSplitView` as the desktop shell. Split the current oversized `ContentView.swift` into root composition, sidebar, capture workspace, and review workspace files; add a small pure presentation-semantic layer in `SnapActionCore`; use native materials and controls before custom glass; keep I/O and permissions outside views.

**Tech Stack:** Swift 6.2+, SwiftUI, Observation, AppKit, ScreenCaptureKit, Vision, Foundation Models, EventKit, Swift Testing, SwiftPM macOS executable bundled by `script/build_and_run.sh`.

## Global Constraints

- Target macOS 26 or later; newer APIs require availability handling.
- Keep processing local-first and add no network or cloud-model dependency.
- Do not persist screenshot pixels or add raw OCR text to logs.
- Preserve explicit confirmation before Calendar or Reminder writes.
- Preserve `WindowGroup`, `MenuBarExtra`, `Settings`, existing menu commands, and existing shortcuts.
- Use native semantic colors, materials, focus, selection, and controls before custom chrome.
- Healthy subsystem state stays quiet; actionable blockers appear in context.
- No idle looping motion, selection scaling, bounce, full-window implicit animation, or keyboard-triggered entrance animation.
- Reduce Motion, Reduce Transparency, increased contrast, Light/Dark appearance, and minimum/typical/large windows are verification targets.
- Launch and test the GUI as `dist/SnapAction.app`, never as a raw `swift run` process.
- No real Calendar or Reminder write during E2E without action-time user confirmation.

---

## File Map

- Modify `Sources/SnapActionCore/DisplaySemantics.swift`: add pure workspace phase and contextual visibility semantics.
- Modify `Tests/SnapActionCoreTests/DisplaySemanticsTests.swift`: test phase precedence and contextual visibility.
- Modify `Sources/SnapActionApp/AppState.swift`: expose typed presentation inputs, typed processing copy, and contextual permission/fallback state without duplicating workflow logic.
- Modify `Sources/SnapActionApp/LocalFoundationModelsExtractor.swift`: expose typed model availability for presentation without parsing status text.
- Modify `Sources/SnapActionApp/ContentView.swift`: retain root split composition and concise toolbar only.
- Create `Sources/SnapActionApp/SidebarView.swift`: native candidate selection, model fallback context, and history/search presentation.
- Create `Sources/SnapActionApp/CaptureWorkspaceView.swift`: empty, processing, permission-blocked, and no-results states.
- Create `Sources/SnapActionApp/ReviewWorkspaceView.swift`: OCR source and selected-action review panes.
- Modify `Sources/SnapActionApp/DesignSystem.swift`: shared spacing/radius tokens, restrained material surface, tone mapping, and accessibility-aware styling.
- Replace `Sources/SnapActionApp/AmbientSignalBackground.swift`: remove looping/ornamental motion and retain only a static Warm Signals backdrop plus confidence gauge.
- Modify `Sources/SnapActionApp/SettingsView.swift`: grouped, adaptive, contextual settings with explicit help and accessibility copy.
- Modify `Sources/SnapActionApp/SnapActionApp.swift`: keep scenes/commands stable and standardize action naming.
- Modify `docs/production-plan.md`: record the implemented UI gate, commands, and current evidence.
- Create `docs/e2e-audit-2026-07-16-ui-polish.md`: scenario matrix, screenshots, logs, findings, fixes, blockers, and readiness label.

---

### Task 1: Add Pure Workspace Presentation Semantics

**Files:**
- Modify: `Sources/SnapActionCore/DisplaySemantics.swift`
- Test: `Tests/SnapActionCoreTests/DisplaySemanticsTests.swift`

**Interfaces:**
- Consumes: `isProcessing: Bool`, `hasDocument: Bool`, `hasClipboardSnapshot: Bool`, `screenCaptureAllowed: Bool`, `modelFallbackActive: Bool`.
- Produces: `WorkspacePhase.resolve(isProcessing:hasDocument:)`, `WorkspacePresentation.showsClipboardRestore`, `WorkspacePresentation.showsCapturePermissionRecovery`, and `WorkspacePresentation.showsModelFallbackNotice`.

- [ ] **Step 1: Write the failing presentation tests**

Append these tests:

```swift
@Test func workspacePhasePrioritizesProcessingThenReviewThenCapture() {
    #expect(WorkspacePhase.resolve(isProcessing: true, hasDocument: true) == .processing)
    #expect(WorkspacePhase.resolve(isProcessing: false, hasDocument: true) == .review)
    #expect(WorkspacePhase.resolve(isProcessing: false, hasDocument: false) == .capture)
}

@Test func workspacePresentationShowsOnlyContextualRecovery() {
    let healthy = WorkspacePresentation(
        phase: .capture,
        hasClipboardSnapshot: false,
        screenCaptureAllowed: true,
        modelFallbackActive: false
    )
    let blocked = WorkspacePresentation(
        phase: .capture,
        hasClipboardSnapshot: true,
        screenCaptureAllowed: false,
        modelFallbackActive: true
    )

    #expect(!healthy.showsClipboardRestore)
    #expect(!healthy.showsCapturePermissionRecovery)
    #expect(!healthy.showsModelFallbackNotice)
    #expect(blocked.showsClipboardRestore)
    #expect(blocked.showsCapturePermissionRecovery)
    #expect(blocked.showsModelFallbackNotice)
}
```

- [ ] **Step 2: Run the focused tests and prove RED**

Run:

```bash
swift test --filter 'workspacePhase|workspacePresentation'
```

Expected: compilation fails because `WorkspacePhase` and `WorkspacePresentation` do not exist.

- [ ] **Step 3: Implement the minimal pure semantics**

Append this implementation to `DisplaySemantics.swift`:

```swift
public enum WorkspacePhase: Equatable, Sendable {
    case capture
    case processing
    case review

    public static func resolve(isProcessing: Bool, hasDocument: Bool) -> WorkspacePhase {
        if isProcessing { return .processing }
        if hasDocument { return .review }
        return .capture
    }
}

public struct WorkspacePresentation: Equatable, Sendable {
    public let phase: WorkspacePhase
    public let hasClipboardSnapshot: Bool
    public let screenCaptureAllowed: Bool
    public let modelFallbackActive: Bool

    public init(
        phase: WorkspacePhase,
        hasClipboardSnapshot: Bool,
        screenCaptureAllowed: Bool,
        modelFallbackActive: Bool
    ) {
        self.phase = phase
        self.hasClipboardSnapshot = hasClipboardSnapshot
        self.screenCaptureAllowed = screenCaptureAllowed
        self.modelFallbackActive = modelFallbackActive
    }

    public var showsClipboardRestore: Bool { hasClipboardSnapshot }
    public var showsCapturePermissionRecovery: Bool { !screenCaptureAllowed }
    public var showsModelFallbackNotice: Bool { modelFallbackActive }
}
```

- [ ] **Step 4: Run focused and full tests and prove GREEN**

Run:

```bash
swift test --filter 'workspacePhase|workspacePresentation'
swift test
```

Expected: the two new tests and all existing tests pass.

- [ ] **Step 5: Commit the semantic slice**

```bash
git add Sources/SnapActionCore/DisplaySemantics.swift Tests/SnapActionCoreTests/DisplaySemanticsTests.swift
git commit -m "feat: add workspace presentation semantics"
```

---

### Task 2: Expose Typed App Presentation State

**Files:**
- Modify: `Sources/SnapActionApp/AppState.swift`
- Modify: `Sources/SnapActionApp/ScreenCaptureService.swift`
- Modify: `Sources/SnapActionApp/LocalFoundationModelsExtractor.swift`

**Interfaces:**
- Consumes: `ScreenCaptureService.hasPermission`, `LocalFoundationModelsExtractor.isAvailable`, existing document/processing/clipboard state.
- Produces: `AppState.workspacePresentation: WorkspacePresentation`, `AppState.processingLabel: String`, and `AppState.modelFallbackActive: Bool`.

- [ ] **Step 1: Add a typed permission boundary**

Implement this property and route the existing summary through it:

```swift
var hasPermission: Bool {
    CGPreflightScreenCaptureAccess()
}

func permissionSummary() -> String {
    hasPermission ? "Screen Recording allowed" : "Screen Recording needed"
}
```

- [ ] **Step 2: Add a typed model-availability boundary**

Add this property beside `availabilitySummary()` and use the same system switch:

```swift
static var isAvailable: Bool {
    #if canImport(FoundationModels)
    if case .available = SystemLanguageModel.default.availability {
        return true
    }
    #endif
    return false
}
```

- [ ] **Step 3: Add presentation properties to `AppState`**

Add:

```swift
var modelFallbackActive: Bool {
    !LocalFoundationModelsExtractor.isAvailable
}

var workspacePresentation: WorkspacePresentation {
    WorkspacePresentation(
        phase: .resolve(isProcessing: isProcessing, hasDocument: currentDocument != nil),
        hasClipboardSnapshot: lastClipboardSnapshot != nil,
        screenCaptureAllowed: screenCaptureService.hasPermission,
        modelFallbackActive: modelFallbackActive
    )
}

var processingLabel: String {
    currentDocument == nil ? "Reading the capture" : "Finding safe actions"
}
```

Keep the existing status strings for settings and log-compatible copy, but stop using them as view-state parsers anywhere else.

- [ ] **Step 4: Build after the state-boundary change**

Run:

```bash
swift build
```

Expected: build completes without warnings or concurrency errors.

- [ ] **Step 5: Commit the state slice**

```bash
git add Sources/SnapActionApp/AppState.swift Sources/SnapActionApp/ScreenCaptureService.swift Sources/SnapActionApp/LocalFoundationModelsExtractor.swift
git commit -m "refactor: expose typed workspace state"
```

---

### Task 3: Refactor The Root And Sidebar Into Native Desktop Components

**Files:**
- Modify: `Sources/SnapActionApp/ContentView.swift`
- Create: `Sources/SnapActionApp/SidebarView.swift`
- Modify: `Sources/SnapActionApp/SnapActionApp.swift`

**Interfaces:**
- Consumes: `AppState.candidates`, `selectedCandidateID`, `filteredHistory`, capture/import actions, and history search binding.
- Produces: stable native list selection, a compact toolbar, sidebar-scoped search, and unchanged menu/shortcut handlers.

- [ ] **Step 1: Replace gesture-only candidate selection with native `List(selection:)`**

Move sidebar types to `SidebarView.swift` and structure them as:

```swift
struct SidebarView: View {
    let appState: AppState

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.selectedCandidateID) {
            modelSection
            suggestionsSection
            historySection
        }
        .listStyle(.sidebar)
        .searchable(text: $appState.historySearchText, prompt: "Search history")
        .navigationTitle("SnapAction")
    }
}
```

Candidate rows use `.tag(candidate.id)`, one leading action symbol, one title, one secondary kind label, and one semantic validation symbol. Remove `.onTapGesture`, selection scale, and row-level implicit animation.

- [ ] **Step 2: Reduce `ContentView` to stable composition and two toolbar actions**

The root body becomes:

```swift
NavigationSplitView {
    SidebarView(appState: appState)
} detail: {
    DetailView(appState: appState)
}
.toolbar {
    ToolbarItemGroup {
        Button(action: appState.captureScreenSnapshot) {
            Label("Capture Screen", systemImage: "rectangle.dashed")
        }
        .help("Capture the first display")

        Button(action: appState.importImageForOCR) {
            Label("Import Image", systemImage: "photo.badge.magnifyingglass")
        }
        .help("Import an image for text recognition")
    }
}
```

Remove Demo and Refresh Status from the toolbar. Keep Demo in `CommandMenu("Capture")` and `MenuBarExtra`.

- [ ] **Step 3: Standardize command labels without changing handlers**

Use “Capture Screen”, “Demo Capture”, and “Import Image” consistently across commands, menu-bar items, help text, and settings. Keep the existing shortcuts exactly: Command-Shift-1, Command-Shift-2, and Command-Shift-I.

- [ ] **Step 4: Build and run the full test suite**

Run:

```bash
swift build
swift test
```

Expected: build and all tests pass; sidebar types are extracted and the root body contains only split composition and toolbar code. Existing detail types remain in `ContentView.swift` until Task 5 replaces them.

- [ ] **Step 5: Commit the native shell slice**

```bash
git add Sources/SnapActionApp/ContentView.swift Sources/SnapActionApp/SidebarView.swift Sources/SnapActionApp/SnapActionApp.swift
git commit -m "refactor: simplify SnapAction desktop shell"
```

---

### Task 4: Build The Capture-First Workspace And Contextual Recovery

**Files:**
- Create: `Sources/SnapActionApp/CaptureWorkspaceView.swift`
- Create: `Sources/SnapActionApp/WorkspaceView.swift`
- Modify: `Sources/SnapActionApp/AppState.swift`

**Interfaces:**
- Consumes: `workspacePresentation`, `processingLabel`, capture/import/demo actions, permission request/settings actions, model fallback state, and last clipboard snapshot.
- Produces: stable capture/processing/review container with contextual blockers and no permanent health strip.

- [ ] **Step 1: Create a stable workspace container**

Implement:

```swift
struct WorkspaceView: View {
    let appState: AppState

    var body: some View {
        Group {
            switch appState.workspacePresentation.phase {
            case .capture:
                CaptureWorkspaceView(appState: appState)
            case .processing:
                ProcessingWorkspaceView(label: appState.processingLabel)
            case .review:
                DetailView(appState: appState)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { WarmSignalBackdrop() }
        .navigationTitle("Review")
        .transition(.opacity)
        .animation(
            appState.workspacePresentation.phase == .review
                ? .easeOut(duration: 0.16)
                : nil,
            value: appState.workspacePresentation.phase
        )
    }
}
```

The transition is scoped only to completed workspace phase changes. Capture commands themselves do not animate or delay. `DetailView` is the existing review implementation and remains temporarily available until Task 5 replaces it with `ReviewWorkspaceView`.

- [ ] **Step 2: Build the single-focus empty state**

`CaptureWorkspaceView` contains one large capture surface with:

```swift
Button(action: appState.captureScreenSnapshot) {
    Label("Capture Screen", systemImage: "viewfinder")
}
.buttonStyle(.glassProminent)
.controlSize(.large)
.help("Capture the first display and find actions")
```

Add secondary Import Image and Demo Capture buttons, a concise local-processing/privacy sentence, and Restore Clipboard only when `showsClipboardRestore` is true.

- [ ] **Step 3: Add contextual recovery**

When `showsCapturePermissionRecovery` is true, show a warning-labelled inline group with **Request Access** and **Open Privacy Settings**. When `showsModelFallbackNotice` is true, show an informational line explaining that only text/table extraction is available. Do not render healthy permission/model badges.

- [ ] **Step 4: Replace idle/looping progress with native processing**

`ProcessingWorkspaceView` uses `ProgressView()` plus the truthful `processingLabel`. It has no custom rotation, no ambient loop, and no cancellation control because the current workflow is not cancellable.

- [ ] **Step 5: Build, test, and commit**

Run:

```bash
swift build
swift test
```

Expected: build and tests pass; the old permanent `StatusStrip` is no longer referenced.

Commit:

```bash
git add Sources/SnapActionApp/AppState.swift Sources/SnapActionApp/WorkspaceView.swift Sources/SnapActionApp/CaptureWorkspaceView.swift
git commit -m "feat: add capture-first workspace states"
```

---

### Task 5: Build The Adjustable Review Workspace

**Files:**
- Create: `Sources/SnapActionApp/ReviewWorkspaceView.swift`
- Modify: `Sources/SnapActionApp/ContentView.swift`
- Modify: `Sources/SnapActionApp/WorkspaceView.swift`

**Interfaces:**
- Consumes: current OCR document, selected candidate, candidate selection, execute action, clipboard restore, and execution status.
- Produces: adjustable OCR/action split, candidate-safe title draft, inline validation, contextual result feedback, and one production confirmation action.

- [ ] **Step 1: Extract the OCR pane**

Implement an `OCRPreviewView` with a header, block count, selectable monospaced text, and a single restrained material surface. Long content scrolls without clipping.

- [ ] **Step 2: Implement candidate-safe title editing**

Use a dedicated `ActionReviewView`:

```swift
struct ActionReviewView: View {
    let appState: AppState
    let candidate: ActionCandidate
    @State private var editedTitle: String

    init(appState: AppState, candidate: ActionCandidate) {
        self.appState = appState
        self.candidate = candidate
        _editedTitle = State(initialValue: candidate.title)
    }

    var body: some View {
        actionContent
            .id(candidate.id)
    }
}
```

At the parent call site, key the review view by `candidate.id` so selecting another candidate resets the draft to that candidate's title. Do not animate the selection change.

- [ ] **Step 3: Simplify fields, validation, and confirmation**

Render fields as aligned label/value rows without one card per field. Show validation directly above the action button. Keep one action-specific primary button (`Create Reminder`, `Create Event`, or `Copy Text`) and remove the visible Test Gate button. Disabled confirmation remains paired with the validation explanation.

- [ ] **Step 4: Keep clipboard and execution feedback contextual**

Show Restore Clipboard only when a snapshot exists. Show `statusMessage` near the confirmation area after an execution attempt, with success/warning/error tone derived from actual result state; never infer success from button activation.

- [ ] **Step 5: Use an adjustable native split**

Compose the review workspace with `HSplitView` and minimum widths that remain usable inside the 980 × 640 window:

```swift
HSplitView {
    OCRPreviewView(document: appState.currentDocument)
        .frame(minWidth: 300, idealWidth: 420)
    actionPane
        .frame(minWidth: 360, idealWidth: 480)
}
```

Update the `.review` case in `WorkspaceView` to instantiate `ReviewWorkspaceView(appState:)`, then remove the superseded detail/review types from `ContentView.swift`.

- [ ] **Step 6: Build, test, and commit**

Run:

```bash
swift build
swift test
```

Expected: build and tests pass; no visible Test Gate control remains; candidate selection preserves correct title identity.

Commit:

```bash
git add Sources/SnapActionApp/ReviewWorkspaceView.swift Sources/SnapActionApp/ContentView.swift Sources/SnapActionApp/WorkspaceView.swift
git commit -m "feat: focus the action review workspace"
```

---

### Task 6: Apply Warm Signals, Crisp Response, And Settings Polish

**Files:**
- Modify: `Sources/SnapActionApp/DesignSystem.swift`
- Modify: `Sources/SnapActionApp/AmbientSignalBackground.swift`
- Modify: `Sources/SnapActionApp/SettingsView.swift`

**Interfaces:**
- Consumes: `DisplayTone`, accessibility environment values, existing settings actions and values.
- Produces: shared spacing/radius tokens, one restrained material modifier, static Warm Signals backdrop, accessible settings groups, and zero looping custom motion.

- [ ] **Step 1: Replace ad hoc tokens with a compact scale**

Define:

```swift
enum SnapActionDesign {
    static let spacingXS: CGFloat = 6
    static let spacingS: CGFloat = 10
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let workspaceRadius: CGFloat = 22
    static let groupRadius: CGFloat = 14
}
```

Replace `SnapMetricPill` and interactive glass-panel scaling with a noninteractive `snapSurface(tone:cornerRadius:)` modifier. Use semantic tint only for warning/success/error context.

- [ ] **Step 2: Replace the ambient drawing with a static, accessibility-aware backdrop**

Implement `WarmSignalBackdrop` using two low-opacity static gradients and read `@Environment(\.accessibilityReduceTransparency)` to switch to a plain semantic background. Delete `ProcessingHalo`; retain `ConfidenceGauge` without animation.

- [ ] **Step 3: Audit animation scopes**

Search:

```bash
rg -n 'withAnimation|\.animation|repeatForever|rotationEffect|scaleEffect|transition' Sources/SnapActionApp
```

Expected after fixes: no `repeatForever`, no idle rotation, no selection scaling, and only phase/result transitions explicitly scoped to a value.

- [ ] **Step 4: Polish Settings**

Group Capture Access, Intelligence, and History in the native `Form`. Give Request Access and Open Privacy Settings explicit `.help(...)` text, allow long status copy to wrap, preserve the retention Stepper range `1...90`, and avoid fixed nested material backgrounds.

- [ ] **Step 5: Build, test, and commit**

Run:

```bash
swift build
swift test
```

Expected: build and tests pass; motion search meets the expected constraints.

Commit:

```bash
git add Sources/SnapActionApp/DesignSystem.swift Sources/SnapActionApp/AmbientSignalBackground.swift Sources/SnapActionApp/SettingsView.swift
git commit -m "style: apply quiet focus visual system"
```

---

### Task 7: Verify The Built App And Close Runtime Findings

**Files:**
- Modify: `docs/production-plan.md`
- Create: `docs/e2e-audit-2026-07-16-ui-polish.md`
- Create evidence under: `.artifacts/ui-polish-2026-07-16/` (gitignored or excluded from commits)
- Modify app/test files only when a verified finding requires a fix.

**Interfaces:**
- Consumes: `script/build_and_run.sh`, `dist/SnapAction.app`, app menus/toolbar/settings, Computer Use for native UI, screenshots, and unified logs.
- Produces: completed scenario matrix, before/after evidence, fix/retest records, truthful blockers, and the weakest supported readiness label.

- [ ] **Step 1: Run fresh automated and bundle verification**

Run:

```bash
swift test
swift build
script/build_and_run.sh --verify
```

Expected: all tests pass, the bundle launches, and `pgrep -x SnapAction` succeeds.

- [ ] **Step 2: Capture the baseline runtime state and logs**

Verify the foreground SnapAction window, capture empty-state and populated-demo screenshots, and collect a bounded unified-log excerpt filtered to subsystem `com.s1kor.snapaction`. Store artifact paths in the audit report; do not commit screenshots unless explicitly useful.

- [ ] **Step 3: Execute the interaction matrix**

Using real native UI interaction, verify and record:

1. Empty-state Capture Screen, Import Image cancel path, and Demo Capture.
2. Toolbar Capture Screen and Import Image.
3. Capture menu commands and Command-Shift-1/2/I shortcuts.
4. Candidate pointer and keyboard selection, title editing, and candidate switching.
5. Disabled validation path and safe Copy Text confirmation.
6. Clipboard persistence and Restore Clipboard across relaunch.
7. History search populated/no-match/cleared states.
8. Settings access controls, Open Privacy Settings up to the pre-navigation safety boundary, retention Stepper, close, and reopen.
9. Menu bar Capture Screen, Demo Capture, Import Image cancel path, Settings, and Quit/relaunch.
10. Sidebar and review split resizing plus minimum, typical, and large window sizes.

Record each row as verified, failed, blocked, or not applicable. Do not perform a real Calendar or Reminder write without action-time user confirmation.

- [ ] **Step 4: Execute visual and accessibility variants**

Verify Light and Dark appearances, Reduce Motion, Reduce Transparency, increased contrast where accessible, keyboard focus visibility, long OCR/title content, toolbar overflow, and no clipped recovery controls. Capture before/after evidence for empty, processing, review, and permission-blocked states where reachable.

- [ ] **Step 5: Run the strict motion review**

Review every remaining animation against `review-animations` and its standards. The required verdict is Approve: no high-frequency animation, no UI duration over 300 ms, no looping idle motion, no unscoped implicit animation, and Reduce Motion coverage present.

- [ ] **Step 6: Fix and re-verify every runtime finding**

For each failure, capture the exact UI path or log, implement the smallest fix, rerun the failed interaction and its parent workflow, then rerun `swift test` and `script/build_and_run.sh --verify` before closing the finding.

- [ ] **Step 7: Update durable repo evidence**

Complete `docs/e2e-audit-2026-07-16-ui-polish.md` with commands, scenario matrix, screenshots/log paths, findings/fixes, blocked external writes, and the weakest truthful readiness label. Update `docs/production-plan.md` with the implemented UI gate and remaining non-UI blockers.

- [ ] **Step 8: Run verification-before-completion and commit evidence**

Run:

```bash
git diff --check
swift test
swift build
script/build_and_run.sh --verify
git status --short
```

Expected: clean checks, app running from the new bundle, only intentional report/plan/source changes, and all audit claims backed by fresh evidence.

Commit:

```bash
git add docs/production-plan.md docs/e2e-audit-2026-07-16-ui-polish.md
git commit -m "docs: record SnapAction UI polish verification"
```

---

## Plan Self-Review

- Spec coverage: capture-first hierarchy, native selection, contextual health,
  review layout, Warm Signals, Crisp Response, accessibility, edge states,
  bundle launch, interaction sweep, logs, screenshots, and truthful blockers
  each have an implementation or verification task.
- Placeholder scan: no TBD/TODO/“implement later” steps remain.
- Type consistency: `WorkspacePhase`, `WorkspacePresentation`,
  `workspacePresentation`, `WarmSignalBackdrop`, `WorkspaceView`,
  `CaptureWorkspaceView`, and `ReviewWorkspaceView` are introduced before use.
- Scope check: the plan changes one coherent native UI system and its evidence;
  it adds no new product action, cloud dependency, signing, or release scope.
