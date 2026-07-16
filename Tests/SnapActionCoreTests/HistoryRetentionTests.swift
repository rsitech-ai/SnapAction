import Foundation
import Testing
@testable import SnapActionCore

@Test
func historyLoadPrunesEntriesOlderThanTheCalendarDayCutoff() throws {
    let fixture = try RetentionFixture(defaultDays: 30)
    defer { fixture.remove() }
    let recent = fixture.entry(daysAgo: 30, hour: 8, title: "Cutoff day")
    let expired = fixture.entry(daysAgo: 31, hour: 23, title: "Expired")
    try fixture.writeRaw([recent, expired])

    let loaded = try fixture.store.load()

    #expect(loaded.map(\.ocrText) == ["Cutoff day"])
    #expect(try fixture.decodeRaw().map(\.ocrText) == ["Cutoff day"])
}

@Test
func historyAppendAppliesTheCurrentRetentionSetting() throws {
    let fixture = try RetentionFixture(defaultDays: 1)
    defer { fixture.remove() }

    try fixture.store.append(fixture.entry(daysAgo: 2, hour: 12, title: "Expired append"))
    try fixture.store.append(fixture.entry(daysAgo: 0, hour: 9, title: "Current append"))

    #expect(try fixture.store.load().map(\.ocrText) == ["Current append"])
}

@Test
func historyRetentionClampsBoundsAndPersistsTheRestoredValue() throws {
    let fixture = try RetentionFixture(defaultDays: 30)
    defer { fixture.remove() }

    try fixture.store.setRetentionDays(0)
    #expect(fixture.store.retentionDays == 1)

    try fixture.store.setRetentionDays(91)
    #expect(fixture.store.retentionDays == 90)

    try fixture.store.setRetentionDays(30)
    let relaunchedStore = try HistoryStore(
        fileURL: fixture.historyURL,
        now: { fixture.now },
        calendar: fixture.calendar
    )
    #expect(relaunchedStore.retentionDays == 30)
}

@Test
func captureWorkflowObservesRetentionChangesMadeAfterItWasCreated() async throws {
    let fixture = try RetentionFixture(defaultDays: 90)
    defer { fixture.remove() }
    let workflow = CaptureWorkflow(
        extractor: RetentionExtractor(),
        validator: ActionValidator(),
        executor: RetentionExecutor(),
        historyStore: fixture.store
    )
    let document = fixture.document(daysAgo: 2, hour: 12, text: "Old workflow entry")
    let session = try await workflow.process(document: document)

    try fixture.store.setRetentionDays(1)
    _ = try await workflow.execute(session.candidates[0], confirmed: true, in: session)

    #expect(fixture.store.retentionDays == 1)
    #expect(try fixture.store.load().isEmpty)
}

private struct RetentionFixture {
    let directory: URL
    let historyURL: URL
    let now: Date
    let calendar: Calendar
    let store: HistoryStore

    init(defaultDays: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 16,
            hour: 12
        ))!
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SnapActionRetentionTests-\(UUID().uuidString)", isDirectory: true)
        let historyURL = directory.appendingPathComponent("history.json")
        self.directory = directory
        self.historyURL = historyURL
        self.now = now
        self.calendar = calendar
        self.store = try HistoryStore(fileURL: historyURL, now: { now }, calendar: calendar)
        try store.setRetentionDays(defaultDays)
    }

    func document(daysAgo: Int, hour: Int, text: String) -> OCRDocument {
        let startOfToday = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday)!
        let date = calendar.date(byAdding: .hour, value: hour, to: day)!
        return .singleBlock(text, capturedAt: date)
    }

    func entry(daysAgo: Int, hour: Int, title: String) -> HistoryEntry {
        HistoryEntry(document: document(daysAgo: daysAgo, hour: hour, text: title), candidates: [])
    }

    func writeRaw(_ entries: [HistoryEntry]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(entries).write(to: historyURL, options: .atomic)
    }

    func decodeRaw() throws -> [HistoryEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([HistoryEntry].self, from: Data(contentsOf: historyURL))
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}

private struct RetentionExtractor: ActionExtracting {
    func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        [
            ActionCandidate(
                kind: .textTable,
                title: "Extract text",
                confidence: 1,
                sourceText: request.document.normalizedText,
                fields: [.extractedText: request.document.normalizedText]
            )
        ]
    }
}

private struct RetentionExecutor: ActionExecuting {
    func execute(_ candidate: ActionCandidate, confirmed: Bool) async throws -> ActionExecutionResult {
        .copiedToClipboard
    }
}
