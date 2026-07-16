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
    private let attemptGate: FoundationModelAttemptGate

    init(
        fallback: any ActionExtracting,
        attemptGate: FoundationModelAttemptGate = FoundationModelAttemptGate()
    ) {
        self.fallback = fallback
        self.attemptGate = attemptGate
    }

    func extractCandidates(from request: ActionExtractionRequest) async throws -> [ActionCandidate] {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            guard await attemptGate.begin() else {
                return try await fallback.extractCandidates(from: request).map { candidate in
                    var copy = candidate
                    copy.validationState = .warning("Apple Intelligence is still winding down; using deterministic text extraction.")
                    return copy
                }
            }

            let outcome = await CallerResponseDeadline.run(for: .seconds(10)) {
                do {
                    let session = LanguageModelSession(instructions: Instructions(Self.instructions))
                    let response = try await session.respond(
                        to: Prompt(Self.prompt(for: request)),
                        generating: GeneratedSnapActions.self
                    )
                    let candidates = response.content.actions.map(Self.convert(_:))
                    await attemptGate.finish()
                    return candidates
                } catch {
                    await attemptGate.finish()
                    throw error
                }
            }
            switch outcome {
            case .success(let candidates):
                if !candidates.isEmpty {
                    return candidates
                }
            case .failure:
                return try await fallback.extractCandidates(from: request).map { candidate in
                    var copy = candidate
                    copy.validationState = .warning("Apple Intelligence extraction failed; using deterministic text extraction.")
                    return copy
                }
            case .timedOut:
                return try await fallback.extractCandidates(from: request).map { candidate in
                    var copy = candidate
                    copy.validationState = .warning("Apple Intelligence took too long; using deterministic text extraction.")
                    return copy
                }
            case .cancelled:
                throw CancellationError()
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

enum CallerResponseDeadlineOutcome<Value: Sendable>: Sendable {
    case success(Value)
    case failure(String)
    case timedOut
    case cancelled
}

extension CallerResponseDeadlineOutcome: Equatable where Value: Equatable {}

enum CallerResponseDeadline {
    static func run<Value: Sendable>(
        for duration: Duration,
        operation: @escaping @Sendable () async throws -> Value
    ) async -> CallerResponseDeadlineOutcome<Value> {
        let state = CallerResponseDeadlineState<Value>()

        return await withTaskCancellationHandler {
            if Task.isCancelled {
                await state.resolve(.cancelled)
                return .cancelled
            }

            let operationTask = Task {
                do {
                    await state.resolve(.success(try await operation()))
                } catch is CancellationError {
                    await state.resolve(.cancelled)
                } catch {
                    await state.resolve(.failure(error.localizedDescription))
                }
            }
            let timeoutTask = Task {
                do {
                    try await Task.sleep(for: duration)
                    await state.resolve(.timedOut)
                } catch {
                    // The operation or parent caller completed first.
                }
            }

            await state.install(operationTask: operationTask, timeoutTask: timeoutTask)
            let outcome = await state.result()
            await state.cancelPendingTasks()
            return outcome
        } onCancel: {
            Task {
                await state.cancelAndResolve()
            }
        }
    }
}

actor FoundationModelAttemptGate {
    private var attemptIsActive = false

    func begin() -> Bool {
        guard !attemptIsActive else { return false }
        attemptIsActive = true
        return true
    }

    func finish() {
        attemptIsActive = false
    }
}

private actor CallerResponseDeadlineState<Value: Sendable> {
    private var outcome: CallerResponseDeadlineOutcome<Value>?
    private var continuation: CheckedContinuation<CallerResponseDeadlineOutcome<Value>, Never>?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    func install(operationTask: Task<Void, Never>, timeoutTask: Task<Void, Never>) {
        guard outcome == nil else {
            operationTask.cancel()
            timeoutTask.cancel()
            return
        }
        self.operationTask = operationTask
        self.timeoutTask = timeoutTask
    }

    func resolve(_ newOutcome: CallerResponseDeadlineOutcome<Value>) {
        guard outcome == nil else { return }
        outcome = newOutcome
        continuation?.resume(returning: newOutcome)
        continuation = nil
    }

    func result() async -> CallerResponseDeadlineOutcome<Value> {
        if let outcome {
            return outcome
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func cancelAndResolve() {
        resolve(.cancelled)
        cancelPendingTasks()
    }

    func cancelPendingTasks() {
        operationTask?.cancel()
        timeoutTask?.cancel()
    }
}
