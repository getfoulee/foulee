import Dependencies
import FouleeDesignSystem
import FouleeDomain
import SwiftUI

/// Live walk screen — chip "EN COURS" + big timer + progress ring with
/// pas/distance/kcal + control row. Renders three distinct presentations
/// depending on `store.state`.
struct ActiveSessionScreen: View {
    let minutesGoal: Int
    /// What Santé will record this session as (issue #223): the sport the
    /// user started (#743).
    ///
    /// Resolved by `TodayStore`, not here: a `View` body is out of reach of the
    /// test process, and this is the value the stamp is made of.
    let activity: SessionActivity
    var onDismiss: (SessionRecord) -> Void
    /// Backed out of the picker without starting anything. Distinct from
    /// `onDismiss`, which carries a finished session for the home to overlay —
    /// there is no session here, and registering an empty one would move the

    @State private var store: ActiveSessionStore
    @State private var showRoute = false
    /// Measured, never guessed from the device (#662): the phone's layout
    /// until the first measure says otherwise.
    @State private var layout = LiveSessionLayout(size: LiveSessionLayout.referenceSize)
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The store is a defaulted parameter for the same reason `WatchIdleScreen`
    /// takes its `onStart` from above: built inside the body it is invisible to
    /// a test, and the `.onAppear` start it hides is where the phone turns a
    /// tap into a permanent Santé stamp (issue #224). Handed in, a test drives
    /// the screen that ships and reads what it actually started.
    init(
        minutesGoal: Int,
        activity: SessionActivity,
        store: ActiveSessionStore = ActiveSessionStore(),
        onDismiss: @escaping (SessionRecord) -> Void
    ) {
        self.minutesGoal = minutesGoal
        self.activity = activity
        self.onDismiss = onDismiss
        _store = State(wrappedValue: store)
    }

    var body: some View {
        ZStack {
            SheetBackground()
            content
        }
        .onAppear { startSession() }
        .onDisappear { store.reset() }
        .sheet(isPresented: $showRoute) {
            SessionRouteMapView(route: store.route) { showRoute = false }
        }
        // Haptics: a tap when the walk starts or resumes, a success buzz when
        // it's finished. The closure form fires only on the rising edge.
        .sensoryFeedback(trigger: isActiveState) { _, now in now ? .impact(weight: .medium) : nil }
        .sensoryFeedback(trigger: isFinishedState) { _, now in now ? .success : nil }
    }

    /// Starts the session as soon as the screen appears.
    ///
    /// A named method rather than the body of `.onAppear`, and internal rather
    /// than private, because `.onAppear` never fires in a test process: inlined
    /// there, the sport could be dropped — every session silently stamped a
    /// walk again, which is exactly issue #223 — with the whole suite green.
    func startSession() {
        store.start(minutesGoal: minutesGoal, activity: activity)
    }

    private var isActiveState: Bool {
        if case .active = store.state { return true }
        return false
    }

    private var isFinishedState: Bool {
        if case .finished = store.state { return true }
        return false
    }

    /// What the session in flight is called — « Ta marche » / « Ta course »,
    /// through the same `SessionActivity.sessionTitle` the Live Activity's
    /// Lock Screen row reads (#225).
    ///
    /// The two are under the user's eyes at the same moment, so they say the
    /// same thing rather than « Ta sortie » here and « Ta course » there; a
    /// literal in each would let them drift, which is what happened when #225
    /// moved only the Lock Screen. Read off the session in flight rather than
    /// off what this screen was handed, for the reason
    /// `ActiveSessionStore.liveActivityAttributes` is: the session is what Santé
    /// gets stamped with. « Ta sortie » stays for the states where there is no
    /// session to name.
    private var sessionTitle: String {
        switch store.state {
        case .active(let session), .paused(let session), .finished(let session):
            session.activity.sessionTitle
        case .idle:
            String(localized: "Ta sortie")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle:
            // The brief spinner while `onAppear` starts the session, with the
            // sport chosen on the home (#743).
            ProgressView()
        case .active(let session):
            walkBody(session: session, paused: false)
        case .paused(let session):
            walkBody(session: session, paused: true)
        case .finished(let session):
            finishedBody(session: session)
        }
    }

