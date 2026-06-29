import AppKit
import EventKit
import Foundation
import SnapActionCore

final class PlatformActionExecutor: ActionExecuting, @unchecked Sendable {
    private let eventStore = EKEventStore()
    private let clipboardStore: ClipboardSnapshotStore?

    init(clipboardStore: ClipboardSnapshotStore? = nil) {
        self.clipboardStore = clipboardStore
    }

    func execute(_ candidate: ActionCandidate, confirmed: Bool) async throws -> ActionExecutionResult {
        guard confirmed else {
            return .failed(message: "Confirmation is required before writing outside SnapAction.")
        }
        guard candidate.validationState == .valid else {
            return .failed(message: "Only valid actions can be executed.")
        }

        switch candidate.kind {
        case .reminder:
            return try await createReminder(from: candidate)
        case .calendarEvent:
            return try await createEvent(from: candidate)
        case .textTable:
            return copyToClipboard(candidate)
        }
    }

    private func createReminder(from candidate: ActionCandidate) async throws -> ActionExecutionResult {
        let granted = try await eventStore.requestFullAccessToReminders()
        guard granted else {
            return .failed(message: "Reminders access was denied.")
        }
        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            return .failed(message: "No default reminders list is available.")
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = candidate.title
        reminder.notes = candidate.fields[.notes] ?? candidate.sourceText
        reminder.calendar = calendar
        if let due = candidate.fields[.dueDate].flatMap(Self.parseDate(_:)) {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        }
        try eventStore.save(reminder, commit: true)
        return .createdReminder(id: reminder.calendarItemIdentifier)
    }

    private func createEvent(from candidate: ActionCandidate) async throws -> ActionExecutionResult {
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else {
            return .failed(message: "Calendar access was denied.")
        }
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            return .failed(message: "No default calendar is available.")
        }
        guard let start = candidate.fields[.startDate].flatMap(Self.parseDate(_:)) else {
            return .failed(message: "Calendar event needs a valid start date.")
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = candidate.title
        event.notes = candidate.fields[.notes] ?? candidate.sourceText
        event.calendar = calendar
        event.startDate = start
        event.endDate = candidate.fields[.endDate].flatMap(Self.parseDate(_:)) ?? start.addingTimeInterval(30 * 60)
        try eventStore.save(event, span: .thisEvent, commit: true)
        return .createdEvent(id: event.eventIdentifier)
    }

    private func copyToClipboard(_ candidate: ActionCandidate) -> ActionExecutionResult {
        let text = candidate.fields[.tableMarkdown] ?? candidate.fields[.extractedText] ?? candidate.sourceText
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        try? clipboardStore?.save(
            ClipboardSnapshot(
                title: candidate.title.isEmpty ? "Copied text" : candidate.title,
                text: text,
                source: candidate.kind
            )
        )
        return .copiedToClipboard
    }

    private static func parseDate(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}
