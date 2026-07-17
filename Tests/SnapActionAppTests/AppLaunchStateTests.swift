import Foundation
import Testing
@testable import SnapActionApp

@Test
@MainActor
func appLaunchStateSurfacesLocalStorageInitializationFailure() {
    let launchState = AppLaunchState.load {
        throw CocoaError(.fileWriteNoPermission)
    }

    #expect(launchState.appState == nil)
    #expect(
        launchState.failureMessage
            == "SnapAction couldn’t initialize its private local storage. Check available disk space and folder permissions, then relaunch."
    )
}
