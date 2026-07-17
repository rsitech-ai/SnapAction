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
    @State private var launchState = AppLaunchState.load()

    private var appState: AppState? {
        launchState.appState
    }

    var body: some Scene {
        WindowGroup("SnapAction", id: "main") {
            if let appState {
                ContentView(appState: appState)
                    .frame(minWidth: 980, minHeight: 640)
                    .task {
                        appState.startHotkeyMonitor()
                    }
            } else {
                StartupFailureView(message: launchState.failureMessage ?? "Local storage is unavailable.")
            }
        }
        .commands {
            CommandMenu("Capture") {
                Button("Capture Screen") {
                    appState?.captureScreenSnapshot()
                }
                .disabled(appState?.allowsNewOperation != true)
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Button("Demo Capture") {
                    appState?.captureDemo()
                }
                .disabled(appState?.allowsNewOperation != true)
                .keyboardShortcut("2", modifiers: [.command, .shift])

                Button("Import Image") {
                    appState?.importImageForOCR()
                }
                .disabled(appState?.allowsNewOperation != true)
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("SnapAction", systemImage: "scope") {
            if let appState {
                Button("Capture Screen") {
                    appState.captureScreenSnapshot()
                }
                .disabled(!appState.allowsNewOperation)
                Button("Demo Capture") {
                    appState.captureDemo()
                }
                .disabled(!appState.allowsNewOperation)
                Button("Import Image") {
                    appState.importImageForOCR()
                }
                .disabled(!appState.allowsNewOperation)
            } else {
                Text("Local storage unavailable")
            }
            Divider()
            SettingsLink()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            if let appState {
                SettingsView(appState: appState)
            } else {
                StartupFailureView(message: launchState.failureMessage ?? "Local storage is unavailable.")
            }
        }
    }
}
