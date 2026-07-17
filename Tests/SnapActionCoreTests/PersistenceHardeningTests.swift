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

@Test func persistenceFilesAreRestrictedToTheCurrentUser() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionPersistencePermissions-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let historyURL = directory.appendingPathComponent("history.json")
    let clipboardURL = directory.appendingPathComponent("clipboard.json")
    let historyStore = try HistoryStore(fileURL: historyURL)
    let clipboardStore = try ClipboardSnapshotStore(fileURL: clipboardURL)

    try historyStore.setRetentionDays(30)
    try clipboardStore.save(
        ClipboardSnapshot(title: "Private payload", text: "Local-only text", source: .textTable)
    )

    let retentionURL = historyURL.deletingPathExtension().appendingPathExtension("retention.json")
    #expect(try posixPermissions(at: historyURL) == 0o600)
    #expect(try posixPermissions(at: retentionURL) == 0o600)
    #expect(try posixPermissions(at: clipboardURL) == 0o600)
}

private func posixPermissions(at url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return try #require(attributes[.posixPermissions] as? Int)
}
