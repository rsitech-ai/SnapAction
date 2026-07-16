import SnapActionCore
import SwiftUI

struct WorkspaceView: View {
    let appState: AppState

    var body: some View {
        ZStack {
            WarmSignalBackdrop()

            Group {
                switch appState.workspacePresentation.phase {
                case .capture:
                    CaptureWorkspaceView(appState: appState)
                case .processing:
                    ProcessingWorkspaceView(label: appState.processingLabel)
                case .review:
                    ReviewWorkspaceView(appState: appState)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Review")
    }
}

struct WorkflowFailureBanner: View {
    let failure: WorkflowFailurePresentation
    let retry: () -> Void
    let requestScreenRecordingAccess: () -> Void
    let openPrivacySettings: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: SnapActionDesign.spacingM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SnapActionDesign.spacingS) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(failure.title)
                        .font(.headline)

                    Text(failure.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: SnapActionDesign.spacingS) {
                    if failure.showsCapturePermissionRecovery {
                        Button("Request Access", action: requestScreenRecordingAccess)
                            .controlSize(.small)
                            .help("Request Screen Recording access")

                        Button("Open Privacy Settings", action: openPrivacySettings)
                            .controlSize(.small)
                            .help("Open Screen Recording privacy settings")
                    }

                    if let retryAction = failure.retryAction {
                        Button(retryLabel(for: retryAction), action: retry)
                            .controlSize(.small)
                    }
                }
            }

            Spacer(minLength: 0)

            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss Error")
            .help("Dismiss this error")
        }
        .padding(SnapActionDesign.spacingM)
        .snapSurface(tone: .danger, cornerRadius: SnapActionDesign.groupRadius)
        .accessibilityElement(children: .contain)
    }

    private func retryLabel(for action: WorkflowFailureRetryAction) -> String {
        switch action {
        case .capture:
            "Try Again"
        case .imageImport:
            "Choose Another Image"
        }
    }
}

struct ProcessingWorkspaceView: View {
    let label: String

    var body: some View {
        VStack(spacing: SnapActionDesign.spacingM) {
            ProgressView()
                .controlSize(.large)
                .accessibilityLabel(label)

            Text(label)
                .font(.title3.weight(.semibold))

            Text("Processing stays on this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
