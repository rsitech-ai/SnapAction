import Foundation
import SnapActionCore

#if canImport(FoundationModels)
import FoundationModels

@Generable
struct GeneratedSnapActions: Sendable {
    @Guide(description: "One to three likely actions found in the OCR text", .count(1...3))
    let actions: [GeneratedSnapAction]
}

@Generable
struct GeneratedSnapAction: Sendable {
    let kind: GeneratedSnapActionKind
    @Guide(description: "Short user-facing title copied or summarized from the OCR text")
    let title: String
    @Guide(description: "Confidence from 0.0 to 1.0")
    let confidence: Double
    @Guide(description: "Exact source text supporting the action")
    let sourceText: String
    @Guide(description: "ISO-8601 due date for reminders, or empty when absent")
    let dueDate: String
    @Guide(description: "ISO-8601 start date for calendar events, or empty when absent")
    let startDate: String
    @Guide(description: "ISO-8601 end date for calendar events, or empty when absent")
    let endDate: String
    @Guide(description: "Clean extracted text or markdown table for text/table actions")
    let extractedText: String
    @Guide(description: "Optional notes, location, or context")
    let notes: String
}

@Generable
enum GeneratedSnapActionKind: Sendable {
    case reminder
    case calendarEvent
    case textTable
}
#endif

struct LocalFoundationModelsExtractor: ActionExtracting {
    private let fallback: any ActionExtracting

    init(fallback: any ActionExtracting) {
        self.fallback = fallback
    }

    func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            do {
                let session = LanguageModelSession(instructions: Instructions(Self.instructions))
                let response = try await session.respond(
                    to: Prompt(Self.prompt(for: request)),
                    generating: GeneratedSnapActions.self
                )
                let candidates = response.content.actions.map(Self.convert(_:))
                if !candidates.isEmpty {
                    return candidates
                }
            } catch {
                return try await fallback.extractCandidates(from: request).map { candidate in
                    var copy = candidate
                    copy.validationState = .warning("Apple Intelligence extraction failed; using deterministic text extraction.")
                    return copy
                }
            }
        case .unavailable(let reason):
            return [
                ActionCandidate(
                    kind: .textTable,
                    title: "Extract text",
                    confidence: 1,
                    sourceText: request.document.normalizedText,
                    fields: [.extractedText: request.document.normalizedText],
                    validationState: .warning("Apple Intelligence unavailable: \(reason)")
                )
            ]
        @unknown default:
            break
        }
        #endif

        return try await fallback.extractCandidates(from: request)
    }

    static func availabilitySummary() -> String {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Apple Intelligence available"
        case .unavailable(let reason):
            return "Apple Intelligence unavailable: \(reason)"
        @unknown default:
            return "Apple Intelligence availability unknown"
        }
        #else
        return "Foundation Models framework unavailable"
        #endif
    }

    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        #endif
        return false
    }

    private static let instructions = """
    Extract only actions supported by SnapAction: reminders, calendar events, and text/table extraction.
    Use only facts present in the OCR text. Do not invent missing dates, names, or locations.
    Dates must be ISO-8601 with timezone when the OCR text gives enough information.
    If the text is mostly a table or notes, return a textTable action.
    """

    private static func prompt(for request: ActionExtractionRequest) -> String {
        """
        Locale: \(request.localeIdentifier)
        Time zone: \(request.timeZoneIdentifier)
        Capture timestamp: \(request.document.capturedAt.formatted(.iso8601))
        Resolve relative dates such as "tomorrow" from the capture timestamp.

        OCR text:
        \(request.document.normalizedText)
        """
    }

    #if canImport(FoundationModels)
    private static func convert(_ action: GeneratedSnapAction) -> ActionCandidate {
        var fields: [ActionField: String] = [:]
        switch action.kind {
        case .reminder:
            if !action.dueDate.isEmpty { fields[.dueDate] = action.dueDate }
            if !action.notes.isEmpty { fields[.notes] = action.notes }
        case .calendarEvent:
            if !action.startDate.isEmpty { fields[.startDate] = action.startDate }
            if !action.endDate.isEmpty { fields[.endDate] = action.endDate }
            if !action.notes.isEmpty { fields[.notes] = action.notes }
        case .textTable:
            if !action.extractedText.isEmpty { fields[.extractedText] = action.extractedText }
            if !action.notes.isEmpty { fields[.notes] = action.notes }
        }

        return ActionCandidate(
            kind: convert(action.kind),
            title: action.title,
            confidence: min(max(action.confidence, 0), 1),
            sourceText: action.sourceText,
            fields: fields
        )
    }

    private static func convert(_ kind: GeneratedSnapActionKind) -> ActionKind {
        switch kind {
        case .reminder:
            .reminder
        case .calendarEvent:
            .calendarEvent
        case .textTable:
            .textTable
        }
    }
    #endif
}
