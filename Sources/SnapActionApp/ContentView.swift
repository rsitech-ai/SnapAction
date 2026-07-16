import SnapActionCore
import SwiftUI

struct ContentView: View {
    let appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationSplitView {
            SidebarView(appState: appState)
        } detail: {
            WorkspaceView(appState: appState)
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appState.refreshPermissionStatus()
            }
        }
    }
}

struct DetailView: View {
    let appState: AppState

    var body: some View {
        HSplitView {
            OCRPreview(document: appState.currentDocument)
                .frame(minWidth: 360)
            CandidateDetailView(appState: appState, candidate: appState.selectedCandidate)
                .frame(minWidth: 420)
        }
    }
}

struct OCRPreview: View {
    let document: OCRDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("OCR Stream", systemImage: "text.viewfinder")
                    .font(.headline)
                Spacer()
                if let document {
                    Text("\(document.blocks.count) blocks")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            ZStack(alignment: .topLeading) {
                ScrollView {
                    Text(document?.normalizedText.isEmpty == false ? document!.normalizedText : "Capture the screen or import an image. SnapAction will turn visual text into clean, typed actions.")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
                if document == nil {
                    EmptyCapturePulse()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .snapGlassPanel(cornerRadius: 18)
        }
        .padding(.leading, 18)
        .padding(.vertical, 14)
    }
}

struct CandidateDetailView: View {
    let appState: AppState
    let candidate: ActionCandidate?
    @State private var editedTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let candidate {
                VStack(alignment: .leading, spacing: 18) {
                    CandidateHeader(candidate: candidate)
                    ClipboardShelf(appState: appState)
                    TextField("Title", text: $editedTitle)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            editedTitle = candidate.title
                        }
                    FieldList(candidate: candidate)
                    ValidationPanel(state: candidate.validationState)
                    HStack {
                        Button {
                            appState.execute(candidate: candidate, editedTitle: editedTitle, confirmed: true)
                        } label: {
                            Label(candidate.kind.confirmLabel, systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(!candidate.isExecutable)
                        .accessibilityLabel(candidate.kind.confirmLabel)
                        .help(candidate.kind.confirmLabel)

                        Button {
                            appState.execute(candidate: candidate, editedTitle: editedTitle, confirmed: false)
                        } label: {
                            Label("Test Gate", systemImage: "lock")
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Test Gate")
                        .help("Verify the confirmation gate without writing")
                    }
                }
                .padding(18)
                .snapGlassPanel(tone: candidate.validationState.displayTone, interactive: true, cornerRadius: 24)
                .transition(.scale(scale: 0.98).combined(with: .opacity))
                Spacer()
            } else {
                EmptyReviewSurface(appState: appState)
            }
        }
        .padding(.trailing, 18)
        .padding(.vertical, 14)
        .id(candidate?.id)
        .animation(.smooth(duration: 0.28), value: candidate?.id)
    }
}

struct CandidateHeader: View {
    let candidate: ActionCandidate

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Label(candidate.kind.displayName, systemImage: candidate.kind.symbolName)
                    .font(.title3.weight(.semibold))
                Text(candidate.confidenceBand.label + " confidence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ConfidenceGauge(value: candidate.confidence, tone: candidate.validationState.displayTone.color)
                .overlay {
                    Text(candidate.confidence, format: .percent.precision(.fractionLength(0)))
                        .font(.caption2.weight(.bold))
                }
        }
    }
}

struct FieldList: View {
    let candidate: ActionCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fields")
                .font(.headline)
            if candidate.fields.isEmpty {
                Text("No structured fields")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(candidate.fields.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { key, value in
                    HStack(alignment: .top) {
                        Text(key.rawValue)
                            .font(.caption.weight(.semibold))
                            .frame(width: 100, alignment: .leading)
                            .foregroundStyle(.secondary)
                        Text(value)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

struct ValidationPanel: View {
    let state: ValidationState

    var body: some View {
        Label(state.message, systemImage: state.symbolName)
            .foregroundStyle(state.displayTone.color)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .snapGlassPanel(tone: state.displayTone, cornerRadius: 14)
    }
}

struct EmptyCapturePulse: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.primary.opacity(0.13), style: StrokeStyle(lineWidth: 1.2, dash: [8, 8]))
                    .frame(width: 180, height: 112)
                Image(systemName: "viewfinder")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text("Waiting for a capture")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

struct EmptyReviewSurface: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: 18) {
            Text("Ready for the next snap")
                .font(.title3.weight(.semibold))
            Text("Capture the screen, run the demo, or import an image. Suggestions appear here as editable, confirmed actions.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            HStack {
                Button {
                    appState.captureScreenSnapshot()
                } label: {
                    Label("Capture Screen", systemImage: "rectangle.dashed")
                }
                .buttonStyle(.glassProminent)
                .accessibilityLabel("Capture Screen")
                .help("Capture the screen")

                Button {
                    appState.captureDemo()
                } label: {
                    Label("Demo Capture", systemImage: "sparkles")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Demo Capture")
                .help("Run a demo capture")
            }
            ClipboardShelf(appState: appState)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .snapGlassPanel(interactive: true, cornerRadius: 24)
    }
}

struct ClipboardShelf: View {
    let appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            Label(appState.clipboardStatus, systemImage: "doc.on.clipboard")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button {
                appState.restoreSavedClipboard()
            } label: {
                Label("Restore Clipboard", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(appState.lastClipboardSnapshot == nil)
            .accessibilityLabel("Restore Clipboard")
            .help("Restore the last SnapAction clipboard payload")
        }
        .padding(10)
        .snapGlassPanel(tone: appState.lastClipboardSnapshot == nil ? .neutral : .success, interactive: appState.lastClipboardSnapshot != nil, cornerRadius: 14)
    }
}

extension ActionKind {
    var symbolName: String {
        switch self {
        case .reminder:
            "checklist"
        case .calendarEvent:
            "calendar.badge.plus"
        case .textTable:
            "text.viewfinder"
        }
    }

    var confirmLabel: String {
        switch self {
        case .reminder:
            "Create Reminder"
        case .calendarEvent:
            "Create Event"
        case .textTable:
            "Copy Text"
        }
    }
}

extension ValidationState {
    var message: String {
        switch self {
        case .pending:
            "Not validated yet"
        case .valid:
            "Valid. Review fields before confirming."
        case .warning(let message), .invalid(let message):
            message
        }
    }

    var symbolName: String {
        switch self {
        case .pending:
            "clock"
        case .valid:
            "checkmark.seal"
        case .warning:
            "exclamationmark.triangle"
        case .invalid:
            "xmark.octagon"
        }
    }

    var isInvalid: Bool {
        if case .invalid = self { return true }
        return false
    }
}
