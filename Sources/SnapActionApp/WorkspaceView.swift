import SwiftUI

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
        .navigationTitle("Review")
    }
}

struct ProcessingWorkspaceView: View {
    let label: String

    var body: some View {
        VStack(spacing: 16) {
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
