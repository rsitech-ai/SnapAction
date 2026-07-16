# SnapAction UI/UX Polish Design

## Goal

Upgrade SnapAction into a simple, clean, professional macOS utility whose
primary workflow—capture, review, and confirm—is immediately understandable.
The redesign must improve hierarchy, motion, accessibility, and adaptive layout
without changing the local-first product boundary or weakening explicit
confirmation before system writes.

The finished interface should feel calm and fast during frequent use. Healthy
systems stay quiet, blockers appear where they can be resolved, and animation
communicates state rather than decorating the window.

## Approved Direction

The approved direction combines four decisions:

- **Primary workflow:** Capture → review → confirm.
- **Visual personality:** Quiet Focus.
- **Color treatment:** Warm Signals.
- **Motion treatment:** Crisp Response.

Three structural directions were considered:

1. **Quiet Focus** keeps the native split-view shell, establishes one dominant
   capture action, and reduces permanent status chrome. This is the selected
   direction because it best supports repeated professional use.
2. **Ambient Studio** uses more luminous depth and expressive material. It was
   rejected because it risks making the operational workflow feel decorative.
3. **Native Workbench** uses a denser multi-pane arrangement. It was rejected
   because the current product does not need persistent inspector-level density.

Three color treatments were considered. Warm Signals was selected to preserve
SnapAction's existing green-and-amber character while restricting color to
active work and semantic state. The interface remains predominantly neutral.

Three motion treatments were considered. Crisp Response was selected because
capture is a frequent keyboard-driven action. Capture begins immediately,
selection changes do not travel or bounce, and newly completed analysis uses a
short opacity transition only.

## Product And Platform Boundaries

- Target platform: macOS 26 or later.
- App shape: SwiftPM executable packaged and launched as
  `dist/SnapAction.app` through `script/build_and_run.sh`.
- Scene structure: `WindowGroup`, `MenuBarExtra`, and `Settings` remain intact.
- Processing remains local-first with Vision OCR and Foundation Models where
  available.
- Screenshot pixels are not persisted.
- OCR text, candidates, timestamps, execution results, and the last clipboard
  text payload retain their current persistence behavior.
- Calendar and Reminder writes continue to require explicit confirmation.
- No cloud model, network dependency, onboarding flow, new action type, or
  release/signing work is added by this pass.

Apple's live Design Resources page listed a macOS 27 UI Kit, SF Symbols 8 beta,
SF Symbols 7, and Icon Composer during the design pass on 2026-07-16. These are
current-reference inputs for spacing, materials, symbols, and hierarchy. The
implementation must remain compatible with SnapAction's macOS 26 deployment
target and must not adopt a newer-only API without availability handling.

## Experience Architecture

### Application Shell

Keep `NavigationSplitView` as the native desktop shell. The sidebar owns
suggestions and history. The detail area owns capture, processing, review, and
contextual recovery. The toolbar contains only frequently useful global actions.

The window remains resizable. The sidebar and detail split must preserve useful
content at the existing 980 × 640 minimum window size and at typical and large
desktop sizes.

### Sidebar

The sidebar contains:

1. A compact product header with model availability summarized in secondary
   text only when that information changes available behavior.
2. Suggested actions, using native list selection rather than gesture-only row
   selection.
3. History, visually secondary to the current suggestions.
4. History search scoped to the sidebar/history context rather than occupying
   the global toolbar.

Candidate rows use one symbol, a concise title, an action-kind label, and a
semantic validation indicator. Selection must work with pointer and keyboard
navigation. Selection does not scale or bounce.

### Toolbar And Commands

The toolbar keeps:

- Capture Screen.
- Import Image.

The Capture menu and existing keyboard shortcuts remain the authoritative paths
for Capture Screen, Demo Capture, and Import Image. Demo Capture moves out of
the primary toolbar because it is a testing/sample path rather than the normal
daily action. Refresh Status is removed from primary chrome; status refresh is
automatic or contextual.

Toolbar actions retain visible labels when space permits and meaningful help and
accessibility labels. Toolbar overflow at smaller widths must remain usable.

### Empty State

The empty detail area presents one calm capture surface:

- **Capture Screen** is the primary action.
- **Import Image** is a secondary action.
- **Demo** is a lower-emphasis secondary/sample action.
- A short privacy line explains that processing stays on the Mac and actions
  require confirmation.

The current two equally dominant empty panels are replaced by a single visual
focal point. Clipboard restore appears only when a saved payload exists and does
not consume permanent empty-state space when unavailable.

