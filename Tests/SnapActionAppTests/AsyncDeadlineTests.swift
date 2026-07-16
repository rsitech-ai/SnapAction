import Foundation
import Testing
@testable import SnapActionApp

@Test
func asyncDeadlineReturnsTimeoutAndCancelsSlowWork() async {
    let clock = ContinuousClock()
    let startedAt = clock.now

    let outcome = await AsyncDeadline.run(for: .milliseconds(25)) {
        while !Task.isCancelled {
            await Task.yield()
        }
        return 42
    }

    #expect(outcome == .timedOut)
    #expect(startedAt.duration(to: clock.now) < .milliseconds(250))
}

@Test
func asyncDeadlineReturnsCompletedValue() async {
    let outcome = await AsyncDeadline.run(for: .seconds(1)) {
        "ready"
    }

    #expect(outcome == .success("ready"))
}
