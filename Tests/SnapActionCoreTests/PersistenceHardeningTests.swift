import Foundation
import Testing
@testable import SnapActionCore

@Test func clipboardSnapshotStoreRestoresLastCopiedPayloadAcrossLaunches() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    let firstStore = try ClipboardSnapshotStore(fileURL: url)
    let snapshot = ClipboardSnapshot(
        title: "Revenue table",
        text: "Quarter | ARR\nQ1 | 42",
        source: .textTable,
        updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
    )

    try firstStore.save(snapshot)
    let secondStore = try ClipboardSnapshotStore(fileURL: url)
    let restored = try secondStore.load()
    let raw = try String(contentsOf: url, encoding: .utf8)

    #expect(restored == snapshot)
    #expect(raw.contains("Revenue table"))
    #expect(!raw.localizedCaseInsensitiveContains("screenshot"))
    #expect(!raw.contains("base64"))
}

@Test func historyStoreRecoversCorruptFileAndAllowsNewWrites() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    try "{not valid json".write(to: url, atomically: true, encoding: .utf8)

    let store = try HistoryStore(fileURL: url)
    let recovered = try store.load()
    try store.append(
        HistoryEntry(
            document: .singleBlock("Copy this"),
            candidates: [
                ActionCandidate(
                    kind: .textTable,
                    title: "Copy this",
                    confidence: 1,
                    sourceText: "Copy this",
                    fields: [.extractedText: "Copy this"],
                    validationState: .valid
                )
            ],
            result: .copiedToClipboard
        )
    )
    let reloaded = try store.load()

    #expect(recovered.isEmpty)
    #expect(reloaded.count == 1)
}