### Processing State

Processing reuses the capture surface rather than adding a detached status strip.
It shows:

- A determinate progress indicator when progress is knowable, otherwise a
  compact native indeterminate indicator.
- A concise phase label such as “Reading text” or “Finding actions” when the
  implementation can report the phase truthfully.
- A cancellation control only if the underlying operation is cancellable.

The existing continuously rotating idle halo and ambient moving background are
removed. Processing motion stops as soon as the operation completes.

### Review State

The detail area becomes an adjustable two-pane review workspace:

- **Left:** OCR source text, block count, selection, and copy-friendly text.
- **Right:** selected action title, structured fields, validation state, and the
  action-specific confirmation button.

The selected action pane uses one primary material surface. Clipboard recovery,
validation, and fields are arranged within that hierarchy rather than as nested
glass cards. The confirmation action stays near the fields it affects.

The secondary “Test Gate” control is removed from the normal production-facing
review surface. Confirmation-gate behavior remains covered by automated tests.

When a candidate changes, editable title state synchronizes immediately with
the newly selected candidate. Edits must never leak from one candidate to
another.

### Contextual Status And Recovery

Healthy subsystem statuses do not occupy permanent space. Status appears only
when it changes what the user can do:

- Screen Recording denial appears beside Capture with **Open Settings** and a
  clear restart note if macOS requires relaunch.
- Foundation Models unavailability explains that SnapAction will safely offer
  text/table extraction only.
- Invalid candidates explain why confirmation is disabled.
- Clipboard restore appears only when a saved payload exists.
- Execution success or failure appears near the confirmation action and is also
  accessible to VoiceOver.

Errors remain recoverable and specific. The UI must not report a successful
Calendar, Reminder, or clipboard action unless the executor returned success.

## Component Boundaries

`ContentView` remains the shell and delegates to focused views. The intended
shape is:

- `ContentView`: split-view composition, toolbar, and search placement.
- `SidebarView`: native suggestion selection plus history presentation and
  search.
- `CaptureWorkspaceView`: empty, processing, and capture-blocked states.
- `ReviewWorkspaceView`: OCR/action split and candidate selection response.
- `OCRPreviewView`: source text presentation.
- `ActionReviewView`: editable title, fields, validation, confirmation, and
  result feedback.
- `ContextualStatusView`: actionable permission/model/execution messages.
- Small design-system helpers for semantic material, spacing, and transition
  behavior.

`AppState` remains the single workflow owner. Views call existing named actions
such as capture, import, execute, restore clipboard, refresh permissions, and
open settings. No parallel handlers or duplicate state flags are introduced.

UI-only presentation logic may be extracted into pure, testable semantics when
it decides visibility, tone, labels, or enabled state. I/O, permissions, OCR,
model extraction, history, and system writes remain outside the view layer.

## Visual System

### Color

- Use semantic macOS foreground and background styles for the majority of the
  interface.
- Green is reserved for readiness and successful completion.
- Amber is reserved for active processing and recoverable attention.
- Red is reserved for blocking or failed states.
- Neutral healthy statuses are omitted rather than shown as gray badges.
- Color never carries meaning without a symbol, label, or state text.

### Materials And Depth

- Use native sidebar/titlebar structure.
- Use one material layer per functional level.
- Avoid translucent surfaces nested inside other translucent surfaces.
- Prefer separators, spacing, and alignment over extra borders and shadows.
- Reduce Transparency uses more opaque semantic surfaces.
- Increased Contrast strengthens boundaries without changing information
  hierarchy.

### Typography

- Use San Francisco through SwiftUI system text styles.
- Use weight and spacing before introducing additional font sizes.
- Limit monospaced text to OCR/source content.
- Allow text to wrap where truncation would hide an actionable problem.
- Keep metadata visually secondary but legible under increased contrast.

### Shape And Spacing

- Use consistent radii by role: large workspace surface, medium content group,
  compact control/status element.
- Use a small shared spacing scale rather than independent padding values in
  each view.
- Maintain comfortable pointer targets and keyboard focus rings.
- Avoid decorative scaling on selected rows or cards.

## Motion System

Every animation must communicate feedback, state, or orientation.

- Keyboard-initiated Capture Screen, Demo Capture, and Import Image begin with
  no entrance animation or artificial delay.
- Candidate selection changes immediately; text may use the native content
  transition only when it prevents a visually jarring swap.
- Completed analysis may crossfade into review using a short transition of
  approximately 120–180 ms.
- Success/error feedback may use symbol effects or opacity when supported and
  helpful, without looping.
