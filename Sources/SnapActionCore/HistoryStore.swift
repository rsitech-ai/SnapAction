import Foundation

public struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var capturedAt: Date
    public var ocrText: String
    public var candidates: [ActionCandidate]
    public var result: ActionExecutionResult?

    public init(
        id: UUID = UUID(),
        document: OCRDocument,
        candidates: [ActionCandidate],
        result: ActionExecutionResult? = nil
    ) {
        self.id = id
        self.capturedAt = document.capturedAt
        self.ocrText = document.normalizedText
        self.candidates = candidates
        self.result = result
    }
}

public struct HistoryStore: Sendable {
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
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try Data("[]".utf8).write(to: fileURL, options: .atomic)
        }
    }

    public func load() throws -> [HistoryEntry] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([HistoryEntry].self, from: data)
        } catch {
            try recoverCorruptFile()
            try Data("[]".utf8).write(to: fileURL, options: .atomic)
            return []
        }
    }

    public func append(_ entry: HistoryEntry) throws {
        var entries = try load()
        entries.insert(entry, at: 0)
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic)
    }

    private func recoverCorruptFile() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let backup = fileURL.deletingPathExtension()
            .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.removeItem(at: backup)
        try FileManager.default.moveItem(at: fileURL, to: backup)
    }
}
