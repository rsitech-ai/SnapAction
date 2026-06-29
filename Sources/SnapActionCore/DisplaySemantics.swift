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
