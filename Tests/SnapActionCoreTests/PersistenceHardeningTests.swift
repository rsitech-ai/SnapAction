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
    let restored = try secondStore.load(now: snapshot.updatedAt)
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

@Test func historyJSONPersistsOnlyAnActionSummary() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionHistorySummary-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.json")
    let store = try HistoryStore(fileURL: url)
    let privateText = "PRIVATE OCR TEXT 8d5c9341"
    let privateIdentifier = "event-private-21f0"

    try store.append(
        HistoryEntry(
            document: .singleBlock(privateText),
            candidates: [
                ActionCandidate(
                    kind: .calendarEvent,
                    title: "Reviewed action",
                    confidence: 1,
                    sourceText: privateText,
                    fields: [.notes: "PRIVATE NOTES", .startDate: "2027-01-16T09:00:00Z"],
                    validationState: .valid
                )
            ],
            result: .createdEvent(id: privateIdentifier)
        )
    )

    let data = try Data(contentsOf: url)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    let keys = try #require(object.first).keys.sorted()
    let raw = String(decoding: data, as: UTF8.self)

    #expect(keys == ["capturedAt", "id", "kind", "outcome", "title"])
    #expect(!raw.contains(privateText))
    #expect(!raw.contains("PRIVATE NOTES"))
    #expect(!raw.contains(privateIdentifier))
}

@Test func corruptHistoryIsDeletedWithoutSensitiveBackup() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionCorruptHistory-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.json")
    try "{PRIVATE HISTORY".write(to: url, atomically: true, encoding: .utf8)
    let store = try HistoryStore(fileURL: url)

    #expect(try store.load().isEmpty)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted() == [
        "history.json",
        "history.retention.json"
    ])
}

@Test func corruptClipboardIsDeletedWithoutSensitiveBackup() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionCorruptClipboard-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("clipboard.json")
    try "{PRIVATE CLIPBOARD".write(to: url, atomically: true, encoding: .utf8)
    let store = try ClipboardSnapshotStore(fileURL: url)

    #expect(try store.load() == nil)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
}

@Test func clipboardSnapshotExpiresAndIsDeletedAfterSevenDays() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionExpiredClipboard-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("clipboard.json")
    let store = try ClipboardSnapshotStore(fileURL: url)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    try store.save(
        ClipboardSnapshot(
            title: "Expired",
            text: "PRIVATE EXPIRED CLIPBOARD",
            source: .textTable,
            updatedAt: now.addingTimeInterval(-(7 * 86_400 + 1))
        )
    )

    #expect(try store.load(maxAge: 7 * 86_400, now: now) == nil)
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test func clearingClipboardRemovesPayloadAndLegacyCorruptRemnants() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionClearClipboard-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("clipboard.json")
    let legacyBackup = directory.appendingPathComponent("clipboard.corrupt-123.json")
    let unrelated = directory.appendingPathComponent("unrelated.json")
    let store = try ClipboardSnapshotStore(fileURL: url)
    try store.save(ClipboardSnapshot(title: "Private", text: "SECRET", source: .textTable))
    try "PRIVATE BACKUP".write(to: legacyBackup, atomically: true, encoding: .utf8)
    try "keep".write(to: unrelated, atomically: true, encoding: .utf8)

    try store.clear()

    #expect(!FileManager.default.fileExists(atPath: url.path))
    #expect(!FileManager.default.fileExists(atPath: legacyBackup.path))
    #expect(FileManager.default.fileExists(atPath: unrelated.path))
}

@Test func clearingHistoryReplacesStoredSummariesWithAnEmptyArray() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("SnapActionClearHistory-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.json")
    let store = try HistoryStore(fileURL: url)
    try store.append(
        HistoryEntry(
            capturedAt: Date(),
            title: "Private summary",
            kind: .textTable,
            outcome: .copiedToClipboard
        )
    )

    try store.deleteAll()

    #expect(try store.load().isEmpty)
    #expect(String(decoding: try Data(contentsOf: url), as: UTF8.self).contains("Private summary") == false)
}

private func posixPermissions(at url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return try #require(attributes[.posixPermissions] as? Int)
}
