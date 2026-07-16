import Foundation
import SnapActionCore
import Testing
@testable import SnapActionApp

@Test
func candidateReviewPreservesDeterministicFallbackProvenance() {
    let candidate = ActionCandidate(
        kind: .textTable,
        title: "Extract text",
        confidence: 0.65,
        sourceText: "Fixture text",
        fields: [.extractedText: "Fixture text"],
        validationState: .valid,
        extractionProvenance: .deterministicFallback(.modelFailed)
    )

    let reviewed = CandidateReview.validated(candidate, editedTitle: "Reviewed text")

    #expect(reviewed.title == "Reviewed text")
    #expect(reviewed.extractionProvenance == .deterministicFallback(.modelFailed))
}

@Test
@MainActor
func appStatePresentsFallbackProvenanceUntilSuccessfulReplacement() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionFallbackProvenanceTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let historyStore = try HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
    let clipboardStore = try ClipboardSnapshotStore(fileURL: directory.appendingPathComponent("clipboard.json"))
    let extractor = SequencedProvenanceExtractor()
    let workflow = CaptureWorkflow(
        extractor: extractor,
        validator: ActionValidator(),
        executor: ProvenanceTestExecutor(),
        historyStore: historyStore
    )
    let appState = AppState(
        workflow: workflow,
        historyStore: historyStore,
        clipboardStore: clipboardStore,
        modelAvailabilitySummary: { "Apple Intelligence available" },
        modelIsAvailable: { true }
    )

    appState.captureDemo()
    while appState.isProcessing {
        await Task.yield()
    }

    #expect(appState.selectedCandidate?.validationState == .valid)
    #expect(appState.selectedCandidate?.extractionProvenance == .deterministicFallback(.modelTimedOut))
    #expect(appState.activeExtractionProvenance == .deterministicFallback(.modelTimedOut))
    #expect(appState.modelFallbackActive)
    #expect(appState.workspacePresentation.showsModelFallbackNotice)
    #expect(appState.modelFallbackNotice == "Deterministic fallback active — Apple Intelligence timed out.")
    #expect(appState.modelStatus == "Deterministic fallback active — Apple Intelligence timed out.")

    appState.captureDemo()
    #expect(appState.activeExtractionProvenance == .deterministicFallback(.modelTimedOut))
    #expect(appState.modelFallbackActive)
    #expect(appState.modelStatus == "Deterministic fallback active — Apple Intelligence timed out.")

    await extractor.waitUntilSecondExtractionStarted()
    await extractor.completeSecondExtraction()
    while appState.isProcessing {
        await Task.yield()
    }

    #expect(appState.activeExtractionProvenance == .foundationModels)
    #expect(!appState.modelFallbackActive)
    #expect(appState.modelStatus == "Apple Intelligence available")
}

@Test
@MainActor
func failedReplacementPreservesStaleFallbackProvenanceAndDisclosure() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionFallbackFailureTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let historyStore = try HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
    let clipboardStore = try ClipboardSnapshotStore(fileURL: directory.appendingPathComponent("clipboard.json"))
    let workflow = CaptureWorkflow(
        extractor: FallbackThenThrowExtractor(),
        validator: ActionValidator(),
        executor: ProvenanceTestExecutor(),
        historyStore: historyStore
    )
    let appState = AppState(
        workflow: workflow,
        historyStore: historyStore,
        clipboardStore: clipboardStore,
        modelAvailabilitySummary: { "Apple Intelligence available" },
        modelIsAvailable: { true }
    )

    appState.captureDemo()
    while appState.isProcessing { await Task.yield() }
    let staleDocument = appState.currentDocument
    let staleCandidate = appState.selectedCandidate

    #expect(staleCandidate?.extractionProvenance == .deterministicFallback(.modelFailed))
    #expect(appState.activeExtractionProvenance == .deterministicFallback(.modelFailed))

    appState.captureDemo()
    while appState.isProcessing { await Task.yield() }

    #expect(appState.currentDocument == staleDocument)
    #expect(appState.selectedCandidate == staleCandidate)
    #expect(appState.workflowFailure?.kind == .extraction)
    #expect(appState.activeExtractionProvenance == .deterministicFallback(.modelFailed))
    #expect(appState.modelFallbackActive)
    #expect(appState.workspacePresentation.showsModelFallbackNotice)
    #expect(appState.workspacePresentation.showsModelStatusInSidebar)
    #expect(appState.modelFallbackNotice == "Deterministic fallback active — Apple Intelligence extraction failed.")
    #expect(appState.modelStatus == "Deterministic fallback active — Apple Intelligence extraction failed.")
}

