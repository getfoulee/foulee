import FouleeKit
import SwiftUI

/// Hero card at the top of `WorkoutDetailSheet` — the session's own figure,
/// date label, big duration, then a one-liner naming the sport, the time range
/// and the source (issue #245).
struct WorkoutDetailHero: View {
    let detail: WorkoutDetail

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: detail.summary.activityIcon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
                .background(FouleeColor.raised, in: .rect(cornerRadius: Radius.row))
            Text(dateLabel)
                .font(FouleeFont.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            // The session clock's own format: hours once past the hour,
            // « 1:06:31 », never « 66:31 ».
            Text(detail.summary.durationSeconds.walkClockText)
                .scaledNumericFont(size: 44)
            Text("\(detail.summary.activityLabel) · \(detail.summary.timeRangeText) · \(detail.summary.sourceName)")
                .font(FouleeFont.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .fouleeCard()
        // One element: the clock alone, « 24:10 », is read as a time of day.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let summary = detail.summary
        return [
            summary.activityLabel,
            dateLabel,
            spokenDurationText(seconds: summary.durationSeconds),
            summary.timeRangeSpokenText,
            summary.sourceName
        ]
        .joined(separator: ", ")
    }

    private var dateLabel: String {
        let calendar = Calendar.current
        let date = detail.summary.startedAt
        if calendar.isDateInToday(date) { return String(localized: "Aujourd'hui") }
        if calendar.isDateInYesterday(date) { return String(localized: "Hier") }
        return date.dayText.sentenceCased
    }
}
