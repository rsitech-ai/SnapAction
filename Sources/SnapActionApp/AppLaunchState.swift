import AppKit
import OSLog
import SwiftUI

@MainActor
enum AppLaunchState {
    case ready(AppState)
    case failed(String)

    var appState: AppState? {
        guard case .ready(let appState) = self else { return nil }
        return appState
    }

    var failureMessage: String? {
        guard case .failed(let message) = self else { return nil }
        return message
    }

    static func load(
        using bootstrap: @MainActor () throws -> AppState = { try AppState.bootstrap() }
    ) -> AppLaunchState {
        do {
            return .ready(try bootstrap())
        } catch {
            let nsError = error as NSError
            Logger(subsystem: "com.s1kor.snapaction", category: "Startup").critical(
                "Local storage initialization failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
            )
            return .failed(
                "SnapAction couldn’t initialize its private local storage. Check available disk space and folder permissions, then relaunch."
            )
        }
    }
}

struct StartupFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("SnapAction couldn’t start", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Quit SnapAction") {
                NSApplication.shared.terminate(nil)
            }
        }
        .frame(minWidth: 560, minHeight: 360)
    }
}
