import Foundation

public struct ActionValidator: Sendable {
    private let now: Date
    private let minimumWriteConfidence: Double

    public init(now: Date = Date(), minimumWriteConfidence: Double = 0.5) {
        self.now = now
        self.minimumWriteConfidence = minimumWriteConfidence
    }

    public func validated(_ candidate: ActionCandidate) -> ActionCandidate {
        var copy = candidate
        copy.validationState = state(for: candidate)
        return copy
    }

    private func state(for candidate: ActionCandidate) -> ValidationState {
        guard !candidate.title.isEmpty else {
            return .invalid("Action title is required.")
        }
        guard !candidate.sourceText.isEmpty else {
            return .invalid("Source text is required.")
        }

        switch candidate.kind {
        case .reminder:
            guard candidate.confidence >= minimumWriteConfidence else {
                return .invalid("Reminder confidence is too low to write safely.")
            }
            if let dueDate = candidate.fields[.dueDate], !dueDate.isEmpty {
                guard let parsedDueDate = parseDate(dueDate) else {
                    return .invalid("Reminder due date is not a valid ISO-8601 date.")
                }
                if sourceMentionsTomorrow(candidate.sourceText), !isTomorrow(parsedDueDate) {
                    return .invalid("Reminder due date does not match the source text.")
                }
            }
            return .valid
        case .calendarEvent:
            guard candidate.confidence >= minimumWriteConfidence else {
                return .invalid("Calendar event confidence is too low to write safely.")
            }
            guard let startDate = candidate.fields[.startDate], !startDate.isEmpty else {
                return .invalid("Calendar events need a start date.")
            }
            guard let parsedStart = parseDate(startDate) else {
                return .invalid("Calendar start date is not a valid ISO-8601 date.")
            }
            if sourceMentionsTomorrow(candidate.sourceText), !isTomorrow(parsedStart) {
                return .invalid("Calendar start date does not match the source text.")
            }
            if parsedStart < now.addingTimeInterval(-60) {
                return .warning("Calendar event starts in the past.")
            }
            if let endDate = candidate.fields[.endDate], !endDate.isEmpty {
                guard let parsedEnd = parseDate(endDate) else {
                    return .invalid("Calendar end date is not a valid ISO-8601 date.")
                }
                guard parsedEnd > parsedStart else {
                    return .invalid("Calendar end date must be after the start date.")
                }
            }
            return .valid
        case .textTable:
            let extracted = candidate.fields[.extractedText] ?? candidate.fields[.tableMarkdown] ?? candidate.sourceText
            guard !extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .invalid("Extracted text is empty.")
            }
            return .valid
        }
    }

    private func parseDate(_ text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: text) {
            return date
        }
        return ISO8601DateFormatter().date(from: text)
    }

    private func sourceMentionsTomorrow(_ sourceText: String) -> Bool {
        sourceText.range(of: #"\btomorrow\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func isTomorrow(_ date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
            return false
        }
        return calendar.isDate(date, inSameDayAs: tomorrow)
    }
}
