import Foundation
import SnapActionCore
import Testing
@testable import SnapActionApp

@Test
@MainActor
func completedExecutionDoesNotExposeFeedbackUnderAnotherCandidate() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionAppStateTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let historyStore = try HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
    let clipboardStore = try ClipboardSnapshotStore(fileURL: directory.appendingPathComponent("clipboard.json"))
    let executor = DelayedActionExecutor()
    let workflow = CaptureWorkflow(
        extractor: RuleBasedFallbackExtractor(),
        validator: ActionValidator(),
        executor: executor,
        historyStore: historyStore
    )
    let appState = AppState(
        workflow: workflow,
        historyStore: historyStore,
        clipboardStore: clipboardStore
    )
    let document = OCRDocument.singleBlock("Candidate source")
    let candidateA = ActionCandidate(
        kind: .reminder,
        title: "Candidate A",
        confidence: 1,
        sourceText: document.normalizedText,
        fields: [:],
        validationState: .valid
    )
    let candidateB = ActionCandidate(
        kind: .textTable,
        title: "Candidate B",
        confidence: 1,
        sourceText: document.normalizedText,
        fields: [.extractedText: document.normalizedText],
        validationState: .valid
    )

    appState.currentDocument = document
    appState.candidates = [candidateA, candidateB]
    appState.selectedCandidateID = candidateA.id

    appState.execute(candidate: candidateA, editedTitle: candidateA.title, confirmed: true)
    await executor.waitUntilStarted()

    appState.selectedCandidateID = candidateB.id
    await executor.complete(with: .createdReminder(id: "candidate-a-result"))

    while appState.isProcessing {
        await Task.yield()
    }

    #expect(appState.selectedCandidate?.id == candidateB.id)
    #expect(appState.lastExecutionFeedback == nil)
    #expect(appState.executionResult(for: candidateB.id) == nil)
    #expect(appState.lastExecutionResult == nil)
}

private actor DelayedActionExecutor: ActionExecuting {
    private var executionContinuation: CheckedContinuation<ActionExecutionResult, Never>?
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func execute(_ candidate: ActionCandidate, confirmed: Bool) async throws -> ActionExecutionResult {
        await withCheckedContinuation { continuation in
            executionContinuation = continuation
            let waiters = startWaiters
            startWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    func waitUntilStarted() async {
        guard executionContinuation == nil else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func complete(with result: ActionExecutionResult) {
        executionContinuation?.resume(returning: result)
        executionContinuation = nil
    }
}
