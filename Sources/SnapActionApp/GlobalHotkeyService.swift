import AppKit
import Foundation

@MainActor
final class GlobalHotkeyService {
    private var monitor: Any?

    func start(onTrigger: @escaping @MainActor () -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.command), flags.contains(.shift), event.charactersIgnoringModifiers == "2" {
                Task { @MainActor in
                    onTrigger()
                }
            }
        }
    }
}