    private func walkBody(session: SessionRecord, paused: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: LiveSessionLayout.spacing) {
                // Scrolls above the controls once the text is too large for the
                // screen (#597): it used to push the title under the status bar
                // and the controls' labels off the bottom.
                ScrollView {
                    VStack(spacing: 0) {
                        header(paused: paused)
                        ForEach(store.degradedStates, id: \.self) { state in
                            DegradedBanner(state: state)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                        }
                        timer(session: session)
                        ring(session: session)
                        heartRatePlaceholder
                    }
                    .screenColumn(gutter: 0)
                }
                .scrollBounceBehavior(.basedOnSize)
                // Wider than tall, the route sits beside the figures rather
                // than behind the « Carte » button (#662).
                if layout.isSideBySide, tracksRoute(session) {
                    SessionRouteMap(strokes: SessionRouteMap.strokes(route: store.route))
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .padding(.trailing, 20)
                }
            }
            controls(paused: paused)
        }
        // The whole space the walk is given, inside the safe area: on the
        // inner screen the hinge and the camera take their margins from it.
        .onGeometryChange(for: LiveSessionLayout.self) { LiveSessionLayout(size: $0.size) } action: { layout = $0 }
        .padding(.top, 60)
        .padding(.bottom, 56)
    }

    private func header(paused: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Chip(
                label: paused ? "EN PAUSE" : "EN COURS",
                systemIcon: paused ? FouleeIcon.pause : nil,
                tint: paused ? ReadablePalette.orangeText : ReadablePalette.greenText,
                fill: (paused ? FouleeColor.warning : FouleeColor.success).opacity(0.16)
            )
            // Names the session's activity (#225) — see `sessionTitle`. No
            // longer tied to a time of day (#222), and the chip above already
            // says whether it is running or paused.
            Text(sessionTitle)
                .font(FouleeFont.largeTitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private func timer(session: SessionRecord) -> some View {
        VStack(spacing: 6) {
            Text(session.elapsed.walkClockText)
                .kerning(-2)
                .scaledNumericFont(size: 86, weight: .ultraLight)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("DURÉE")
                .font(FouleeFont.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1.2)
        }
        // « 12:34 » alone is read as a time of day.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Durée")
        .accessibilityValue(spokenDurationText(seconds: session.elapsed))
        .padding(.top, 30)
    }

    private func ring(session: SessionRecord) -> some View {
        let goalSeconds = TimeInterval(minutesGoal * 60)
        let progress = goalSeconds > 0 ? session.elapsed / goalSeconds : 0
        // The three figures leave the ring at the accessibility sizes: the
        // ring is 232 pt on a phone, and in it they were cut to « Dis… ».
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize
        return VStack(spacing: 16) {
            ProgressRing(progress: progress, lineWidth: 16) {
                VStack(spacing: 4) {
                    // A hike or a trail is told by its climb (#744), an
                    // indoor session by its calories (#745), the others by
                    // their steps.
                    Text(leadText(session))
                        .scaledNumericFont(size: 56 * layout.scale)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(leadLabel(session))
                        .font(FouleeFont.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if !isAccessibilitySize, measuresDistance(session) {
                        ringFigures(session: session)
                            .padding(.top, 8)
                    }
                }
            }
            // Grown with the room on the inner screen (#662).
            .frame(width: 232 * layout.scale, height: 232 * layout.scale)
            if isAccessibilitySize, measuresDistance(session) {
                ringFigures(session: session)
            }
        }
        .padding(.top, 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sortie en cours")
        .accessibilityValue(figuresAccessibilityValue(session))
    }

    private func figuresAccessibilityValue(_ session: SessionRecord) -> Text {
        guard measuresDistance(session) else { return Text("\(session.estimatedCalories) kilocalories") }
        let (steps, distance) = (session.steps.groupedText(), session.distanceKm.kmText(fractionDigits: 1))
        let kcal = session.estimatedCalories
        // A treadmill has no climb to tell (#746). Two whole sentences rather
        // than one spliced: each translates as a sentence.
        guard session.activity.sport.descriptor.showsElevation else {
            return Text("\(steps) pas, \(distance), \(kcal) kilocalories")
        }
        let (up, down) = (Int(session.elevationGainMeters), Int(session.elevationLossMeters))
        return Text("\(steps) pas, \(distance), \(kcal) kilocalories, \(up) mètres de montée, \(down) mètres de descente")
    }

    private func ringFigures(session: SessionRecord) -> some View {
        FigureRow(spacing: 12, ruleHeight: 28) {
            metric(value: session.distanceKm.kmText(fractionDigits: 1), label: "Distance")
            metric(value: "\(session.estimatedCalories) kcal", label: "Énergie")
            if session.activity.sport.descriptor.liveLead == .climb {
                metric(value: session.steps.groupedText(), label: "Pas")
            } else if session.activity.sport.descriptor.showsElevation {
                metric(value: climbText(session), label: "D+ / D−")
            }
        }
    }

    private func leadText(_ session: SessionRecord) -> String {
        switch session.activity.sport.descriptor.liveLead {
        case .steps: session.steps.groupedText()
        case .climb: climbText(session)
        case .calories: "\(session.estimatedCalories)"
        }
    }

    private func leadLabel(_ session: SessionRecord) -> LocalizedStringResource {
        switch session.activity.sport.descriptor.liveLead {
        case .steps: "PAS"
        case .climb: "D+ / D−"
        case .calories: "KCAL"
        }
    }

    /// An indoor session has no map (#745).
    private func tracksRoute(_ session: SessionRecord) -> Bool {
        session.activity.sport.descriptor.tracksRoute
    }

    /// Strength, yoga or a rower have no distance either; a treadmill has
    /// one (#746).
    private func measuresDistance(_ session: SessionRecord) -> Bool {
        session.activity.sport.descriptor.measuresDistance
    }

    private func climbText(_ session: SessionRecord) -> String {
        "\(Int(session.elevationGainMeters)) / \(Int(session.elevationLossMeters)) m"
    }

    /// The ring reads as one VoiceOver element (above), so its figures
    /// speak through it.
    private func metric(value: String, label: LocalizedStringResource) -> some View {
        MetricTile(
            title: String(localized: label),
            value: value,
            icon: nil,
            tint: .secondary,
            shape: .compact,
            size: .small
        )
    }

    private var heartRatePlaceholder: some View {
        HStack(spacing: 10) {
            Image(systemName: FouleeIcon.heart)
                .scaledSystemFont(size: 20)
                .foregroundStyle(FouleeColor.danger)
            Text("Connecte ta Watch pour le rythme cardiaque")
                .font(FouleeFont.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(16)
        .fouleeGlass(cornerRadius: 22)
        .padding(.horizontal, 20)
        .padding(.top, 32)
    }
}

/// The control row. In an extension so the screen's own type body stays
/// inside the length budget.
private extension ActiveSessionScreen {
    func controls(paused: Bool) -> some View {
        HStack(spacing: 28) {
            controlButton(icon: FouleeIcon.stop, color: FouleeColor.danger, label: "Arrêter") {
                Task { await store.stop() }
            }
            if paused {
                controlButton(icon: FouleeIcon.play, color: FouleeColor.accentMid, label: "Reprendre", big: true) {
                    store.resume()
                }
            } else {
                controlButton(icon: FouleeIcon.pause, color: FouleeColor.accentMid, label: "Pause", big: true) {
                    Task { await store.pause() }
                }
            }
            // The map is already on screen beside the figures; an indoor
            // session has none (#745).
            if !layout.isSideBySide, activity.sport.descriptor.tracksRoute {
                controlButton(icon: FouleeIcon.location, color: Color(hex: 0x0A84FF), label: "Carte") {
                    showRoute = true
                }
            }
        }
        .padding(.bottom, 40)
    }

    func controlButton(
        icon: String,
        color: Color,
        label: LocalizedStringResource,
        big: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: big ? 32 : 24, weight: .semibold))
                    .foregroundStyle(big ? AnyShapeStyle(Color.white) : AnyShapeStyle(color))
                    .frame(width: big ? 80 : 62, height: big ? 80 : 62)
                    .background(
                        big
                            ? AnyShapeStyle(FouleeColor.accentGradient)
                            : AnyShapeStyle(.ultraThinMaterial),
                        in: Circle()
                    )
                    .shadow(
                        color: big ? FouleeColor.accentMid.opacity(0.4) : .black.opacity(0.15),
                        radius: big ? 18 : 8, x: 0, y: 6
                    )
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(label)
            // Capped like a tab bar's labels, with the system's large content
            // viewer past it: « Pause » broke in two, and the labels pushed
            // the ring off screen.
            .accessibilityShowsLargeContentViewer {
                Label { Text(label) } icon: { Image(systemName: icon) }
            }
            Text(label)
                .font(FouleeFont.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .cappedTextSize()
                .accessibilityHidden(true)
        }
    }
}

/// The end-of-session presentation. In an extension so the screen's own
/// type body stays inside the length budget — and it reads as one piece:
/// nothing here decides anything, it draws a session that is already over.
private extension ActiveSessionScreen {
    func finishedBody(session: SessionRecord) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                CelebrationBurst()
                Image(systemName: FouleeIcon.check)
                    .font(.system(size: 84, weight: .bold))
                    .foregroundStyle(FouleeColor.accentGradient)
                    .symbolEffect(.bounce, value: isFinishedState)
            }
            .accessibilityHidden(true)
            Text("Sortie terminée")
                .font(FouleeFont.title2)
            VStack(spacing: 4) {
                Text(session.elapsed.walkClockText)
                    .scaledNumericFont(size: 48)
                Text(finishedSummary(session: session))
                    .font(FouleeFont.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(finishedSummary(session: session, spoken: true))
            if let highlight = store.highlight {
                highlightCard(highlight)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            if let lastError = store.lastError {
                Text(lastError)
                    .font(FouleeFont.footnote)
                    .foregroundStyle(FouleeColor.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
            PrimaryButton(title: "Terminer", systemIcon: FouleeIcon.check) { onDismiss(session) }
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 32)
        .animation(.snappy, value: store.highlight)
    }

    /// The outing's best, as a session notification would say it (#531).
    func highlightCard(_ highlight: SessionHighlight) -> some View {
        VStack(spacing: 4) {
            Text(highlight.title)
                .font(FouleeFont.headline)
            Text(highlight.body)
                .font(FouleeFont.callout)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)
    }

    /// « 4 321 pas · 3,20 km · ↑ 42 m » — or, `spoken`, the duration first
    /// and the climb in words, since the arrows are read as arrows.
    func finishedSummary(session: SessionRecord, spoken: Bool = false) -> String {
        let elevation = Elevation(ascent: session.elevationGainMeters, descent: session.elevationLossMeters)
        let parts = [
            spoken ? spokenDurationText(seconds: session.elapsed) : nil,
            String(localized: "\(session.steps.groupedText()) pas"),
            session.distanceKm.kmText(),
            spoken ? elevation.spokenText : elevation.text
        ]
        return parts.compactMap(\.self).joined(separator: spoken ? ", " : " · ")
    }
}

private struct ActiveSessionPreview: View {
    init() {
        prepareDependencies {
            $0.healthKit = .previewValue
            $0.pedometer = .previewValue
        }
    }
    var body: some View {
        ActiveSessionScreen(minutesGoal: 20, activity: .walking, onDismiss: { _ in })
    }
}

#Preview("Active") { ActiveSessionPreview() }
