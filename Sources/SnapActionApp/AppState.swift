import AppKit
import Foundation
import Observation
import OSLog
import SnapActionCore

@MainActor
@Observable
final class AppState {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "org.example.snapaction.community",
        category: "Workflow"
    )

    var currentDocument: OCRDocument? {
        didSet {
            if currentDocument != oldValue {
                lastExecutionFeedback = nil
            }
        }
    }
    var candidates: [ActionCandidate] = [] {
        didSet {
            if candidates != oldValue {
                lastExecutionFeedback = nil
            }
        }
    }
    var selectedCandidateID: ActionCandidate.ID? {
        didSet {
            if selectedCandidateID != oldValue {
                lastExecutionFeedback = nil
            }
        }
    }
    var history: [HistoryEntry] = []
    var lastClipboardSnapshot: ClipboardSnapshot?
    private(set) var lastExecutionFeedback: CandidateExecutionFeedback?
    private(set) var workflowFailure: WorkflowFailurePresentation?
    private(set) var settingsErrorMessage: String?
    private(set) var processingStage: ProcessingStage = .idle
    var modelStatus = "Checking Apple Intelligence..."
    var screenCaptureStatus = "Checking Screen Recording..."
    private(set) var modelFallbackActive = false
    private(set) var activeExtractionProvenance: ExtractionProvenance?
    private var screenCaptureAllowed = false
    var eventKitStatus = "Calendar and Reminders permissions are requested on first write."
    var clipboardStatus = "No saved clipboard yet"
    private(set) var historyRetentionDays = 30
    var historySearchText = ""

    private let workflow: CaptureWorkflow
    private let historyStore: HistoryStore
    private let clipboardStore: ClipboardSnapshotStore
    private let ocrService: VisionOCRService
    private let screenCaptureService: ScreenCaptureService
    private let hotkeyService: GlobalHotkeyService
    private let modelAvailabilitySummary: @Sendable () -> String
    private let modelIsAvailable: @Sendable () -> Bool
    private let historyRetentionUpdater: @Sendable (Int) throws -> Void
    private let clipboardWriter: @MainActor @Sendable (String) -> Bool

    init(
        workflow: CaptureWorkflow,
        historyStore: HistoryStore,
        clipboardStore: ClipboardSnapshotStore,
        ocrService: VisionOCRService = VisionOCRService(),
        screenCaptureService: ScreenCaptureService = ScreenCaptureService(),
        hotkeyService: GlobalHotkeyService = GlobalHotkeyService(),
        modelAvailabilitySummary: @escaping @Sendable () -> String = LocalFoundationModelsExtractor.availabilitySummary,
        modelIsAvailable: @escaping @Sendable () -> Bool = { LocalFoundationModelsExtractor.isAvailable },
        historyRetentionUpdater: (@Sendable (Int) throws -> Void)? = nil,
        clipboardWriter: @escaping @MainActor @Sendable (String) -> Bool = AppState.writeToPasteboard
    ) {
        self.workflow = workflow
        self.historyStore = historyStore
        self.clipboardStore = clipboardStore
        self.ocrService = ocrService
        self.screenCaptureService = screenCaptureService
        self.hotkeyService = hotkeyService
        self.modelAvailabilitySummary = modelAvailabilitySummary
        self.modelIsAvailable = modelIsAvailable
        self.historyRetentionUpdater = historyRetentionUpdater ?? { days in
            try historyStore.setRetentionDays(days)
        }
        self.clipboardWriter = clipboardWriter
        self.historyRetentionDays = historyStore.retentionDays
        refreshHistory()
        refreshClipboardSnapshot()
        refreshPermissionStatus()
        logger.info("App state initialized historyCount=\(self.history.count, privacy: .public) clipboardReady=\((self.lastClipboardSnapshot != nil), privacy: .public)")
    }

    static func bootstrap() throws -> AppState {
        let historyStore = try HistoryStore(fileURL: ApplicationPaths.historyURL())
        let clipboardStore = try ClipboardSnapshotStore(fileURL: ApplicationPaths.clipboardURL())
        let extractor = LocalFoundationModelsExtractor(fallback: RuleBasedFallbackExtractor())
        let executor = PlatformActionExecutor(clipboardStore: clipboardStore)
        let workflow = CaptureWorkflow(
            extractor: extractor,
            validator: ActionValidator(),
            executor: executor,
            historyStore: historyStore
        )
        return AppState(workflow: workflow, historyStore: historyStore, clipboardStore: clipboardStore)
    }

    var selectedCandidate: ActionCandidate? {
        guard let selectedCandidateID else { return candidates.first }
        return candidates.first { $0.id == selectedCandidateID } ?? candidates.first
    }

    var lastExecutionResult: ActionExecutionResult? {
        guard let candidateID = selectedCandidate?.id else { return nil }
        return executionResult(for: candidateID)
    }

    func executionResult(for candidateID: ActionCandidate.ID) -> ActionExecutionResult? {
        guard lastExecutionFeedback?.candidateID == candidateID else { return nil }
        return lastExecutionFeedback?.result
    }

    var isProcessing: Bool {
        processingStage != .idle
    }

    var allowsNewOperation: Bool {
        processingStage.allowsNewOperation
    }

    var workspacePresentation: WorkspacePresentation {
        WorkspacePresentation(
            phase: .resolve(isProcessing: isProcessing, hasDocument: currentDocument != nil),
            hasClipboardSnapshot: lastClipboardSnapshot != nil,
            screenCaptureAllowed: screenCaptureAllowed,
            modelFallbackActive: modelFallbackActive
        )
    }

    var modelFallbackNotice: String {
        if let status = activeExtractionProvenance?.fallbackStatusText {
            return status
        }
        return "Deterministic fallback active — \(modelStatus)."
    }

    var processingLabel: String {
        processingStage.label
    }

    var filteredHistory: [HistoryEntry] {
        let query = historySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return history }
        return history.filter { entry in
            entry.title.localizedCaseInsensitiveContains(query)
                || entry.kind.displayName.localizedCaseInsensitiveContains(query)
                || entry.outcome.displayMessage.localizedCaseInsensitiveContains(query)
        }
    }

    func startHotkeyMonitor() {
        hotkeyService.start { [weak self] in
            Task { @MainActor in
                self?.captureDemo()
            }
        }
    }

    func captureDemo() {
        guard processingStage.allowsNewOperation else { return }
        beginExtraction()
        processingStage = .findingActions
        logger.info("Capture demo requested")
        let calendar = Calendar.current
        let now = Date()
        let reminderDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let eventStart = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        let eventEnd = calendar.date(byAdding: .minute, value: 30, to: eventStart) ?? eventStart
        let formatter = ISO8601DateFormatter()
        let sample = """
        Reminder: File expenses \(formatter.string(from: reminderDate))
        Calendar: Planning sync \(formatter.string(from: eventStart)) to \(formatter.string(from: eventEnd))
        Name | Score
        Ada | 10
        """
        Task {
            defer { processingStage = .idle }
            await resolveActions(in: .singleBlock(sample))
        }
    }

    func captureScreenSnapshot() {
        guard processingStage.allowsNewOperation else { return }
        beginExtraction()
        processingStage = .readingCapture
        logger.info("Screen snapshot capture requested")
        Task {
            defer { processingStage = .idle }
            do {
                let image = try await screenCaptureService.captureFirstDisplayImage()
                let document = try await ocrService.recognizeText(in: image)
                processingStage = .findingActions
                await resolveActions(in: document)
            } catch {
                refreshPermissionStatus()
                if screenCaptureAllowed {
                    logger.error("Screen capture workflow failed")
                    workflowFailure = .capture(
                        "SnapAction couldn’t capture and read the display. Try again."
                    )
                } else {
                    logger.error("Screen capture blocked by Screen Recording access")
                    workflowFailure = .capturePermission(
                        "Allow Screen Recording access to capture the display."
                    )
                }
            }
        }
    }

    func importImageForOCR() {
        guard processingStage.allowsNewOperation else { return }
        logger.info("Image import requested")
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            guard processingStage.allowsNewOperation else { return }
            beginExtraction()
            processingStage = .readingCapture
            Task {
                defer { processingStage = .idle }
                do {
                    let document = try await ocrService.recognizeText(in: url)
                    processingStage = .findingActions
                    await resolveActions(in: document)
                } catch {
                    logger.error("Imported image OCR failed")
                    workflowFailure = .imageImport(
                        "SnapAction couldn’t recognize text in the selected image. Choose another image and try again."
                    )
                }
            }
        }
    }

    func execute(candidate: ActionCandidate, editedTitle: String, confirmed: Bool) {
        guard processingStage.allowsNewOperation, let document = currentDocument else { return }
        lastExecutionFeedback = nil
        logger.info("Action execution requested kind=\(candidate.kind.rawValue, privacy: .public) confirmed=\(confirmed, privacy: .public)")
        let candidateToExecute = CandidateReview.validated(candidate, editedTitle: editedTitle)
        guard candidateToExecute.isExecutable else {
            let result = ActionExecutionResult.failed(
                message: CandidateReview.validationMessage(for: candidateToExecute)
            )
            storeExecutionFeedback(result, for: candidate.id, document: document)
            logger.warning("Action execution blocked by edited candidate validation")
            return
        }
        if let candidateIndex = candidates.firstIndex(where: { $0.id == candidate.id }) {
            candidates[candidateIndex] = candidateToExecute
        }
        let session = CaptureSession(document: document, candidates: candidates)

        processingStage = confirmed ? .executingAction : .checkingConfirmation
        Task {
            defer { processingStage = .idle }
            do {
                let result = try await workflow.execute(candidateToExecute, confirmed: confirmed, in: session)
                storeExecutionFeedback(result, for: candidate.id, document: document)
                refreshHistory()
                refreshClipboardSnapshot()
                if case .failed = result {
                    logger.error("Action execution finished with a recoverable failure")
                } else {
                    logger.info("Action execution finished kind=\(candidate.kind.rawValue, privacy: .public)")
                }
            } catch {
                let nsError = error as NSError
                logger.error("Action execution threw domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
                let result = ActionExecutionResult.failed(message: error.localizedDescription)
                storeExecutionFeedback(result, for: candidate.id, document: document)
            }
        }
    }

    func restoreSavedClipboard() {
        guard let snapshot = lastClipboardSnapshot else {
            clipboardStatus = "No saved clipboard yet"
            return
        }
        guard clipboardWriter(snapshot.text) else {
            clipboardStatus = "Could not restore the saved clipboard"
            logger.error("Clipboard restore failed")
            return
        }
        clipboardStatus = "Ready: \(snapshot.title)"
        logger.info("Clipboard restored from durable snapshot source=\(snapshot.source.rawValue, privacy: .public)")
    }

    func refreshPermissionStatus() {
        if let fallbackStatus = activeExtractionProvenance?.fallbackStatusText {
            modelStatus = fallbackStatus
            modelFallbackActive = true
        } else {
            modelStatus = modelAvailabilitySummary()
            modelFallbackActive = !modelIsAvailable()
        }
        screenCaptureStatus = screenCaptureService.permissionSummary()
        screenCaptureAllowed = screenCaptureService.hasPermission
        if screenCaptureAllowed, workflowFailure?.kind == .capturePermission {
            workflowFailure = nil
        }
    }

    func requestScreenRecordingPermission() {
        screenCaptureService.requestPermission()
        refreshPermissionStatus()
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func updateHistoryRetentionDays(_ days: Int) {
        settingsErrorMessage = nil
        do {
            try historyRetentionUpdater(days)
            historyRetentionDays = historyStore.retentionDays
            refreshHistory()
        } catch {
            historyRetentionDays = historyStore.retentionDays
            settingsErrorMessage = "Could not update history retention: \(error.localizedDescription)"
            logger.error("History retention update failed")
        }
    }

    func clearHistory() {
        settingsErrorMessage = nil
        do {
            try historyStore.deleteAll()
            history = []
            logger.info("History summaries cleared")
        } catch {
            settingsErrorMessage = "Could not clear history. Check local storage access and try again."
            logger.error("History clear failed")
        }
    }

    func clearSavedClipboard() {
        settingsErrorMessage = nil
        do {
            try clipboardStore.clear()
            lastClipboardSnapshot = nil
            clipboardStatus = "No saved clipboard yet"
            logger.info("Saved clipboard cleared")
        } catch {
            settingsErrorMessage = "Could not clear the saved clipboard. Check local storage access and try again."
            logger.error("Saved clipboard clear failed")
        }
    }

    func dismissSettingsError() {
        settingsErrorMessage = nil
    }

    func dismissWorkflowFailure() {
        workflowFailure = nil
    }

    func retryWorkflowFailure() {
        guard let retryAction = workflowFailure?.retryAction else { return }
        switch retryAction {
        case .capture:
            captureScreenSnapshot()
        case .imageImport:
            importImageForOCR()
        }
    }

    private func resolveActions(in document: OCRDocument) async {
        do {
            let session = try await workflow.process(document: document)
            lastExecutionFeedback = nil
            currentDocument = session.document
            candidates = session.candidates
            workflowFailure = nil
            activeExtractionProvenance = session.extractionProvenance
            selectedCandidateID = session.candidates.first?.id
            refreshPermissionStatus()
            logger.info("Document processed blocks=\(document.blocks.count, privacy: .public) candidates=\(session.candidates.count, privacy: .public)")
        } catch {
            logger.error("Action extraction failed")
            workflowFailure = .extraction(
                "SnapAction couldn’t create safe actions from the recognized text. Try another capture or image."
            )
        }
    }

    private func beginExtraction() {
        workflowFailure = nil
        refreshPermissionStatus()
    }

    private func refreshHistory() {
        do {
            history = try historyStore.load()
        } catch {
            history = []
            settingsErrorMessage = "Could not read history. Check local storage access and try again."
            logger.error("History refresh failed")
        }
    }

    private func refreshClipboardSnapshot() {
        do {
            lastClipboardSnapshot = try clipboardStore.load()
            if let lastClipboardSnapshot {
                clipboardStatus = "Ready: \(lastClipboardSnapshot.title)"
            } else {
                clipboardStatus = "No saved clipboard yet"
            }
        } catch {
            lastClipboardSnapshot = nil
            clipboardStatus = "No saved clipboard yet"
            settingsErrorMessage = "Could not read the saved clipboard. Check local storage access and try again."
            logger.error("Saved clipboard refresh failed")
        }
    }

    private func storeExecutionFeedback(
        _ result: ActionExecutionResult,
        for candidateID: ActionCandidate.ID,
        document: OCRDocument
    ) {
        guard currentDocument == document, selectedCandidate?.id == candidateID else { return }
        lastExecutionFeedback = CandidateExecutionFeedback(candidateID: candidateID, result: result)
    }

    private static func writeToPasteboard(_ text: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }
}

struct CandidateExecutionFeedback: Equatable, Sendable {
    let candidateID: ActionCandidate.ID
    let result: ActionExecutionResult

    var accessibilityAnnouncement: String {
        result.displayMessage
    }
}

enum ApplicationPaths {
    static func historyURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("SnapAction", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    static func clipboardURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("SnapAction", isDirectory: true)
            .appendingPathComponent("clipboard.json")
    }
}
