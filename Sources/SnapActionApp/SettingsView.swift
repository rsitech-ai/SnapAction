import SnapActionCore
import SwiftUI

struct SettingsView: View {
    let appState: AppState
    @State private var showingClearHistoryConfirmation = false
    @State private var showingClearClipboardConfirmation = false

    var body: some View {
        Form {
            Section("Capture Access") {
                LabeledContent("Capture Screen", value: "Command-Shift-1")
                LabeledContent("Demo Capture", value: "Command-Shift-2")
                LabeledContent("Import Image", value: "Command-Shift-I")
                LabeledContent("System writes", value: appState.eventKitStatus)
                LabeledContent("Clipboard", value: appState.clipboardStatus)

                LabeledContent("Screen Recording") {
                    Text(appState.screenCaptureStatus)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: SnapActionDesign.spacingS) {
                    Button("Request Access") {
                        appState.requestScreenRecordingPermission()
                    }
                    .accessibilityLabel("Request Screen Recording Permission")
                    .help("Ask macOS for Screen Recording access")

                    Button("Open Privacy Settings") {
                        appState.openSystemSettings()
                    }
                    .accessibilityLabel("Open Privacy Settings")
                    .help("Open the Screen Recording privacy settings in System Settings")
                }
            }

            Section("Intelligence") {
                LabeledContent("Foundation Models") {
                    Text(appState.modelStatus)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("SnapAction stays local-only. If Apple Intelligence is unavailable, fails, or times out, deterministic text/table extraction remains available.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("History") {
                Stepper(value: Binding<Int>(
                    get: { appState.historyRetentionDays },
                    set: { newValue in
                        appState.updateHistoryRetentionDays(newValue)
                    }
                ), in: 1...90) {
                    Text(HistoryRetentionPresentation.label(days: appState.historyRetentionDays))
                }
                if let errorMessage = appState.settingsErrorMessage {
                    HStack(alignment: .firstTextBaseline, spacing: SnapActionDesign.spacingS) {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        Button("Dismiss", action: appState.dismissSettingsError)
                            .controlSize(.small)
                            .help("Dismiss the history settings error")
                    }
                }
                Button("Clear History…", role: .destructive) {
                    showingClearHistoryConfirmation = true
                }
                .help("Delete all saved action summaries")

                Text("History stores only action titles, kinds, timestamps, and bounded outcomes. OCR text, candidate fields, system identifiers, and screenshot pixels are not stored.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Saved Clipboard") {
                Button("Clear Saved Clipboard…", role: .destructive) {
                    showingClearClipboardConfirmation = true
                }
                .disabled(appState.lastClipboardSnapshot == nil)
                .help("Delete the locally cached clipboard payload")

                Text("The most recent copied text is cached for up to seven days so it can be restored after relaunch. Clear it here at any time.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .padding(SnapActionDesign.spacingM)
        .frame(width: 620, height: 620)
        .confirmationDialog(
            "Clear all history summaries?",
            isPresented: $showingClearHistoryConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear History", role: .destructive, action: appState.clearHistory)
        } message: {
            Text("This removes all saved action summaries from this Mac and cannot be undone.")
        }
        .confirmationDialog(
            "Clear the saved clipboard payload?",
            isPresented: $showingClearClipboardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Saved Clipboard", role: .destructive, action: appState.clearSavedClipboard)
        } message: {
            Text("This removes the cached text from SnapAction. The current system clipboard is not changed.")
        }
    }
}
