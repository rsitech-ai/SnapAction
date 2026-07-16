public enum DisplayTone: String, Codable, Equatable, Sendable {
    case neutral
    case success
    case warning
    case danger
}

public enum ConfidenceBand: String, Codable, Equatable, Sendable {
    case low
    case medium
    case high
}

public extension ActionCandidate {
    var confidenceBand: ConfidenceBand {
        switch confidence {
        case 0.8...:
            .high
        case 0.5..<0.8:
            .medium
        default:
            .low
        }
    }

    var isExecutable: Bool {
        validationState == .valid
    }
}

public extension ValidationState {
    var displayTone: DisplayTone {
        switch self {
        case .pending:
            .neutral
        case .valid:
            .success
        case .warning:
            .warning
        case .invalid:
            .danger
        }
    }
}

public extension ActionExecutionResult {
    var displayTone: DisplayTone {
        switch self {
        case .createdReminder, .createdEvent, .copiedToClipboard:
            .success
        case .failed:
            .danger
        }
    }
}

public enum WorkspacePhase: Equatable, Sendable {
    case capture
    case processing
    case review

    public static func resolve(isProcessing: Bool, hasDocument: Bool) -> WorkspacePhase {
        if isProcessing { return .processing }
        if hasDocument { return .review }
        return .capture
    }
}

public enum ProcessingStage: Equatable, Sendable {
    case idle
    case readingCapture
    case findingActions
    case checkingConfirmation
    case executingAction

    public var allowsNewOperation: Bool {
        self == .idle
    }

    public var label: String {
        switch self {
        case .idle:
            "Ready"
        case .readingCapture:
            "Reading the capture"
        case .findingActions:
            "Finding safe actions"
        case .checkingConfirmation:
            "Checking confirmation"
        case .executingAction:
            "Executing the action"
        }
    }
}

public struct WorkspacePresentation: Equatable, Sendable {
    public let phase: WorkspacePhase
    public let hasClipboardSnapshot: Bool
    public let screenCaptureAllowed: Bool
    public let modelFallbackActive: Bool

    public init(
        phase: WorkspacePhase,
        hasClipboardSnapshot: Bool,
        screenCaptureAllowed: Bool,
        modelFallbackActive: Bool
    ) {
        self.phase = phase
        self.hasClipboardSnapshot = hasClipboardSnapshot
        self.screenCaptureAllowed = screenCaptureAllowed
        self.modelFallbackActive = modelFallbackActive
    }

    public var showsClipboardRestore: Bool { hasClipboardSnapshot }
    public var showsCapturePermissionRecovery: Bool { !screenCaptureAllowed }
    public var showsModelFallbackNotice: Bool { modelFallbackActive }
}

public enum HistoryEmptyState: Sendable {
    public static func label(hasStoredHistory: Bool) -> String {
        hasStoredHistory ? "No matching history" : "No history"
    }
}
