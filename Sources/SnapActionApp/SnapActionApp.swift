import AppKit
import SnapActionCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct SnapActionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState.bootstrap()

    var body: some Scene {
        WindowGroup("SnapAction", id: "main") {
            ContentView(appState: appState)
                .frame(minWidth: 980, minHeight: 640)
                .task {
                    appState.startHotkeyMonitor()
                }
        }
        .commands {
            CommandMenu("Capture") {
                Button("Capture Screen") {
                    appState.captureScreenSnapshot()
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Button("Capture Demo") {
                    appState.captureDemo()
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])

                Button("Import Image for OCR") {
                    appState.importImageForOCR()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("SnapAction", systemImage: "scope") {
            Button("Capture Screen") {
                appState.captureScreenSnapshot()
            }
            Button("Capture Demo") {
                appState.captureDemo()
            }
            Button("Import Image") {
                appState.importImageForOCR()
            }
            Divider()
            SettingsLink()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView(appState: appState)
        }
    }
}
