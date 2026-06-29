import Foundation

public protocol ActionExecuting: Sendable {
    func execute(_ candidate: ActionCandidate, confirmed: Bool) async throws -> ActionExecutionResult
}

public final class FakeActionExecutor: ActionExecuting, @unchecked Sendable {
    public private(set) var executed: [ActionCandidate] = []

    public init() {}

    public func execute(_ candidate: ActionCandidate, confirmed: Bool) async throws -> ActionExecutionResult {
        guard confirmed else {
            return .failed(message: "Confirmation is required before writing outside SnapAction.")
        }
        guard candidate.validationState == .valid else {
            return .failed(message: "Only valid actions can be executed.")
        }

        executed.append(candidate)
        switch candidate.kind {
        case .reminder:
            return .createdReminder(id: "fake-reminder-\(executed.count)")
        case .calendarEvent:
            return .createdEvent(id: "fake-event-\(executed.count)")
        case .textTable:
            return .copiedToClipboard
        }
    }
}
