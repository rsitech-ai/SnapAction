import Foundation

public enum ActionKind: String, Codable, CaseIterable, Equatable, Sendable {
    case reminder
    case calendarEvent
    case textTable

    public var displayName: String {
        switch self {
        case .reminder:
            "Create reminder"
        case .calendarEvent:
            "Create calendar event"
        case .textTable:
            "Extract text/table"
        }
    }
}

public enum ActionField: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case dueDate
    case startDate
    case endDate
    case notes
    case location
    case extractedText
    case tableMarkdown
}

public enum ValidationState: Codable, Equatable, Sendable {
    case pending
    case valid
    case warning(String)
    case invalid(String)
}

public struct ActionCandidate: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: ActionKind
    public var title: String
    public var confidence: Double
    public var sourceText: String
    public var fields: [ActionField: String]
    public var validationState: ValidationState

    public init(
        id: UUID = UUID(),
        kind: ActionKind,
        title: String,
        confidence: Double,
        sourceText: String,
        fields: [ActionField: String],
        validationState: ValidationState = .pending
    ) {
        self.id = id
        self.kind = kind
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.confidence = confidence
        self.sourceText = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.fields = fields.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.validationState = validationState
    }
}

public enum ActionExecutionResult: Codable, Equatable, Sendable {
    case createdReminder(id: String)
    case createdEvent(id: String)
    case copiedToClipboard
    case failed(message: String)

    public var displayMessage: String {
        switch self {
        case .createdReminder:
            "Reminder created"
        case .createdEvent:
            "Calendar event created"
        case .copiedToClipboard:
            "Copied to clipboard"
        case .failed(let message):
            message
        }
    }
}
