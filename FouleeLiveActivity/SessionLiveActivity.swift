import ActivityKit
import FouleeDesignSystem
import FouleeDomain
import FouleeLiveActivityModel
import SwiftUI
import WidgetKit

/// Live Activity rendered while a session is active. Three surfaces:
/// - Lock Screen / banner: full row with timer + ring + counters
/// - Dynamic Island compact: activity icon left, elapsed right
/// - Dynamic Island expanded: timer + km and climb + steps + kcal
/// - Dynamic Island minimal: activity icon
///
/// The copy, the glyph and the figures follow the outing's sport (#225,
/// #732): a run announces itself as a run, and a sport without a distance
/// draws none. This extension has no app-group entitlement, so the attributes
/// are the only channel that carries it — the title, the glyph and the figures
/// are derived there, once, so the places below cannot disagree.
///
/// Generic over the attributes type: `SessionActivityAttributes` for every new
/// activity, `WalkActivityAttributes` for one left running by a build before
/// #732, drawn the same way.
struct SessionLiveActivity<Attributes: ActivityAttributes & SessionActivityContent>: Widget
where Attributes.ContentState == SessionActivityState {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Attributes.self) { context in
            LockScreenView(
                state: context.state,
                attributes: context.attributes
            )
            .padding(14)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(
                            timerInterval: context.state.timerBasis...Date(timeIntervalSinceNow: 86_400),
                            pauseTime: context.state.pausedAt,
                            countsDown: false,
                            showsHours: true
                        )
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .sessionClockAccessibility(context.state)
                    } icon: {
                        Image(systemName: context.state.isPaused ? "pause.fill" : context.attributes.glyph)
                            .foregroundStyle(.tint)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        if let headline = context.attributes.headlineMetric {
                            Text(context.state.text(for: headline))
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                                .accessibilityLabel(context.state.spokenText(for: headline))
                        }
                        // A ride's average speed under its distance (#750).
                        if context.attributes.showsSpeed, let speed = context.state.averageSpeedText {
                            Text(speed)
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(context.state.spokenAverageSpeedText ?? speed)
                        }
                        // The climb under the headline, when there is one
                        // (issue #576); never in the compact views.
                        if context.attributes.showsElevation,
                           let elevation = context.state.elevation, let text = elevation.text {
                            Text(text)
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(elevation.spokenText ?? text)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        ForEach(context.attributes.cellMetrics) { metric in
                            statCell(
                                value: context.state.valueText(for: metric),
                                label: metric.unit,
                                icon: metric.glyph,
                                spoken: context.state.spokenText(for: metric)
                            )
                        }
                        statCell(
                            value: "\(context.attributes.goalMinutes)",
                            label: String(localized: "min objectif"),
                            icon: "target",
                            spoken: spokenGoalText(minutes: context.attributes.goalMinutes)
                        )
                    }
                }
            } compactLeading: {
                sessionGlyph(context)
            } compactTrailing: {
                Text(
                    timerInterval: context.state.timerBasis...Date(timeIntervalSinceNow: 86_400),
                    pauseTime: context.state.pausedAt,
                    countsDown: false,
                    showsHours: true
                )
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(context.state.isPaused ? .secondary : .primary)
                .frame(maxWidth: 60)
                .sessionClockAccessibility(context.state)
            } minimal: {
                sessionGlyph(context)
            }
        }
    }

    /// The activity's glyph, or pause, named for VoiceOver by the session's
    /// title: « Ta marche », « Ta course · En pause » (issue #601).
    private func sessionGlyph(_ context: ActivityViewContext<Attributes>) -> some View {
        Image(systemName: context.state.isPaused ? "pause.fill" : context.attributes.glyph)
            .foregroundStyle(.tint)
            .accessibilityLabel(context.attributes.title(isPaused: context.state.isPaused))
    }

    /// `spoken` is the whole cell for VoiceOver: « — kcal » would be read
    /// « tiret k cal » and « 30 min objectif » word by word (issue #601).
    private func statCell(value: String, label: String, icon: String, spoken: String) -> some View {
        MetricTile(
            title: label,
            value: value,
            icon: icon,
            tint: .secondary,
            shape: .compact,
            size: .small,
            speech: .spoken(label: spoken, value: nil)
        )
    }
}

struct LockScreenView: View {
    let state: SessionActivityState
    let attributes: any SessionActivityContent

    private var progress: Double {
        let goalSeconds = Double(attributes.goalMinutes * 60)
        guard goalSeconds > 0 else { return 0 }
        return min(state.elapsed / goalSeconds, 1)
    }

    var body: some View {
        HStack(spacing: 14) {
            ring
            VStack(alignment: .leading, spacing: 4) {
                Label(
                    // « Ta marche » / « Ta course », « Ta sortie » for an
                    // outing the app cannot name — spelled in
                    // `SessionActivityContent` so the Dynamic Island above
                    // draws the same figure this row does.
                    attributes.title(isPaused: state.isPaused),
                    systemImage: state.isPaused ? "pause.fill" : attributes.glyph
                )
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(.primary)
                Text(
                    timerInterval: state.timerBasis...Date(timeIntervalSinceNow: 86_400),
                    pauseTime: state.pausedAt,
                    countsDown: false,
                    showsHours: true
                )
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(state.isPaused ? .secondary : .primary)
                .sessionClockAccessibility(state)
                // The sport's first two figures: « 5 391 pas · 2,48 km »
                // for a walk, the calories alone for a sport without either.
                // A ride adds its average speed: « 12,4 km · 24 km/h » (#750).
                Text(attributes.rowTexts(state).joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text(attributes.rowSpokenTexts(state).joined(separator: ", ")))
                // Its own line: beside the steps and the distance it would
                // truncate on a small phone (issue #576).
                if attributes.showsElevation, let elevation = state.elevation, let text = elevation.text {
                    Text(text)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(elevation.spokenText ?? text)
                }
            }
            Spacer(minLength: 0)
        }
        // One element for the whole row, read in the order it is drawn.
        .accessibilityElement(children: .combine)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.tint.opacity(0.15), lineWidth: 7)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .monospacedDigit()
        }
        .frame(width: 62, height: 62)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenGoalText(minutes: attributes.goalMinutes))
        .accessibilityValue(Text("\(Int(progress * 100)) %"))
    }
}

private extension View {
    /// The session clock for VoiceOver (issue #601): « 18:24 » is read as a
    /// time of day. Running, a `.relative` text the system ticks like the
    /// timer itself, « 18 min 24 s »; paused, the frozen duration in words.
    func sessionClockAccessibility(_ state: SessionActivityState) -> some View {
        accessibilityLabel(Text("Durée"))
            .accessibilityValue(
                state.isPaused
                    ? Text(spokenDurationText(seconds: state.elapsed))
                    : Text(state.timerBasis, style: .relative)
            )
    }
}
