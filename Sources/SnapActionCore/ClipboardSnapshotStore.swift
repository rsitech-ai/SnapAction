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
    public static let defaultMaximumAge: TimeInterval = 7 * 86_400

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
        try PersistencePermissions.restrictDirectory(directory)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try PersistencePermissions.restrictFile(fileURL)
        }
    }

    public func load(
        maxAge: TimeInterval = Self.defaultMaximumAge,
        now: Date = Date()
    ) throws -> ClipboardSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        guard maxAge >= 0 else {
            try clear()
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            guard !data.isEmpty else { return nil }
            let snapshot = try decoder.decode(ClipboardSnapshot.self, from: data)
            let age = now.timeIntervalSince(snapshot.updatedAt)
            guard age >= 0, age <= maxAge else {
                try clear()
                return nil
            }
            return snapshot
        } catch {
            try clear()
            return nil
        }
    }

    public func save(_ snapshot: ClipboardSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
        try PersistencePermissions.restrictDirectory(fileURL.deletingLastPathComponent())
        try PersistencePermissions.restrictFile(fileURL)
    }

    public func clear() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        let directory = fileURL.deletingLastPathComponent()
        let prefix = "\(fileURL.deletingPathExtension().lastPathComponent).corrupt-"
        for sibling in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where sibling.lastPathComponent.hasPrefix(prefix) {
            try fileManager.removeItem(at: sibling)
        }
    }
}
