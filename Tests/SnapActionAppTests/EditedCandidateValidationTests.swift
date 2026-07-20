import Foundation
import SnapActionCore
import Testing
@testable import SnapActionApp

@Test
func editedCandidateIsRevalidatedBeforeConfirmation() {
    let candidate = ActionCandidate(
        kind: .textTable,
        title: "Extract text",
        confidence: 1,
        sourceText: "Fixture text",
        fields: [.extractedText: "Fixture text"],
        validationState: .valid
    )

    let reviewed = CandidateReview.validated(candidate, editedTitle: "   ")

    #expect(reviewed.validationState == .invalid("Action title is required."))
    #expect(!reviewed.isExecutable)
}

@Test
@MainActor
func invalidEditedTitleNeverReachesTheExecutor() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionEditedValidationTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let historyStore = try HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
    let clipboardStore = try ClipboardSnapshotStore(fileURL: directory.appendingPathComponent("clipboard.json"))
    let executor = InvocationCountingExecutor()
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
    let document = OCRDocument.singleBlock("Fixture text")
    let candidate = ActionCandidate(
        kind: .textTable,
        title: "Extract text",
        confidence: 1,
        sourceText: document.normalizedText,
        fields: [.extractedText: document.normalizedText],
        validationState: .valid
    )
    appState.currentDocument = document
    appState.candidates = [candidate]
    appState.selectedCandidateID = candidate.id

    appState.execute(candidate: candidate, editedTitle: "   ", confirmed: true)

    #expect(await executor.invocationCount == 0)
    #expect(appState.lastExecutionResult == .failed(message: "Action title is required."))
    #expect(!appState.isProcessing)
}

@Test
@MainActor
func confirmedEditedTitleBecomesCurrentAndPersistsInHistory() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionEditedPersistenceTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let historyStore = try HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
    let clipboardStore = try ClipboardSnapshotStore(fileURL: directory.appendingPathComponent("clipboard.json"))
    let executor = InvocationCountingExecutor()
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
    let document = OCRDocument.singleBlock("Fixture text")
    let candidate = ActionCandidate(
        kind: .textTable,
        title: "Extract text",
        confidence: 1,
        sourceText: document.normalizedText,
        fields: [.extractedText: document.normalizedText],
        validationState: .valid
    )
    appState.currentDocument = document
    appState.candidates = [candidate]
    appState.selectedCandidateID = candidate.id

    appState.execute(candidate: candidate, editedTitle: "  Reviewed fixture title  ", confirmed: true)
    while appState.isProcessing {
        await Task.yield()
    }

    #expect(appState.selectedCandidate?.title == "Reviewed fixture title")
    #expect(appState.history.first?.title == "Reviewed fixture title")
    #expect(appState.lastExecutionResult == .copiedToClipboard)
}

private actor InvocationCountingExecutor: ActionExecuting {
    private(set) var invocationCount = 0

    func execute(_ candidate: ActionCandidate, confirmed: Bool) async throws -> ActionExecutionResult {
        invocationCount += 1
        return .copiedToClipboard
    }
}
