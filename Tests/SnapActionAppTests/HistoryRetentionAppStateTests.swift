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
    #expect(firstAppState.history.map(\.title) == ["Current entry"])
    #expect(try firstStore.load().map(\.title) == ["Current entry"])

    let relaunchedStore = try HistoryStore(fileURL: historyURL, now: { now }, calendar: calendar)
    let relaunchedAppState = try makeRetentionAppState(
        historyStore: relaunchedStore,
        clipboardURL: clipboardURL
    )

    #expect(relaunchedStore.retentionDays == 30)
    #expect(relaunchedAppState.historyRetentionDays == 30)
    #expect(relaunchedAppState.history.map(\.title) == ["Current entry"])
}

@Test
@MainActor
func appStateClearsHistoryAndSavedClipboard() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionAppClearData-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let historyURL = directory.appendingPathComponent("history.json")
    let clipboardURL = directory.appendingPathComponent("clipboard.json")
    let historyStore = try HistoryStore(fileURL: historyURL)
    let clipboardStore = try ClipboardSnapshotStore(fileURL: clipboardURL)
    try historyStore.append(
        HistoryEntry(capturedAt: Date(), title: "Saved summary", kind: .textTable, outcome: .copiedToClipboard)
    )
    try clipboardStore.save(
        ClipboardSnapshot(title: "Saved clipboard", text: "PRIVATE", source: .textTable)
    )
    let workflow = CaptureWorkflow(
        extractor: RuleBasedFallbackExtractor(),
        validator: ActionValidator(),
        executor: RetentionAppExecutor(),
        historyStore: historyStore
    )
    let appState = AppState(
        workflow: workflow,
        historyStore: historyStore,
        clipboardStore: clipboardStore,
        modelAvailabilitySummary: { "Apple Intelligence available" },
        modelIsAvailable: { true }
    )

    #expect(appState.history.count == 1)
    #expect(appState.lastClipboardSnapshot != nil)

    appState.clearHistory()
    appState.clearSavedClipboard()

    #expect(appState.history.isEmpty)
    #expect(try historyStore.load().isEmpty)
    #expect(appState.lastClipboardSnapshot == nil)
    #expect(try clipboardStore.load() == nil)
    #expect(appState.clipboardStatus == "No saved clipboard yet")
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
    return HistoryEntry(
        capturedAt: day,
        title: text,
        kind: .textTable,
        outcome: .unknown
    )
}

private struct RetentionAppExecutor: ActionExecuting {
    func execute(_ candidate: ActionCandidate, confirmed: Bool) async throws -> ActionExecutionResult {
        .copiedToClipboard
    }
}
