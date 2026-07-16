import SwiftUI

struct SettingsView: View {
    let appState: AppState

    var body: some View {
        Form {
            Section("Capture") {
                LabeledContent("Capture Screen", value: "Command-Shift-1")
                LabeledContent("Demo Capture", value: "Command-Shift-2")
                LabeledContent("Import Image", value: "Command-Shift-I")
                LabeledContent("System writes", value: appState.eventKitStatus)
                LabeledContent("Clipboard", value: appState.clipboardStatus)
                HStack {
                    Text(appState.screenCaptureStatus)
                    Spacer()
                    Button("Request") {
                        appState.requestScreenRecordingPermission()
                    }
                    .accessibilityLabel("Request Screen Recording Permission")
                    Button("Open Privacy Settings") {
                        appState.openSystemSettings()
                    }
                    .accessibilityLabel("Open Privacy Settings")
                }
            }

            Section("AI") {
                LabeledContent("Foundation Models", value: appState.modelStatus)
                Text("SnapAction stays local-only. When Apple Intelligence is unavailable, only text/table extraction is suggested.")
                    .foregroundStyle(.secondary)
            }

            Section("History") {
                Stepper(value: Bindable(appState).historyRetentionDays, in: 1...90) {
                    Text("Retain metadata for \(appState.historyRetentionDays) days")
                }
                Text("History stores OCR text, candidates, timestamps, and execution results. Screenshot pixels are not stored.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 620, height: 520)
    }
}
