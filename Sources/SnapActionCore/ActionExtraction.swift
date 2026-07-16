import Foundation

public struct ActionExtractionRequest: Codable, Equatable, Sendable {
    public var document: OCRDocument
    public var localeIdentifier: String
    public var timeZoneIdentifier: String

    public init(document: OCRDocument, localeIdentifier: String, timeZoneIdentifier: String) {
        self.document = document
        self.localeIdentifier = localeIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

public enum ModelAvailability: Equatable, Sendable {
    case available
    case unavailable(String)
}

public protocol ActionExtracting: Sendable {
    func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate]
}

public struct FoundationActionExtractor: ActionExtracting {
    public typealias ModelProvider = @Sendable (ActionExtractionRequest) async throws -> [ActionCandidate]

    private let availability: ModelAvailability
    private let modelProvider: ModelProvider

    public init(
        availability: ModelAvailability,
        modelProvider: @escaping ModelProvider
    ) {
        self.availability = availability
        self.modelProvider = modelProvider
    }

    public func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        switch availability {
        case .available:
            return try await modelProvider(request)
                .prefix(3)
                .map { ActionValidator().validated($0) }
        case .unavailable(let reason):
            return [
                ActionCandidate(
                    kind: .textTable,
                    title: "Extract text",
                    confidence: 1,
                    sourceText: request.document.normalizedText,
                    fields: [.extractedText: request.document.normalizedText],
                    validationState: .warning(reason),
                    extractionProvenance: .deterministicFallback(.modelUnavailable)
                )
            ]
        }
    }
}

public struct RuleBasedFallbackExtractor: ActionExtracting {
    public init() {}

    public func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        let text = request.document.normalizedText
        guard !text.isEmpty else { return [] }

        return [
            ActionCandidate(
                kind: .textTable,
                title: text.contains("|") ? "Extract table" : "Extract text",
                confidence: 0.65,
                sourceText: text,
                fields: [.extractedText: text],
                validationState: .valid
            )
        ]
    }
}
