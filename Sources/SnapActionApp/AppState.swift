import AppKit
import Foundation
import Observation
import OSLog
import SnapActionCore

@MainActor
@Observable
final class AppState {
    private let logger = Logger(subsystem: "com.s1kor.snapaction", category: "Workflow")

    var currentDocument: OCRDocument?
    var candidates: [ActionCandidate] = []
    var selectedCandidateID: ActionCandidate.ID?
    var history: [HistoryEntry] = []
    var lastClipboardSnapshot: ClipboardSnapshot?
    var statusMessage = "Ready"
    private(set) var processingStage: ProcessingStage = .idle
    var modelStatus = "Checking Apple Intelligence..."
    var screenCaptureStatus = "Checking Screen Recording..."
    private(set) var modelFallbackActive = false
    private var screenCaptureAllowed = false
    var eventKitStatus = "Calendar and Reminders permissions are requested on first write."
    var clipboardStatus = "No saved clipboard yet"
    var historyRetentionDays = 30
    var hotkeyDescription = "Command-Shift-1 capture, Command-Shift-2 demo, Command-Shift-I import"
    var historySearchText = ""

    private let workflow: CaptureWorkflow
    private let historyStore: HistoryStore
    private let clipboardStore: ClipboardSnapshotStore
    private let ocrService: VisionOCRService
    private let screenCaptureService: ScreenCaptureService
    private let hotkeyService: GlobalHotkeyService

    init(
        workflow: CaptureWorkflow,
        historyStore: HistoryStore,
        clipboardStore: ClipboardSnapshotStore,
        ocrService: VisionOCRService = VisionOCRService(),
        screenCaptureService: ScreenCaptureService = ScreenCaptureService(),
        hotkeyService: GlobalHotkeyService = GlobalHotkeyService()
    ) {
        self.workflow = workflow
        self.historyStore = historyStore
        self.clipboardStore = clipboardStore
        self.ocrService = ocrService
        self.screenCaptureService = screenCaptureService
        self.hotkeyService = hotkeyService
        refreshHistory()
        refreshClipboardSnapshot()
        refreshPermissionStatus()
        logger.info("App state initialized historyCount=\(self.history.count, privacy: .public) clipboardReady=\((self.lastClipboardSnapshot != nil), privacy: .public)")
    }

    static func bootstrap() -> AppState {
        let historyURL = ApplicationPaths.historyURL()
        let store = try? HistoryStore(fileURL: historyURL)
        let historyStore = store ?? (try! HistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("snapaction-history.json")))
        let clipboardStore = (try? ClipboardSnapshotStore(fileURL: ApplicationPaths.clipboardURL()))
            ?? (try! ClipboardSnapshotStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("snapaction-clipboard.json")))
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

    var isProcessing: Bool {
        processingStage != .idle
    }

    var workspacePresentation: WorkspacePresentation {
        WorkspacePresentation(
            phase: .resolve(isProcessing: isProcessing, hasDocument: currentDocument != nil),
            hasClipboardSnapshot: lastClipboardSnapshot != nil,
            screenCaptureAllowed: screenCaptureAllowed,
            modelFallbackActive: modelFallbackActive
        )
    }

    var processingLabel: String {
        processingStage.label
    }

    var filteredHistory: [HistoryEntry] {
        let query = historySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return history }
        return history.filter { entry in
            entry.ocrText.localizedCaseInsensitiveContains(query)
                || entry.candidates.contains { $0.title.localizedCaseInsensitiveContains(query) }
                || (entry.result?.displayMessage.localizedCaseInsensitiveContains(query) ?? false)
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
        processingStage = .findingActions
        Task {
            defer { processingStage = .idle }
            await resolveActions(in: .singleBlock(sample))
        }
    }

    func captureScreenSnapshot() {
        logger.info("Screen snapshot capture requested")
        processingStage = .readingCapture
        Task {
            defer { processingStage = .idle }
            do {
                let image = try await screenCaptureService.captureFirstDisplayImage()
                let document = try await ocrService.recognizeText(in: image)
                processingStage = .findingActions
                await resolveActions(in: document)
            } catch {
                logger.error("Screen capture failed: \(error.localizedDescription, privacy: .public)")
                statusMessage = "Screen Recording permission needed. Open Settings to continue."
                refreshPermissionStatus()
            }
        }
    }

    func importImageForOCR() {
        logger.info("Image import requested")
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await recognizeImage(at: url)
            }
        }
    }

    func execute(candidate: ActionCandidate, editedTitle: String, confirmed: Bool) {
        guard let document = currentDocument else { return }
        logger.info("Action execution requested kind=\(candidate.kind.rawValue, privacy: .public) confirmed=\(confirmed, privacy: .public)")
        var candidateToExecute = candidate
        candidateToExecute.title = editedTitle
        let session = CaptureSession(document: document, candidates: candidates)

        processingStage = .executingAction
        Task {
            defer { processingStage = .idle }
            do {
                let result = try await workflow.execute(candidateToExecute, confirmed: confirmed, in: session)
                statusMessage = result.displayMessage
                refreshHistory()
                refreshClipboardSnapshot()
                logger.info("Action execution finished result=\(result.displayMessage, privacy: .public)")
            } catch {
                logger.error("Action execution failed: \(error.localizedDescription, privacy: .public)")
                statusMessage = error.localizedDescription
            }
        }
    }

    func restoreSavedClipboard() {
        guard let snapshot = lastClipboardSnapshot else {
            statusMessage = "No saved clipboard payload yet."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snapshot.text, forType: .string)
        statusMessage = "Clipboard restored: \(snapshot.title)"
        clipboardStatus = "Ready: \(snapshot.title)"
        logger.info("Clipboard restored from durable snapshot source=\(snapshot.source.rawValue, privacy: .public)")
    }

    func refreshPermissionStatus() {
        modelStatus = LocalFoundationModelsExtractor.availabilitySummary()
        screenCaptureStatus = screenCaptureService.permissionSummary()
        modelFallbackActive = !LocalFoundationModelsExtractor.isAvailable
        screenCaptureAllowed = screenCaptureService.hasPermission
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

    private func recognizeImage(at url: URL) async {
        processingStage = .readingCapture
        defer { processingStage = .idle }
        do {
            let document = try await ocrService.recognizeText(in: url)
            processingStage = .findingActions
            await resolveActions(in: document)
        } catch {
            logger.error("OCR failed: \(error.localizedDescription, privacy: .public)")
            statusMessage = "OCR failed: \(error.localizedDescription)"
        }
    }

    private func resolveActions(in document: OCRDocument) async {
        do {
            let session = try await workflow.process(document: document)
            currentDocument = session.document
            candidates = session.candidates
            selectedCandidateID = session.candidates.first?.id
            statusMessage = session.candidates.isEmpty ? "No actions found" : "Review suggested actions before confirming."
            refreshPermissionStatus()
            logger.info("Document processed blocks=\(document.blocks.count, privacy: .public) candidates=\(session.candidates.count, privacy: .public)")
        } catch {
            logger.error("Extraction failed: \(error.localizedDescription, privacy: .public)")
            statusMessage = "Extraction failed: \(error.localizedDescription)"
        }
    }

    private func refreshHistory() {
        history = (try? historyStore.load()) ?? []
    }

    private func refreshClipboardSnapshot() {
        lastClipboardSnapshot = try? clipboardStore.load()
        if let lastClipboardSnapshot {
            clipboardStatus = "Ready: \(lastClipboardSnapshot.title)"
        } else {
            clipboardStatus = "No saved clipboard yet"
        }
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
