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

@Test func workspacePhasePrioritizesProcessingThenReviewThenCapture() {
    #expect(WorkspacePhase.resolve(isProcessing: true, hasDocument: true) == .processing)
    #expect(WorkspacePhase.resolve(isProcessing: false, hasDocument: true) == .review)
    #expect(WorkspacePhase.resolve(isProcessing: false, hasDocument: false) == .capture)
}

@Test func processingStageExposesTruthfulLabels() {
    #expect(ProcessingStage.idle.label == "Ready")
    #expect(ProcessingStage.readingCapture.label == "Reading the capture")
    #expect(ProcessingStage.findingActions.label == "Finding safe actions")
    #expect(ProcessingStage.executingAction.label == "Executing the action")
}

@Test func workspacePresentationShowsOnlyContextualRecovery() {
    let healthy = WorkspacePresentation(
        phase: .capture,
        hasClipboardSnapshot: false,
        screenCaptureAllowed: true,
        modelFallbackActive: false
    )
    let blocked = WorkspacePresentation(
        phase: .capture,
        hasClipboardSnapshot: true,
        screenCaptureAllowed: false,
        modelFallbackActive: true
    )

    #expect(!healthy.showsClipboardRestore)
    #expect(!healthy.showsCapturePermissionRecovery)
    #expect(!healthy.showsModelFallbackNotice)
    #expect(blocked.showsClipboardRestore)
    #expect(blocked.showsCapturePermissionRecovery)
    #expect(blocked.showsModelFallbackNotice)
}