@Test
@MainActor
func zeroCandidateFallbackStillPresentsItsReason() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionEmptyFallbackTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let historyStore = try HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
    let clipboardStore = try ClipboardSnapshotStore(fileURL: directory.appendingPathComponent("clipboard.json"))
    let workflow = CaptureWorkflow(
        extractor: EmptyFallbackProvenanceExtractor(),
        validator: ActionValidator(),
        executor: ProvenanceTestExecutor(),
        historyStore: historyStore
    )
    let appState = AppState(
        workflow: workflow,
        historyStore: historyStore,
        clipboardStore: clipboardStore,
        modelAvailabilitySummary: { "Apple Intelligence available" },
        modelIsAvailable: { true }
    )

    appState.captureDemo()
    while appState.isProcessing { await Task.yield() }

    #expect(appState.currentDocument != nil)
    #expect(appState.candidates.isEmpty)
    #expect(appState.activeExtractionProvenance == .deterministicFallback(.modelTimedOut))
    #expect(appState.modelFallbackActive)
    #expect(appState.workspacePresentation.showsModelFallbackNotice)
    #expect(appState.modelFallbackNotice == "Deterministic fallback active — Apple Intelligence timed out.")
}

private actor SequencedProvenanceExtractor: ActionExtracting {
    private var callCount = 0
    private var secondResultContinuation: CheckedContinuation<[ActionCandidate], Never>?
    private var secondStartWaiters: [CheckedContinuation<Void, Never>] = []

    func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        callCount += 1
        if callCount == 1 {
            return [candidate(for: request, provenance: .deterministicFallback(.modelTimedOut))]
        }

        let startWaiters = secondStartWaiters
        secondStartWaiters.removeAll()
        startWaiters.forEach { $0.resume() }
        return await withCheckedContinuation { continuation in
            secondResultContinuation = continuation
        }
    }

    func waitUntilSecondExtractionStarted() async {
        guard secondResultContinuation == nil else { return }
        await withCheckedContinuation { continuation in
            secondStartWaiters.append(continuation)
        }
    }

    func completeSecondExtraction() {
        let document = OCRDocument.singleBlock("Foundation Models fixture")
        let request = ActionExtractionRequest(
            document: document,
            localeIdentifier: "en_US",
            timeZoneIdentifier: "UTC"
        )
        secondResultContinuation?.resume(returning: [candidate(for: request, provenance: .foundationModels)])
        secondResultContinuation = nil
    }

    private func candidate(
        for request: ActionExtractionRequest,
        provenance: ExtractionProvenance
    ) -> ActionCandidate {
        ActionCandidate(
            kind: .textTable,
            title: "Extract text",
            confidence: 0.65,
            sourceText: request.document.normalizedText,
            fields: [.extractedText: request.document.normalizedText],
            validationState: .valid,
            extractionProvenance: provenance
        )
    }
}

private actor FallbackThenThrowExtractor: ActionExtracting {
    private var invocationCount = 0

    func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        invocationCount += 1
        guard invocationCount == 1 else {
            throw FallbackProvenanceTestError.replacementFailed
        }
        return [
            ActionCandidate(
                kind: .textTable,
                title: "Fallback review",
                confidence: 0.65,
                sourceText: request.document.normalizedText,
                fields: [.extractedText: request.document.normalizedText],
                validationState: .valid,
                extractionProvenance: .deterministicFallback(.modelFailed)
            )
        ]
    }
}

private struct EmptyFallbackProvenanceExtractor: ActionExtracting {
    func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        []
    }

    func extractResult(from request: ActionExtractionRequest) async throws -> ActionExtractionResult {
        ActionExtractionResult(
            candidates: [],
            provenance: .deterministicFallback(.modelTimedOut)
        )
    }
}

private enum FallbackProvenanceTestError: Error {
    case replacementFailed
}

private struct ProvenanceTestExecutor: ActionExecuting {
    func execute(_ candidate: ActionCandidate, confirmed: Bool) async throws -> ActionExecutionResult {
        .copiedToClipboard
    }
}
