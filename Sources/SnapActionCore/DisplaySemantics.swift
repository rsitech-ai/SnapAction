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
