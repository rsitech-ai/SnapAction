import Foundation
import SnapActionCore
import Testing
@testable import SnapActionApp

@Test
@MainActor
func extractionFailureIsVisibleWithoutADocumentAndClearsOnRetry() async throws {
    let fixture = try AppStateFailureFixture(extractor: ThrowingWorkflowExtractor())
    defer { fixture.remove() }

    fixture.appState.captureDemo()
    await fixture.waitUntilIdle()

    #expect(fixture.appState.currentDocument == nil)
    #expect(fixture.appState.workflowFailure?.kind == .extraction)
    #expect(fixture.appState.workflowFailure?.title == "Actions couldn’t be created")

    fixture.appState.captureDemo()
    #expect(fixture.appState.workflowFailure == nil)
    await fixture.waitUntilIdle()

    fixture.appState.dismissWorkflowFailure()
    #expect(fixture.appState.workflowFailure == nil)
}

@Test
@MainActor
func extractionFailureKeepsAStaleDocumentAndCandidateVisible() async throws {
    let fixture = try AppStateFailureFixture(extractor: ThrowingWorkflowExtractor())
    defer { fixture.remove() }
    let staleDocument = OCRDocument.singleBlock("Keep this reviewed document")
    let staleCandidate = ActionCandidate(
        kind: .textTable,
        title: "Keep reviewed action",
        confidence: 1,
        sourceText: staleDocument.normalizedText,
        fields: [.extractedText: staleDocument.normalizedText],
        validationState: .valid
    )
    fixture.appState.currentDocument = staleDocument
    fixture.appState.candidates = [staleCandidate]
    fixture.appState.selectedCandidateID = staleCandidate.id

    fixture.appState.captureDemo()
    await fixture.waitUntilIdle()

    #expect(fixture.appState.currentDocument == staleDocument)
    #expect(fixture.appState.selectedCandidate == staleCandidate)
    #expect(fixture.appState.workflowFailure?.kind == .extraction)
}

@Test
@MainActor
func successfulResolutionClearsThePreviousWorkflowFailure() async throws {
    let extractor = ThrowThenSucceedWorkflowExtractor()
    let fixture = try AppStateFailureFixture(extractor: extractor)
    defer { fixture.remove() }

    fixture.appState.captureDemo()
    await fixture.waitUntilIdle()
    #expect(fixture.appState.workflowFailure?.kind == .extraction)

    fixture.appState.captureDemo()
    await fixture.waitUntilIdle()

    #expect(fixture.appState.workflowFailure == nil)
    #expect(fixture.appState.currentDocument != nil)
    #expect(fixture.appState.selectedCandidate?.title == "Recovered action")
}

@Test
@MainActor
func retentionWriteFailureExposesAnInlineSettingsError() throws {
    let fixture = try AppStateFailureFixture(
        extractor: RuleBasedFallbackExtractor(),
        historyRetentionUpdater: { _ in throw WorkflowFailureTestError.retentionWrite }
    )
    defer { fixture.remove() }

    fixture.appState.updateHistoryRetentionDays(7)

    #expect(fixture.appState.historyRetentionDays == 30)
    #expect(fixture.appState.settingsErrorMessage == "Could not update history retention: Retention write failed.")

    fixture.appState.dismissSettingsError()
    #expect(fixture.appState.settingsErrorMessage == nil)
}

@MainActor
private struct AppStateFailureFixture {
    let directory: URL
    let appState: AppState

    init(
        extractor: any ActionExtracting,
        historyRetentionUpdater: (@Sendable (Int) throws -> Void)? = nil
    ) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnapActionWorkflowFailureTests-\(UUID().uuidString)", isDirectory: true)
        let historyStore = try HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
        let clipboardStore = try ClipboardSnapshotStore(fileURL: directory.appendingPathComponent("clipboard.json"))
        let workflow = CaptureWorkflow(
            extractor: extractor,
            validator: ActionValidator(),
            executor: WorkflowFailureTestExecutor(),
            historyStore: historyStore
        )
        self.directory = directory
        self.appState = AppState(
            workflow: workflow,
            historyStore: historyStore,
            clipboardStore: clipboardStore,
            modelAvailabilitySummary: { "Apple Intelligence available" },
            modelIsAvailable: { true },
            historyRetentionUpdater: historyRetentionUpdater
        )
    }

    func waitUntilIdle() async {
        while appState.isProcessing {
            await Task.yield()
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}

private struct ThrowingWorkflowExtractor: ActionExtracting {
    func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        throw WorkflowFailureTestError.extraction
    }
}

private actor ThrowThenSucceedWorkflowExtractor: ActionExtracting {
    private var invocationCount = 0

    func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        invocationCount += 1
        guard invocationCount > 1 else {
            throw WorkflowFailureTestError.extraction
        }
        return [
            ActionCandidate(
                kind: .textTable,
                title: "Recovered action",
                confidence: 1,
                sourceText: request.document.normalizedText,
                fields: [.extractedText: request.document.normalizedText],
                validationState: .valid
            )
        ]
    }
}

private struct WorkflowFailureTestExecutor: ActionExecuting {
    func execute(_ candidate: ActionCandidate, confirmed: Bool) async throws -> ActionExecutionResult {
        .copiedToClipboard
    }
}

private enum WorkflowFailureTestError: LocalizedError {
    case extraction
    case retentionWrite

    var errorDescription: String? {
        switch self {
        case .extraction:
            "Extraction fixture failed."
        case .retentionWrite:
            "Retention write failed."
        }
    }
}
