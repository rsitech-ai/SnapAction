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
    private let retentionPreferences: HistoryRetentionPreferences
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let coordinator: HistoryStorageCoordinator

    public init(
        fileURL: URL,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.now = now
        self.calendar = calendar
        self.coordinator = HistoryStorageCoordinator()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.retentionPreferences = try HistoryRetentionPreferences(
            fileURL: fileURL.deletingPathExtension().appendingPathExtension("retention.json")
        )
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try Data("[]".utf8).write(to: fileURL, options: .atomic)
        }
    }

    public var retentionDays: Int {
        retentionPreferences.days
    }

    public func load() throws -> [HistoryEntry] {
        try coordinator.withLock {
            try loadLocked()
        }
    }

    public func setRetentionDays(_ days: Int) throws {
        try coordinator.withLock {
            try retentionPreferences.setDays(days)
            _ = try loadLocked()
        }
    }

    public func append(_ entry: HistoryEntry) throws {
        try coordinator.withLock {
            var entries = try loadLocked()
            entries.insert(entry, at: 0)
            try write(retainedEntries(from: entries))
        }
    }

    private func loadLocked() throws -> [HistoryEntry] {
        let entries: [HistoryEntry]
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try decoder.decode([HistoryEntry].self, from: data)
        } catch {
            try recoverCorruptFile()
            try Data("[]".utf8).write(to: fileURL, options: .atomic)
            return []
        }

        let retained = retainedEntries(from: entries)
        if retained != entries {
            try write(retained)
        }
        return retained
    }

    private func retainedEntries(from entries: [HistoryEntry]) -> [HistoryEntry] {
        let startOfToday = calendar.startOfDay(for: now())
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: -retentionPreferences.days,
            to: startOfToday
        ) else {
            return entries
        }
        return entries.filter { $0.capturedAt >= cutoff }
    }

    private func write(_ entries: [HistoryEntry]) throws {
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

private final class HistoryStorageCoordinator: @unchecked Sendable {
    private let lock = NSRecursiveLock()

    func withLock<Value>(_ operation: () throws -> Value) rethrows -> Value {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class HistoryRetentionPreferences: @unchecked Sendable {
    private struct Payload: Codable {
        var days: Int
    }

    private let fileURL: URL
    private let lock = NSLock()
    private var storedDays: Int

    init(fileURL: URL) throws {
        self.fileURL = fileURL
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let payload = try JSONDecoder().decode(Payload.self, from: Data(contentsOf: fileURL))
                let normalizedDays = Self.normalized(payload.days)
                self.storedDays = normalizedDays
                if normalizedDays != payload.days {
                    try Self.write(normalizedDays, to: fileURL)
                }
            } catch {
                let backup = fileURL.deletingPathExtension()
                    .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.removeItem(at: backup)
                try? FileManager.default.moveItem(at: fileURL, to: backup)
                self.storedDays = 30
                try Self.write(30, to: fileURL)
            }
        } else {
            self.storedDays = 30
            try Self.write(30, to: fileURL)
        }
    }

    var days: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedDays
    }

    func setDays(_ days: Int) throws {
        let normalizedDays = Self.normalized(days)
        lock.lock()
        defer { lock.unlock() }
        try Self.write(normalizedDays, to: fileURL)
        storedDays = normalizedDays
    }

    private static func normalized(_ days: Int) -> Int {
        min(max(days, 1), 90)
    }

    private static func write(_ days: Int, to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Payload(days: days))
        try data.write(to: fileURL, options: .atomic)
    }
}
