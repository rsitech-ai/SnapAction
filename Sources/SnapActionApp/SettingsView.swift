import SnapActionCore
import SwiftUI

struct SettingsView: View {
    let appState: AppState

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
                Text("History stores OCR text, candidates, timestamps, and execution results. Screenshot pixels are not stored.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .padding(SnapActionDesign.spacingM)
        .frame(width: 620, height: 520)
    }
}