- Button press feedback remains native and immediate.
- No idle rotation, ambient looping background movement, bounce, large spatial
  travel, or full-window implicit animation is allowed.
- Animation scopes must name the exact state value they observe.
- Reduce Motion replaces any remaining spatial transition with a brief opacity
  change or no animation.

## Accessibility And Input

- Every icon-only or ambiguous macOS control has a meaningful `.help(...)`,
  accessibility label, and hint where needed.
- Suggested-action selection supports pointer, arrow-key, and VoiceOver usage.
- Focus order follows sidebar → source → action fields → confirmation.
- Disabled confirmation includes an accessible explanation through nearby
  validation text.
- Execution result changes are announced accessibly.
- Light and Dark appearances, Reduce Motion, Reduce Transparency, and increased
  contrast must retain readable hierarchy.
- Window resizing and larger accessibility text must not clip the primary
  action, validation message, or recovery control.

## Error And Edge States

The implementation and verification cover:

- No capture yet.
- Processing.
- No suggested actions.
- One and multiple candidates.
- Long OCR text and long candidate titles/fields.
- Foundation Models unavailable with safe text/table fallback.
- Screen Recording denied.
- OCR/import failure.
- Invalid or warning candidate.
- Calendar/Reminder permission denied.
- Successful and failed action execution.
- No clipboard snapshot and available clipboard snapshot.
- Empty history, populated history, and no search matches.

Each state must preserve a clear next action and must not silently fall back to a
different external write.

## Test And End-To-End Verification Strategy

### Automated Logic Checks

Run the complete Swift package test suite. Add focused tests before production
changes for any new pure presentation semantics, selection synchronization, or
state-to-visibility rules. Existing safety tests for explicit confirmation,
validation, persistence recovery, metadata privacy, clipboard restoration, and
fallback extraction remain green.

### Build And Bundle Checks

Use the project entry points:

```bash
swift test
swift build
script/build_and_run.sh --verify
```

Verification is performed against `dist/SnapAction.app`, not a raw
`swift run` GUI process.

### Interaction Sweep

Exercise every reachable enabled control and record verified, failed, blocked,
or not-applicable status for:

- Empty-state Capture Screen, Import Image, and Demo.
- Toolbar Capture Screen and Import Image.
- Capture menu commands and Command-Shift-1, Command-Shift-2, and
  Command-Shift-I shortcuts.
- Suggested-action pointer and keyboard selection.
- Editable title and candidate switching.
- Confirmation button enabled and disabled paths.
- Clipboard copy and Restore Clipboard.
- History list rendering and history search, including the no-match state.
  History entries remain read-only in this pass and are not presented as
  controls unless an explicit selection behavior is implemented.
- Settings permission request, privacy-settings routing, retention stepper, and
  window dismissal/reopening.
- Menu bar Capture Screen, Demo, Import Image, Settings, and Quit where safe.
- Sidebar resizing, review split resizing, minimum/typical/large window sizes,
  and toolbar overflow.

Real Calendar or Reminder writes use clearly disposable test data and require an
explicit local confirmation. If permission, account, or environment constraints
prevent a safe write, record the exact external blocker and verify the denied or
unavailable recovery path instead of claiming success.

### Visual And Accessibility Sweep

Capture before/after screenshots for empty, processing, populated review, and
permission-blocked states where reachable. Inspect Light and Dark appearance,
Reduce Motion, Reduce Transparency, increased contrast, keyboard focus, long
content, and adaptive sizing. Review the final motion diff against the motion
standards and verify it in the foreground app rather than from code alone.

### Runtime Signals

After primary workflows, review SnapAction's structured logs for crashes,
uncaught errors, repeated failures, misleading success messages, and private
content. Logs must not contain screenshot pixels or raw OCR text.

## Completion Bar

The pass is complete only when:

- The approved hierarchy, Warm Signals treatment, and Crisp Response motion are
  visible in the built app.
- All automated tests and the app-bundle verification pass.
- Every reachable enabled control in the audited surface is exercised or given
  a truthful blocked/not-applicable result.
- Empty, processing, review, error, permission, and recovery states have runtime
  evidence.
- Minimum, typical, and large window sizes remain usable.
- Accessibility appearance/motion variants show no blocking regression.
- Motion review has no high-frequency, looping, unscoped, or reduced-motion
  violations.
- Runtime logs show no unexplained crash or error signal.

The final readiness label must be the weakest truthful label supported by this
evidence. A clean build alone is not sufficient.
