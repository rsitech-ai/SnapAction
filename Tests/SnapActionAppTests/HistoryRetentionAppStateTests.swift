import Foundation
import SnapActionCore
import Testing
@testable import SnapActionApp

@Test
@MainActor
func appStatePrunesImmediatelyAndRestoresRetentionAfterRelaunch() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 16, hour: 12))!
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionAppRetentionTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let historyURL = directory.appendingPathComponent("history.json")
    let clipboardURL = directory.appendingPathComponent("clipboard.json")
    let firstStore = try HistoryStore(fileURL: historyURL, now: { now }, calendar: calendar)
    try firstStore.setRetentionDays(90)
    try firstStore.append(retentionEntry(calendar: calendar, now: now, daysAgo: 40, text: "Old entry"))
    try firstStore.append(retentionEntry(calendar: calendar, now: now, daysAgo: 0, text: "Current entry"))
    let firstAppState = try makeRetentionAppState(historyStore: firstStore, clipboardURL: clipboardURL)

    #expect(firstAppState.historyRetentionDays == 90)
    #expect(firstAppState.history.count == 2)

    firstAppState.updateHistoryRetentionDays(30)

    #expect(firstAppState.historyRetentionDays == 30)
    #expect(firstAppState.history.map(\.ocrText) == ["Current entry"])
    #expect(try firstStore.load().map(\.ocrText) == ["Current entry"])

    let relaunchedStore = try HistoryStore(fileURL: historyURL, now: { now }, calendar: calendar)
    let relaunchedAppState = try makeRetentionAppState(
        historyStore: relaunchedStore,
        clipboardURL: clipboardURL
    )

    #expect(relaunchedStore.retentionDays == 30)
    #expect(relaunchedAppState.historyRetentionDays == 30)
    #expect(relaunchedAppState.history.map(\.ocrText) == ["Current entry"])
}

@MainActor
private func makeRetentionAppState(
    historyStore: HistoryStore,
    clipboardURL: URL
) throws -> AppState {
    let clipboardStore = try ClipboardSnapshotStore(fileURL: clipboardURL)
    let workflow = CaptureWorkflow(
        extractor: RuleBasedFallbackExtractor(),
        validator: ActionValidator(),
        executor: RetentionAppExecutor(),
        historyStore: historyStore
    )
    return AppState(
        workflow: workflow,
        historyStore: historyStore,
        clipboardStore: clipboardStore,
        modelAvailabilitySummary: { "Apple Intelligence available" },
        modelIsAvailable: { true }
    )
}

private func retentionEntry(
    calendar: Calendar,
    now: Date,
    daysAgo: Int,
    text: String
) -> HistoryEntry {
    let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
    return HistoryEntry(document: .singleBlock(text, capturedAt: day), candidates: [])
}

private struct RetentionAppExecutor: ActionExecuting {
    func execute(_ candidate: ActionCandidate, confirmed: Bool) async throws -> ActionExecutionResult {
        .copiedToClipboard
    }
}
