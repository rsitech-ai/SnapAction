import Foundation
import Testing
@testable import SnapActionCore

@Test func captureWorkflowValidatesCandidatesAndStoresHistoryAfterConfirmedExecution() async throws {
    let historyURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    let history = try HistoryStore(fileURL: historyURL)
    let executor = FakeActionExecutor()
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let workflow = CaptureWorkflow(
        extractor: StaticExtractor(candidates: [
            ActionCandidate(
                kind: .reminder,
                title: "Pay invoice",
                confidence: 0.94,
                sourceText: "Pay invoice tomorrow",
                fields: [.dueDate: "2027-01-16T09:00:00Z"]
            )
        ]),
        validator: ActionValidator(now: now),
        executor: executor,
        historyStore: history
    )

    let session = try await workflow.process(document: .singleBlock("Pay invoice tomorrow"))
    let result = try await workflow.execute(session.candidates[0], confirmed: true, in: session)
    let entries = try history.load()

    #expect(session.candidates[0].validationState == .valid)
    #expect(result == .createdReminder(id: "fake-reminder-1"))
    #expect(entries.count == 1)
    #expect(entries[0].result == result)
}

@Test func captureWorkflowPreservesProvenanceWhenExtractionReturnsNoCandidates() async throws {
    let historyURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    let history = try HistoryStore(fileURL: historyURL)
    let workflow = CaptureWorkflow(
        extractor: EmptyFallbackResultExtractor(),
        validator: ActionValidator(),
        executor: FakeActionExecutor(),
        historyStore: history
    )

    let session = try await workflow.process(document: .singleBlock(""))

    #expect(session.candidates.isEmpty)
    #expect(session.extractionProvenance == .deterministicFallback(.modelTimedOut))
}

private struct StaticExtractor: ActionExtracting {
    let candidates: [ActionCandidate]

    func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        candidates
    }
}

private struct EmptyFallbackResultExtractor: ActionExtracting {
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
