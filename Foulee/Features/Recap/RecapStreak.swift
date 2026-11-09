import FouleeKit
import SwiftUI

/// The streak at the head of the Bilan (issue #445): the flame, the days in a
/// row, and how far the record is.
struct RecapStreakHeader: View {
    let streak: StreakSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // The flame above the text at the accessibility sizes: beside it,
            // « Série actuelle » broke mid-word (issue #658).
            AdaptiveStack(stacked: VStackLayout(alignment: .leading, spacing: 14), regular: HStackLayout(spacing: 14)) {
                Image(systemName: FouleeIcon.flame)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(FouleeColor.warning)
                    .frame(width: 56, height: 56)
                    .background(FouleeColor.raised, in: .rect(cornerRadius: Radius.row))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Série actuelle")
                        .font(FouleeFont.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(streak.current)")
                            .scaledNumericFont(size: 36)
                        Text(streak.current == 1 ? "jour" : "jours")
                            .font(FouleeFont.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(recordTitle)
                        .font(FouleeFont.headline)
                    Spacer()
                    if streak.best > 0 {
                        Text("\(streak.current) / \(streak.best)")
                            .scaledNumericFont(size: 15)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Record : \(streak.best) jours"))
                    }
                }
                RecordBar(progress: streak.recordProgress)
                    .frame(height: 8)
            }
        }
        .padding(20)
        .fouleeCard()
    }

    private var recordTitle: LocalizedStringResource {
        if streak.best == 0 { return "Lance ta première série 🔥" }
        guard let remaining = streak.daysToRecord else { return "🔥 Nouveau record !" }
        return "Plus que \(remaining) jours pour ton record"
    }
}

/// The year at the foot of the Bilan (issue #445): its totals, and the
/// weekdays kept best. The same whatever the period on screen.
struct RecapYear: View {
    let streak: StreakSummary

    var body: some View {
        CardSection("Sur 12 mois") {
            FigureRow {
                total(value: "\(streak.walks)", label: streak.walks == 1 ? "objectif tenu" : "objectifs tenus")
                total(value: durationText(minutes: streak.minutes), label: "d'activité")
                total(value: "\(streak.rate) %", label: "réussite")
            }
        }
        CardSection("Tes jours les plus réguliers") {
            StreakWeekdayBreakdown(stats: streak.weekdays)
        }
    }

    private func total(value: String, label: LocalizedStringResource) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .scaledNumericFont(size: 20)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(FouleeFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

/// Track and fill toward the record.
private struct RecordBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(FouleeColor.raised)
                Capsule()
                    .fill(FouleeColor.warning)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .accessibilityHidden(true)
    }
}
