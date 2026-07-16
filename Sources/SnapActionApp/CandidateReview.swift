import Foundation
import SnapActionCore

enum CandidateReview {
    static func validated(_ candidate: ActionCandidate, editedTitle: String) -> ActionCandidate {
        var reviewed = candidate
        reviewed.title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return ActionValidator().validated(reviewed)
    }

    static func validationMessage(for candidate: ActionCandidate) -> String {
        switch candidate.validationState {
        case .pending:
            "Not validated yet"
        case .valid:
            "Valid. Review fields before confirming."
        case .warning(let message), .invalid(let message):
            message
        }
    }
}
