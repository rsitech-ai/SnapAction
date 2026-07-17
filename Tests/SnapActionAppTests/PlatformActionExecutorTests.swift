import Foundation
import SnapActionCore
import Testing
@testable import SnapActionApp

@Test
func clipboardExecutionReportsPasteboardWriteFailure() async throws {
    let executor = PlatformActionExecutor(clipboardWriter: { _ in false })

    let result = try await executor.execute(validClipboardCandidate(), confirmed: true)

    #expect(result == .failed(message: "SnapAction couldn’t write the extracted text to the clipboard."))
}

@Test
func clipboardExecutionReportsSnapshotPersistenceFailure() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionClipboardFailure-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = try ClipboardSnapshotStore(fileURL: directory.appendingPathComponent("clipboard.json"))
    try FileManager.default.removeItem(at: directory)
    try Data().write(to: directory)
    let executor = PlatformActionExecutor(clipboardStore: store, clipboardWriter: { _ in true })

    let result = try await executor.execute(validClipboardCandidate(), confirmed: true)

    #expect(result == .failed(message: "Copied, but SnapAction couldn’t save a restore snapshot."))
}

@Test
@MainActor
func clipboardRestoreReportsPasteboardWriteFailure() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionClipboardRestore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let historyStore = try HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
    let clipboardStore = try ClipboardSnapshotStore(fileURL: directory.appendingPathComponent("clipboard.json"))
    try clipboardStore.save(
        ClipboardSnapshot(title: "Saved extract", text: "Private text", source: .textTable)
    )
    let workflow = CaptureWorkflow(
        extractor: RuleBasedFallbackExtractor(),
        validator: ActionValidator(),
        executor: FakeActionExecutor(),
        historyStore: historyStore
    )
    let appState = AppState(
        workflow: workflow,
        historyStore: historyStore,
        clipboardStore: clipboardStore,
        clipboardWriter: { _ in false }
    )

    appState.restoreSavedClipboard()

    #expect(appState.clipboardStatus == "Could not restore the saved clipboard")
}

private func validClipboardCandidate() -> ActionCandidate {
    ActionCandidate(
        kind: .textTable,
        title: "Extracted table",
        confidence: 1,
        sourceText: "Name | Score",
        fields: [.tableMarkdown: "Name | Score\nAda | 10"],
        validationState: .valid
    )
}
