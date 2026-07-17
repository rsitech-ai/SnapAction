import Foundation

public struct ClipboardSnapshot: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var text: String
    public var source: ActionKind
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        text: String,
        source: ActionKind,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.text = text
        self.source = source
        self.updatedAt = updatedAt
    }
}

public struct ClipboardSnapshotStore: Sendable {
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try PersistencePermissions.restrictFile(fileURL)
        }
    }

    public func load() throws -> ClipboardSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            guard !data.isEmpty else { return nil }
            return try decoder.decode(ClipboardSnapshot.self, from: data)
        } catch {
            try recoverCorruptFile()
            return nil
        }
    }

    public func save(_ snapshot: ClipboardSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
        try PersistencePermissions.restrictFile(fileURL)
    }

    private func recoverCorruptFile() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let backup = fileURL.deletingPathExtension()
            .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.removeItem(at: backup)
        try FileManager.default.moveItem(at: fileURL, to: backup)
    }
}
