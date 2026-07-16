import SnapActionCore
import SwiftUI

struct ReviewWorkspaceView: View {
    let appState: AppState

    var body: some View {
        HSplitView {
            OCRPreviewView(document: appState.currentDocument)
                .frame(minWidth: 300, idealWidth: 420)

            actionPane
                .frame(minWidth: 360, idealWidth: 480)
        }
    }

    @ViewBuilder
    private var actionPane: some View {
        if let candidate = appState.selectedCandidate {
            ScrollView {
                ActionReviewView(appState: appState, candidate: candidate)
                    .id(candidate.id)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(20)
            }
        } else {
            ContentUnavailableView(
                "No Suggested Actions",
                systemImage: "text.badge.xmark",
                description: Text("The recognized text did not produce an action to review.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
    }
}

struct OCRPreviewView: View {
    let document: OCRDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Recognized Text", systemImage: "text.viewfinder")
                    .font(.headline)

                Spacer()

                Text(blockCountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(previewText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
    }

    private var blockCountLabel: String {
        let count = document?.blocks.count ?? 0
        return count == 1 ? "1 block" : "\(count) blocks"
    }

    private var previewText: String {
        guard let text = document?.normalizedText, !text.isEmpty else {
            return "No recognized text."
        }
        return text
    }
}

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

    private var actionContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            candidateHeader

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Action title", text: $editedTitle)
                    .textFieldStyle(.roundedBorder)
            }

            fieldRows

            Divider()

            confirmationArea

            if appState.lastClipboardSnapshot != nil {
                clipboardRestore
            }
        }
    }

    private var candidateHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label(candidate.kind.displayName, systemImage: candidate.kind.symbolName)
                .font(.title3.weight(.semibold))

            Spacer(minLength: 8)

            Text(candidate.confidence, format: .percent.precision(.fractionLength(0)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Confidence \(candidate.confidence.formatted(.percent.precision(.fractionLength(0))))")
        }
    }

    @ViewBuilder
    private var fieldRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fields")
                .font(.headline)

            if candidate.fields.isEmpty {
                Text("No structured fields")
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .topLeading, horizontalSpacing: 18, verticalSpacing: 10) {
                    ForEach(candidate.fields.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { field, value in
                        GridRow(alignment: .top) {
                            Text(field.reviewLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 92, alignment: .leading)

                            Text(value)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var confirmationArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let result = appState.executionResult(for: candidate.id) {
                Label(result.displayMessage, systemImage: result.displayTone.feedbackSymbolName)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(result.displayTone.color)
                    .textSelection(.enabled)
            }

            Label(candidate.validationState.message, systemImage: candidate.validationState.symbolName)
                .font(.callout)
                .foregroundStyle(candidate.validationState.displayTone.color)

            Button {
                appState.execute(candidate: candidate, editedTitle: editedTitle, confirmed: true)
            } label: {
                Label(candidate.kind.confirmLabel, systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(!candidate.isExecutable)
            .accessibilityLabel(candidate.kind.confirmLabel)
            .accessibilityHint(candidate.isExecutable ? "Executes the reviewed action" : candidate.validationState.message)
            .help(candidate.isExecutable ? candidate.kind.confirmLabel : candidate.validationState.message)
        }
    }

    private var clipboardRestore: some View {
        HStack(spacing: 12) {
            Label(appState.clipboardStatus, systemImage: "doc.on.clipboard")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button(action: appState.restoreSavedClipboard) {
                Label("Restore Clipboard", systemImage: "arrow.counterclockwise")
            }
            .controlSize(.small)
            .help("Restore the last SnapAction clipboard payload")
        }
    }
}

private extension ActionField {
    var reviewLabel: String {
        switch self {
        case .dueDate:
            "Due date"
        case .startDate:
            "Start date"
        case .endDate:
            "End date"
        case .notes:
            "Notes"
        case .location:
            "Location"
        case .extractedText:
            "Extracted text"
        case .tableMarkdown:
            "Table"
        }
    }
}

private extension DisplayTone {
    var feedbackSymbolName: String {
        switch self {
        case .neutral:
            "info.circle"
        case .success:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .danger:
            "xmark.octagon.fill"
        }
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
}
