import Foundation
import SnapActionCore
import Testing
@testable import SnapActionApp

@Test
@MainActor
func appStateDisablesNewOperationsWhileExtractionIsActive() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionOperationAvailabilityTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let historyStore = try HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
    let clipboardStore = try ClipboardSnapshotStore(fileURL: directory.appendingPathComponent("clipboard.json"))
    let extractor = BlockingOperationExtractor()
    let workflow = CaptureWorkflow(
        extractor: extractor,
        validator: ActionValidator(),
        executor: OperationAvailabilityExecutor(),
        historyStore: historyStore
    )
    let appState = AppState(
        workflow: workflow,
        historyStore: historyStore,
        clipboardStore: clipboardStore
    )

    #expect(appState.allowsNewOperation)
    appState.captureDemo()
    await extractor.waitUntilStarted()
    #expect(!appState.allowsNewOperation)

    await extractor.complete()
    while appState.isProcessing {
        await Task.yield()
    }
    #expect(appState.allowsNewOperation)
}

private actor BlockingOperationExtractor: ActionExtracting {
    private var continuation: CheckedContinuation<[ActionCandidate], Never>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilStarted() async {
        guard continuation == nil else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func complete() {
        continuation?.resume(returning: [])
        continuation = nil
    }
}

private struct OperationAvailabilityExecutor: ActionExecuting {
    func execute(_ candidate: ActionCandidate, confirmed: Bool) async throws -> ActionExecutionResult {
        .copiedToClipboard
    }
}
