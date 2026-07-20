import Foundation

public enum HistoryOutcome: String, Codable, Equatable, Sendable {
    case createdReminder
    case createdEvent
    case copiedToClipboard
    case failed
    case unknown

    public init(_ result: ActionExecutionResult?) {
        switch result {
        case .createdReminder: self = .createdReminder
        case .createdEvent: self = .createdEvent
        case .copiedToClipboard: self = .copiedToClipboard
        case .failed: self = .failed
        case nil: self = .unknown
        }
    }

    public var displayMessage: String {
        switch self {
        case .createdReminder: "Reminder created"
        case .createdEvent: "Calendar event created"
        case .copiedToClipboard: "Copied to clipboard"
        case .failed: "Action failed"
        case .unknown: "Action completed"
        }
    }
}

public struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var capturedAt: Date
    public var title: String
    public var kind: ActionKind
    public var outcome: HistoryOutcome

    public init(
        id: UUID = UUID(),
        capturedAt: Date,
        title: String,
        kind: ActionKind,
        outcome: HistoryOutcome
    ) {
        self.id = id
        self.capturedAt = capturedAt
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = normalizedTitle.isEmpty ? kind.displayName : normalizedTitle
        self.kind = kind
        self.outcome = outcome
    }

    public init(
        id: UUID = UUID(),
        document: OCRDocument,
        candidates: [ActionCandidate],
        result: ActionExecutionResult? = nil
    ) {
        let candidate = candidates.first
        self.init(
            id: id,
            capturedAt: document.capturedAt,
            title: candidate?.title ?? "Captured text",
            kind: candidate?.kind ?? .textTable,
            outcome: HistoryOutcome(result)
        )
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
        try PersistencePermissions.restrictDirectory(directory)
        self.retentionPreferences = try HistoryRetentionPreferences(
            fileURL: fileURL.deletingPathExtension().appendingPathExtension("retention.json")
        )
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try Data("[]".utf8).write(to: fileURL, options: .atomic)
        }
        try PersistencePermissions.restrictFile(fileURL)
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

    public func deleteAll() throws {
        try coordinator.withLock {
            try write([])
        }
    }

    private func loadLocked() throws -> [HistoryEntry] {
        let entries: [HistoryEntry]
        let requiresMigration: Bool
        do {
            let data = try Data(contentsOf: fileURL)
            if let currentEntries = try? decoder.decode([HistoryEntry].self, from: data) {
                entries = currentEntries
                requiresMigration = false
            } else {
                let legacyEntries = try decoder.decode([LegacyHistoryEntry].self, from: data)
                entries = legacyEntries.map(HistoryEntry.init(legacy:))
                requiresMigration = true
            }
        } catch {
            try deleteSensitiveHistoryArtifacts()
            try Data("[]".utf8).write(to: fileURL, options: .atomic)
            try PersistencePermissions.restrictFile(fileURL)
            return []
        }

        let retained = retainedEntries(from: entries)
        if requiresMigration || retained != entries {
            try write(retained)
        }
        return retained
    }

    private func retainedEntries(from entries: [HistoryEntry]) -> [HistoryEntry] {
        let startOfToday = calendar.startOfDay(for: now())
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: 1 - retentionPreferences.days,
            to: startOfToday
        ) else {
            return entries
        }
        return entries.filter { $0.capturedAt >= cutoff }
    }

    private func write(_ entries: [HistoryEntry]) throws {
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic)
        try PersistencePermissions.restrictDirectory(fileURL.deletingLastPathComponent())
        try PersistencePermissions.restrictFile(fileURL)
    }

    private func deleteSensitiveHistoryArtifacts() throws {
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
        try PersistencePermissions.restrictDirectory(directory)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let payload = try JSONDecoder().decode(Payload.self, from: Data(contentsOf: fileURL))
                let normalizedDays = Self.normalized(payload.days)
                self.storedDays = normalizedDays
                if normalizedDays != payload.days {
                    try Self.write(normalizedDays, to: fileURL)
                }
            } catch {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                self.storedDays = 30
                try Self.write(30, to: fileURL)
            }
        } else {
            self.storedDays = 30
            try Self.write(30, to: fileURL)
        }
        try PersistencePermissions.restrictFile(fileURL)
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
        try PersistencePermissions.restrictFile(fileURL)
    }
}

private struct LegacyHistoryEntry: Codable {
    var id: UUID
    var capturedAt: Date
    var ocrText: String
    var candidates: [ActionCandidate]
    var result: ActionExecutionResult?
}

private extension HistoryEntry {
    init(legacy entry: LegacyHistoryEntry) {
        let candidate = entry.candidates.first
        self.init(
            id: entry.id,
            capturedAt: entry.capturedAt,
            title: candidate?.title ?? "Captured text",
            kind: candidate?.kind ?? .textTable,
            outcome: HistoryOutcome(entry.result)
        )
    }
}
