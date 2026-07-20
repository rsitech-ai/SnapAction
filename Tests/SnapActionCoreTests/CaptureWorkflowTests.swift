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
    #expect(entries[0].outcome == .createdReminder)
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

@Test func captureWorkflowRejectsForeignAndFreshlyInvalidCandidates() async throws {
    let fixture = try makeExecutionBoundaryFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let session = try await fixture.workflow.process(document: .singleBlock("Name | Score"))
    let foreign = ActionCandidate(
        kind: .textTable,
        title: "Foreign",
        confidence: 1,
        sourceText: "Foreign",
        fields: [.extractedText: "Foreign"],
        validationState: .valid
    )
    var invalidEdit = try #require(session.candidates.first)
    invalidEdit.title = " \n\t "
    invalidEdit.validationState = .valid

    let foreignResult = try await fixture.workflow.execute(foreign, confirmed: true, in: session)
    let invalidResult = try await fixture.workflow.execute(invalidEdit, confirmed: true, in: session)

    #expect(foreignResult == .failed(message: "This action is no longer available. Capture it again before trying to execute it."))
    #expect(invalidResult == .failed(message: "This action is not valid. Review it before trying again."))
    #expect(fixture.executor.executed.isEmpty)
    #expect(try fixture.history.load().isEmpty)
}

@Test func captureWorkflowNormalizesAndRevalidatesTheFinalEditedCandidate() async throws {
    let fixture = try makeExecutionBoundaryFixture()
    defer { try? FileManager.default.removeItem(at: fixture.directory) }
    let session = try await fixture.workflow.process(document: .singleBlock("Name | Score"))
    var edited = try #require(session.candidates.first)
    edited.title = "  Quarterly scores \n"
    edited.sourceText = "  Name | Score \n"
    edited.fields = [.tableMarkdown: "  Name | Score \n"]
    edited.validationState = .invalid("Stale validation")

    let result = try await fixture.workflow.execute(edited, confirmed: true, in: session)

    #expect(result == .copiedToClipboard)
    #expect(fixture.executor.executed.first?.title == "Quarterly scores")
    #expect(fixture.executor.executed.first?.sourceText == "Name | Score")
    #expect(fixture.executor.executed.first?.fields[.tableMarkdown] == "Name | Score")
    #expect(fixture.executor.executed.first?.validationState == .valid)
    #expect(try fixture.history.load().first?.title == "Quarterly scores")
}

@Test func actionValidatorUsesTheCurrentInjectedClockForEachValidation() {
    final class Clock: @unchecked Sendable {
        var now: Date
        init(now: Date) { self.now = now }
    }
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let clock = Clock(now: start)
    let validator = ActionValidator(nowProvider: { clock.now })
    let candidate = ActionCandidate(
        kind: .calendarEvent,
        title: "Current event",
        confidence: 1,
        sourceText: "Current event",
        fields: [.startDate: ISO8601DateFormatter().string(from: start.addingTimeInterval(120))]
    )

    #expect(validator.validated(candidate).validationState == .valid)
    clock.now = start.addingTimeInterval(3_600)
    #expect(validator.validated(candidate).validationState == .warning("Calendar event starts in the past."))
}

private func makeExecutionBoundaryFixture() throws -> (
    directory: URL,
    history: HistoryStore,
    executor: FakeActionExecutor,
    workflow: CaptureWorkflow
) {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionExecutionBoundary-\(UUID().uuidString)", isDirectory: true)
    let history = try HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
    let executor = FakeActionExecutor()
    let candidate = ActionCandidate(
        kind: .textTable,
        title: "Extract scores",
        confidence: 1,
        sourceText: "Name | Score",
        fields: [.tableMarkdown: "Name | Score"]
    )
    let workflow = CaptureWorkflow(
        extractor: StaticExtractor(candidates: [candidate]),
        validator: ActionValidator(),
        executor: executor,
        historyStore: history
    )
    return (directory, history, executor, workflow)
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
