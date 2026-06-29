import Testing
@testable import SnapActionCore

@Test func displaySemanticsClassifyCandidateConfidenceAndExecutability() {
    let validCandidate = ActionCandidate(
        kind: .reminder,
        title: "Send deck",
        confidence: 0.92,
        sourceText: "Send deck tomorrow",
        fields: [.dueDate: "2027-01-01T09:00:00Z"],
        validationState: .valid
    )
    let warningCandidate = ActionCandidate(
        kind: .textTable,
        title: "Extract text",
        confidence: 0.64,
        sourceText: "Quarter | ARR",
        fields: [.extractedText: "Quarter | ARR"],
        validationState: .warning("Model unavailable")
    )
    let invalidCandidate = ActionCandidate(
        kind: .calendarEvent,
        title: "Sync",
        confidence: 0.2,
        sourceText: "Sync",
        fields: [:],
        validationState: .invalid("Calendar events need a start date.")
    )

    #expect(validCandidate.confidenceBand == .high)
    #expect(validCandidate.isExecutable)
    #expect(validCandidate.validationState.displayTone == .success)
    #expect(warningCandidate.confidenceBand == .medium)
    #expect(warningCandidate.validationState.displayTone == .warning)
    #expect(invalidCandidate.confidenceBand == .low)
    #expect(!invalidCandidate.isExecutable)
    #expect(invalidCandidate.validationState.displayTone == .danger)
}
