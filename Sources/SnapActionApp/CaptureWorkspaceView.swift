import SwiftUI

struct CaptureWorkspaceView: View {
    let appState: AppState

    var body: some View {
        VStack(spacing: SnapActionDesign.spacingL) {
            Spacer(minLength: SnapActionDesign.spacingL)

            VStack(spacing: 14) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text("Turn a screen into actions")
                    .font(.largeTitle.weight(.semibold))

                Text("Capture the first display, then review every suggested action before anything changes.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            Button(action: appState.captureScreenSnapshot) {
                Label("Capture Screen", systemImage: "viewfinder")
                    .frame(minWidth: 240, minHeight: 48)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .help("Capture the first display and find actions")

            HStack(spacing: 12) {
                Button(action: appState.importImageForOCR) {
                    Label("Import Image", systemImage: "photo.badge.magnifyingglass")
                }
                .buttonStyle(.glass)
                .help("Import an image for text recognition")

                Button(action: appState.captureDemo) {
                    Label("Demo Capture", systemImage: "sparkles")
                }
                .buttonStyle(.glass)
                .help("Run a local demo capture")
            }

            Text("Captures stay on this Mac and are processed locally.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let failure = appState.workflowFailure {
                WorkflowFailureBanner(
                    failure: failure,
                    retry: appState.retryWorkflowFailure,
                    requestScreenRecordingAccess: appState.requestScreenRecordingPermission,
                    openPrivacySettings: appState.openSystemSettings,
                    dismiss: appState.dismissWorkflowFailure
                )
                .frame(maxWidth: 560)
                .fixedSize(horizontal: false, vertical: true)
            }

            contextualRecovery
                .frame(maxWidth: 560)

            Spacer(minLength: SnapActionDesign.spacingL)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var contextualRecovery: some View {
        let presentation = appState.workspacePresentation

        VStack(spacing: 12) {
            if presentation.showsCapturePermissionRecovery,
               appState.workflowFailure?.showsCapturePermissionRecovery != true {
                GroupBox {
                    HStack(spacing: SnapActionDesign.spacingS) {
                        Button("Request Access", action: appState.requestScreenRecordingPermission)
                            .help("Request Screen Recording access")

                        Button("Open Privacy Settings", action: appState.openSystemSettings)
                            .help("Open Screen Recording privacy settings")

                        Spacer(minLength: 0)
                    }
                    .padding(.top, 4)
                } label: {
                    Label("Screen Recording access is needed to capture the display.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            if presentation.showsModelFallbackNotice {
                Label(
                    appState.modelFallbackNotice,
                    systemImage: "info.circle"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if presentation.showsClipboardRestore {
                Button(action: appState.restoreSavedClipboard) {
                    Label("Restore Clipboard", systemImage: "arrow.counterclockwise")
                }
                .help("Restore the last SnapAction clipboard payload")
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
