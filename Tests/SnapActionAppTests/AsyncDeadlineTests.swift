import Foundation
import Testing
@testable import SnapActionApp

@Test
func callerResponseDeadlineTimesOutAndCooperativeChildStops() async {
    let probe = AsyncOperationProbe()
    let clock = ContinuousClock()
    let startedAt = clock.now

    let outcome = await CallerResponseDeadline.run(for: .milliseconds(25)) {
        await probe.markStarted()
        while !Task.isCancelled {
            await Task.yield()
        }
        await probe.markStopped()
        return 42
    }

    #expect(outcome == .timedOut)
    #expect(startedAt.duration(to: clock.now) < .milliseconds(250))
    await probe.waitUntilStopped()
}

@Test
func callerResponseDeadlinePropagatesParentCancellationAndReturnsPromptly() async {
    let probe = AsyncOperationProbe()
    let clock = ContinuousClock()
    let task = Task {
        await CallerResponseDeadline.run(for: .seconds(30)) {
            await probe.markStarted()
            while !Task.isCancelled {
                await Task.yield()
            }
            await probe.markStopped()
            return 42
        }
    }

    await probe.waitUntilStarted()
    let cancelledAt = clock.now
    task.cancel()

    #expect(await task.value == .cancelled)
    #expect(cancelledAt.duration(to: clock.now) < .milliseconds(250))
    await probe.waitUntilStopped()
}

@Test
func modelAttemptRunnerRejectsOverlapWhileTimedOutWorkWindsDown() async {
    let gate = FoundationModelAttemptGate()
    let probe = AsyncOperationProbe()
    let invocationCounter = AsyncInvocationCounter()

    let firstAttempt = Task {
        await FoundationModelAttemptRunner.run(for: .milliseconds(25), gate: gate) {
            await invocationCounter.recordInvocation()
            await probe.markStarted()
            while !(await probe.isReleased) {
                // Deliberately ignore cancellation to model an in-process framework call
                // that needs time to wind down after the caller has fallen back.
                await Task.yield()
            }
            await probe.markStopped()
            return 42
        }
    }

    await probe.waitUntilStarted()
    #expect(await firstAttempt.value == .timedOut)
    let overlappingAttempt = await FoundationModelAttemptRunner.run(for: .seconds(1), gate: gate) {
        await invocationCounter.recordInvocation()
        return 7
    }
    #expect(overlappingAttempt == .busy)
    #expect(await invocationCounter.count == 1)

    await probe.release()
    await probe.waitUntilStopped()
    await gate.waitUntilIdle()

    let nextAttempt = await FoundationModelAttemptRunner.run(for: .seconds(1), gate: gate) {
        await invocationCounter.recordInvocation()
        return 7
    }
    #expect(nextAttempt == .success(7))
    #expect(await invocationCounter.count == 2)
}

@Test
func preCancelledModelAttemptDoesNotClaimTheGate() async {
    let gate = FoundationModelAttemptGate()
    let startBarrier = AsyncOperationProbe()
    let invocationCounter = AsyncInvocationCounter()
    let cancelledAttempt = Task {
        await startBarrier.markStarted()
        await startBarrier.waitUntilReleased()
        return await FoundationModelAttemptRunner.run(for: .seconds(1), gate: gate) {
            await invocationCounter.recordInvocation()
            return 42
        }
    }

    await startBarrier.waitUntilStarted()
    cancelledAttempt.cancel()
    await startBarrier.release()

    #expect(await cancelledAttempt.value == .cancelled)
    #expect(await invocationCounter.count == 0)

    let nextAttempt = await FoundationModelAttemptRunner.run(for: .seconds(1), gate: gate) {
        await invocationCounter.recordInvocation()
        return 42
    }
    #expect(nextAttempt == .success(42))
    #expect(await invocationCounter.count == 1)
}

@Test
func callerResponseDeadlineReturnsCompletedValue() async {
    let outcome = await CallerResponseDeadline.run(for: .seconds(1)) {
        "ready"
    }

    #expect(outcome == .success("ready"))
}

private actor AsyncOperationProbe {
    private var started = false
    private var stopped = false
    private var released = false
    private var startedContinuations: [CheckedContinuation<Void, Never>] = []
    private var stoppedContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuations: [CheckedContinuation<Void, Never>] = []

    var isReleased: Bool { released }

    func markStarted() {
        started = true
        startedContinuations.forEach { $0.resume() }
        startedContinuations.removeAll()
    }

    func markStopped() {
        stopped = true
        stoppedContinuations.forEach { $0.resume() }
        stoppedContinuations.removeAll()
    }

    func release() {
        released = true
        releaseContinuations.forEach { $0.resume() }
        releaseContinuations.removeAll()
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { continuation in
            startedContinuations.append(continuation)
        }
    }

    func waitUntilStopped() async {
        guard !stopped else { return }
        await withCheckedContinuation { continuation in
            stoppedContinuations.append(continuation)
        }
    }

    func waitUntilReleased() async {
        guard !released else { return }
        await withCheckedContinuation { continuation in
            releaseContinuations.append(continuation)
        }
    }
}

private actor AsyncInvocationCounter {
    private(set) var count = 0

    func recordInvocation() {
        count += 1
    }
}
