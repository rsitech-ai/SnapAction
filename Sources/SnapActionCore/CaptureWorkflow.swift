import Foundation

public struct CaptureSession: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var document: OCRDocument
    public var candidates: [ActionCandidate]
    public var extractionProvenance: ExtractionProvenance?

    public init(
        id: UUID = UUID(),
        document: OCRDocument,
        candidates: [ActionCandidate],
        extractionProvenance: ExtractionProvenance? = nil
    ) {
        self.id = id
        self.document = document
        self.candidates = candidates
        self.extractionProvenance = extractionProvenance ?? candidates.compactMap(\.extractionProvenance).first
    }
}

public struct CaptureWorkflow: Sendable {
    private let extractor: any ActionExtracting
    private let validator: ActionValidator
    private let executor: any ActionExecuting
    private let historyStore: HistoryStore

    public init(
        extractor: any ActionExtracting,
        validator: ActionValidator,
        executor: any ActionExecuting,
        historyStore: HistoryStore
    ) {
        self.extractor = extractor
        self.validator = validator
        self.executor = executor
        self.historyStore = historyStore
    }

    public func process(
        document: OCRDocument,
        localeIdentifier: String = Locale.current.identifier,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) async throws -> CaptureSession {
        let request = ActionExtractionRequest(
            document: document,
            localeIdentifier: localeIdentifier,
            timeZoneIdentifier: timeZoneIdentifier
        )
        let extraction = try await extractor.extractResult(from: request)
        let candidates = extraction.candidates
            .map { validator.validated($0) }
            .prefix(3)
        return CaptureSession(
            document: document,
            candidates: Array(candidates),
            extractionProvenance: extraction.provenance
        )
    }

    public func execute(
        _ candidate: ActionCandidate,
        confirmed: Bool,
        in session: CaptureSession
    ) async throws -> ActionExecutionResult {
        let result = try await executor.execute(candidate, confirmed: confirmed)
        if confirmed {
            try historyStore.append(
                HistoryEntry(
                    document: session.document,
                    candidates: session.candidates,
                    result: result
                )
            )
        }
        return result
    }
}
