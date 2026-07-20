import Foundation
import Testing
@testable import SnapActionCore

@Test func ocrDocumentNormalizesBlocksInReadingOrder() {
    let document = OCRDocument(
        blocks: [
            OCRBlock(text: "second", boundingBox: OCRRect(x: 0.1, y: 0.4, width: 0.4, height: 0.1), confidence: 0.8),
            OCRBlock(text: " first ", boundingBox: OCRRect(x: 0.1, y: 0.1, width: 0.4, height: 0.1), confidence: 0.9),
            OCRBlock(text: "   ", boundingBox: OCRRect(x: 0.1, y: 0.2, width: 0.4, height: 0.1), confidence: 0.3)
        ],
        capturedAt: Date(timeIntervalSince1970: 100)
    )

    #expect(document.normalizedText == "first\nsecond")
    #expect(document.blocks.map(\.text) == ["first", "second"])
}

@Test func modelUnavailableFallbackReturnsOnlyTextCandidate() async throws {
    let extractor = FoundationActionExtractor(
        availability: .unavailable("Apple Intelligence is not enabled."),
        modelProvider: { _ in
            [
                ActionCandidate(
                    kind: .reminder,
                    title: "Should not appear",
                    confidence: 0.9,
                    sourceText: "Call Sam",
                    fields: [.notes: "blocked by availability"]
                )
            ]
        }
    )
    let request = ActionExtractionRequest(
        document: OCRDocument.singleBlock("Call Sam tomorrow\nBudget | 42"),
        localeIdentifier: "en_US",
        timeZoneIdentifier: "America/New_York"
    )

    let candidates = try await extractor.extractCandidates(from: request)

    #expect(candidates.count == 1)
    #expect(candidates.first?.kind == .textTable)
    #expect(candidates.first?.title == "Extract text")
    #expect(candidates.first?.validationState == .warning("Apple Intelligence is not enabled."))
}

@Test func validatorRejectsUnsafeWriteCandidatesAndAcceptsConfirmedText() {
    let validator = ActionValidator(now: Date(timeIntervalSince1970: 1_800_000_000))
    let lowConfidenceReminder = ActionCandidate(
        kind: .reminder,
        title: "Call Sam",
        confidence: 0.39,
        sourceText: "Call Sam",
        fields: [.dueDate: "2027-02-01T09:00:00Z"]
    )
    let missingDateEvent = ActionCandidate(
        kind: .calendarEvent,
        title: "Planning meeting",
        confidence: 0.88,
        sourceText: "Planning meeting",
        fields: [:]
    )
    let textCandidate = ActionCandidate(
        kind: .textTable,
        title: "Extract clean text",
        confidence: 0.4,
        sourceText: "Name | Score\nAda | 10",
        fields: [.extractedText: "Name | Score\nAda | 10"]
    )
    let mismatchedTomorrow = ActionCandidate(
        kind: .reminder,
        title: "File expenses",
        confidence: 0.9,
        sourceText: "File expenses tomorrow",
        fields: [.dueDate: "2027-01-15T09:00:00Z"]
    )

    #expect(validator.validated(lowConfidenceReminder).validationState == .invalid("Reminder confidence is too low to write safely."))
    #expect(validator.validated(missingDateEvent).validationState == .invalid("Calendar events need a start date."))
    #expect(validator.validated(textCandidate).validationState == .valid)
    #expect(validator.validated(mismatchedTomorrow).validationState == .invalid("Reminder due date does not match the source text."))
}

@Test func historyStorePersistsMetadataWithoutScreenshotBytes() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    let store = try HistoryStore(fileURL: url)
    let entry = HistoryEntry(
        document: .singleBlock("Meet Jamie tomorrow at 10"),
        candidates: [
            ActionCandidate(
                kind: .calendarEvent,
                title: "Meet Jamie",
                confidence: 0.92,
                sourceText: "Meet Jamie tomorrow at 10",
                fields: [.startDate: "2027-01-15T10:00:00Z"]
            )
        ],
        result: .createdEvent(id: "event-1")
    )

    try store.append(entry)
    let raw = try String(contentsOf: url, encoding: .utf8)
    let reloaded = try store.load()

    #expect(reloaded.count == 1)
    #expect(raw.contains("Meet Jamie"))
    #expect(!raw.contains("Meet Jamie tomorrow at 10"))
    #expect(!raw.contains("event-1"))
    #expect(!raw.localizedCaseInsensitiveContains("screenshot"))
    #expect(!raw.contains("png"))
    #expect(!raw.contains("base64"))
}

@Test func executorsRequireExplicitConfirmationBeforeExternalWrite() async throws {
    let executor = FakeActionExecutor()
    let reminder = ActionCandidate(
        kind: .reminder,
        title: "File expenses",
        confidence: 0.91,
        sourceText: "File expenses tomorrow",
        fields: [.dueDate: "2027-03-01T09:00:00Z"],
        validationState: .valid
    )

    let blocked = try await executor.execute(reminder, confirmed: false)
    let written = try await executor.execute(reminder, confirmed: true)

    #expect(blocked == .failed(message: "Confirmation is required before writing outside SnapAction."))
    #expect(written == .createdReminder(id: "fake-reminder-1"))
    #expect(executor.executed.count == 1)
}
