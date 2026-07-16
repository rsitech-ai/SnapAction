import CoreGraphics
import Foundation
import ScreenCaptureKit

struct ScreenCaptureService: Sendable {
    var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    func permissionSummary() -> String {
        hasPermission ? "Screen Recording allowed" : "Screen Recording needed"
    }

    func requestPermission() {
        _ = CGRequestScreenCaptureAccess()
    }

    func verifyShareableContent() async -> String {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return "ScreenCaptureKit sees \(content.displays.count) display(s)."
        } catch {
            return "ScreenCaptureKit unavailable: \(error.localizedDescription)"
        }
    }

    func captureFirstDisplayImage() async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw CocoaError(.featureUnsupported)
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }
}
