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
