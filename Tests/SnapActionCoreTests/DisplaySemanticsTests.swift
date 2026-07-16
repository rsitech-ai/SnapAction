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

@Test func successfulExecutionResultsUseSuccessTone() {
    #expect(ActionExecutionResult.createdReminder(id: "reminder-1").displayTone == .success)
    #expect(ActionExecutionResult.createdEvent(id: "event-1").displayTone == .success)
    #expect(ActionExecutionResult.copiedToClipboard.displayTone == .success)
}

@Test func failedExecutionResultUsesDangerTone() {
    #expect(ActionExecutionResult.failed(message: "Permission denied").displayTone == .danger)
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
    #expect(ProcessingStage.checkingConfirmation.label == "Checking confirmation")
    #expect(ProcessingStage.executingAction.label == "Executing the action")
}

@Test func processingStageAllowsNewOperationsOnlyWhileIdle() {
    #expect(ProcessingStage.idle.allowsNewOperation)
    #expect(!ProcessingStage.readingCapture.allowsNewOperation)
    #expect(!ProcessingStage.findingActions.allowsNewOperation)
    #expect(!ProcessingStage.checkingConfirmation.allowsNewOperation)
    #expect(!ProcessingStage.executingAction.allowsNewOperation)
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
    #expect(!healthy.showsModelStatusInSidebar)
    #expect(blocked.showsClipboardRestore)
    #expect(blocked.showsCapturePermissionRecovery)
    #expect(blocked.showsModelFallbackNotice)
    #expect(blocked.showsModelStatusInSidebar)
}

@Test func workflowFailuresExposeDistinctTruthfulPresentation() {
    let permission = WorkflowFailurePresentation.capturePermission("Screen Recording is denied.")
    let capture = WorkflowFailurePresentation.capture("The display could not be captured.")
    let image = WorkflowFailurePresentation.imageImport("The selected image is invalid.")
    let extraction = WorkflowFailurePresentation.extraction("The model response was invalid.")

    #expect(permission.kind == .capturePermission)
    #expect(permission.title == "Screen Recording needed")
    #expect(permission.showsCapturePermissionRecovery)
    #expect(permission.retryAction == nil)

    #expect(capture.kind == .capture)
    #expect(capture.title == "Capture failed")
    #expect(!capture.showsCapturePermissionRecovery)
    #expect(capture.retryAction == .capture)

    #expect(image.kind == .imageImport)
    #expect(image.title == "Image couldn’t be read")
    #expect(!image.showsCapturePermissionRecovery)
    #expect(image.retryAction == .imageImport)

    #expect(extraction.kind == .extraction)
    #expect(extraction.title == "Actions couldn’t be created")
    #expect(!extraction.showsCapturePermissionRecovery)
    #expect(extraction.retryAction == nil)
}

@Test func historyEmptyStateDistinguishesNoMatchesFromNoStoredHistory() {
    #expect(HistoryEmptyState.label(hasStoredHistory: false) == "No history")
    #expect(HistoryEmptyState.label(hasStoredHistory: true) == "No matching history")
}

@Test func historyRetentionLabelUsesSingularAndPluralDayUnits() {
    #expect(HistoryRetentionPresentation.label(days: 1) == "Retain history for 1 day")
    #expect(HistoryRetentionPresentation.label(days: 30) == "Retain history for 30 days")
}
