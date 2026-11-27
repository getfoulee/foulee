import AppIntents
import Dependencies
import FouleeDesignSystem
import FouleeDomain
import SwiftUI
import UIKit

/// Pre/post-walk dashboard and the app's home. Content-only: the wallpaper is
/// provided by `HomeView`. Data comes from `TodayStore`, which reads HealthKit
/// through the `healthKit` dependency. Settings open from the profile button.
struct TodayScreen: View {
    @State private var store = TodayStore()
    @State private var hydration = HydrationStore()
    @State private var isWalking = false
    /// An outing iOS kept running while the app was gone (#729), reopened.
    @State private var recoveredWalk: ActiveSessionStore?
    /// The sport of the session on screen: the last one, a shortcut's (#604)
    /// or the one picked in « Autre sport » (#743).
    @State private var startingActivity = SessionActivity.walking
    @State private var isChoosingSport = false
    private let sessionStartRouter = SessionStartRouter.shared
    /// The wrist's outing, shown instead of ours (issue #279). The store is not
    /// owned here — `FouleeApp` observes it from process launch, because a
    /// mirror can arrive while no UI is mounted at all.
    @State private var isShowingMirroredWalk = false
    private let mirroredSession = MirroredSessionStore.shared
    private let review = ReviewPromptStore.shared
    @State private var isShowingSettings = false
    @State private var selectedMetric: MetricID?
    @State private var isShowingWeather = false
    @State private var scrollToHydration = false

    @Environment(UserPreferences.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.openURL) private var openURL
    private let scheduler = OutingReminderScheduler()

    /// The app theme, applied to every modal — sheets/covers don't inherit the
    /// root `.preferredColorScheme`, so without this they'd render in the
    /// system appearance and ignore the user's Clair/Sombre choice. `.system`
    /// is resolved to the live system scheme so we never pass `nil` (which
    /// fails to reset an already-dark sheet back to light).
    private var preferredScheme: ColorScheme {
        preferences.themeMode.colorScheme ?? systemColorScheme
    }

    var body: some View {
        content
            .task { await store.bootstrap() }
            .task { await reopenRecoveredWalk() }
            .task {
                hydration.startObserving()
                await hydration.refresh()
            }
            .task(id: todayPreferencesKey(preferences)) {
                // Push the user's current goals + walk-window into the
                // store on first appear and whenever they change.
                // `apply` re-derives the snapshot from cached history
                // so the ring, streak and countdown update immediately.
                store.apply(preferences: preferences)
                // Here rather than on appear: a shortcut that cold-launched
                // the app must find the user's mode already applied.
                startPendingShortcut()
            }
            // `.task` runs once; re-query whenever the app returns to the
            // foreground so the dashboard isn't stuck on stale (or zero)
            // values after the user walked and came back.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await store.refresh() }
                    Task { await hydration.refresh() }
                }
            }
            .onChange(of: preferences.hydrationEnabled) { _, enabled in
                // Turning hydration on prompts for Health (water) access.
                if enabled { Task { await hydration.enable() } }
            }
            .overlay(alignment: .top) {
                // "C'est compté" feedback after a notification action tap.
                HydrationActionToast(
                    onLogged: { Task { await hydration.refresh() } },
                    onUndo: { await hydration.undo($0) }
                )
            }
            .onChange(of: sessionStartRouter.pending) { _, _ in startPendingShortcut() }
            .onOpenURL { url in
                // A getfoulee.app link or the hydration widget's tap. The home
                // is already the screen the app opens on.
                switch AppLinks.destination(of: url) {
                case .weekRecap: RecapRouter.shared.open(.week)
                case .hydration: scrollToHydration = true
                case .home, nil: break
                }
            }
            .reviewRequest(
                store: review,
                at: store.snapshot.map { ReviewProgress($0, outings: review.outings) },
                isAllowed: store.lastError == nil
            )
            .whatsNewPresentation(
                isAllowed: store.snapshot != nil && !isWalking && !isShowingMirroredWalk,
                colorScheme: preferredScheme
            )
            .mirroredWalkCover(
                store: mirroredSession,
                isPresented: $isShowingMirroredWalk,
                isWalking: $isWalking,
                scheme: preferredScheme
            )
            .fullScreenCover(isPresented: $isWalking) { walkScreen }
            .sheet(
                item: $selectedMetric,
                onDismiss: { Task { await store.refresh() } },
                content: { metric in
                    MetricStatsScreen(metric: metric, dailyGoal: dailyGoal(for: metric)) {
                        selectedMetric = nil
                    }
                    .preferredColorScheme(preferredScheme)
                }
            )
            .sheet(isPresented: $isChoosingSport) {
                SportPickerSheet(
                    sections: store.sportChoice.sections,
                    current: store.startActivity,
                    // Choosing names the sport; the home's buttons start it,
                    // on the device the user picks there (#832).
                    onChoose: { sport in
                        store.chosenSport = sport
                        isChoosingSport = false
                    },
                    onClose: { isChoosingSport = false }
                )
            }
            .sheet(isPresented: $isShowingWeather) {
                if let weather = store.snapshot?.weather {
                    WeatherDetailSheet(weather: weather, windowStart: store.walkWindowStart, location: store.locationAccess) {
                        isShowingWeather = false
                    }
                        .preferredColorScheme(preferredScheme)
                }
            }
            .modifier(RecapPresentation(
                goalMinutes: store.minutesGoal,
                activeDays: preferences.activeDays,
                waterGoalML: preferences.hydrationEnabled ? preferences.hydrationGoalML : nil,
                colorScheme: preferredScheme
            ))
            .sheet(isPresented: $isShowingSettings) {
                SettingsScreen(preferences: preferences) { isShowingSettings = false }
                    .presentationBackground { SheetBackground() }
                    .preferredColorScheme(preferredScheme)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = store.snapshot {
            loaded(snapshot: snapshot)
        } else {
            placeholder
        }
    }

    private func heroCard(snapshot: TodaySnapshot) -> some View {
        TodayHeroCard(
            snapshot: snapshot,
            mirroring: mirroredSession.session?.device,
            canStartOnWatch: mirroredSession.canStartOnWatch,
            onStartOnWatch: { startOnWatch() },
            sport: store.startActivity,
            onChooseSport: { isChoosingSport = true },
            notificationsEnabled: preferences.notificationsEnabled,
            notificationsDenied: store.notificationsAuthorizationStatus == .denied,
            onStart: { startWalk() },
            onSummary: { RecapRouter.shared.open(.week) },
            onWeatherTap: { isShowingWeather = true },
            onSnooze: { interval in
                Task { await scheduler.snooze(after: interval) }
            },
            onToggleNotifications: {
                preferences.notificationsEnabled.toggle()
            },
            onOpenNotificationSettings: {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    openURL(url)
                }
            }
        )
    }

    private func loaded(snapshot: TodaySnapshot) -> some View {
        ScrollViewReader { proxy in
        ScrollView {
            // One margin and one gap for every section, set here rather than
            // repeated on each card — and wider than the 12 pt it was, so the
            // home reads as separate blocks instead of one dense column.
            VStack(spacing: Self.sectionSpacing) {
                header(snapshot: snapshot)
                    .padding(.top, 8)
                // One card at most. A failed fetch outranks the Garmin hint —
                // a day can perfectly well hold data *and* a failed fetch, and
                // only the banner explains why the numbers may be wrong.
                //
                // No « Pas encore de données » card any more: it showed every
                // morning before the first step, said nothing the zeros below
                // did not, and its « Ouvrir Santé » led nowhere useful —
                // HealthKit never tells an app its read access was refused, so
                // the card could not tell that case from an ordinary empty day.
                if store.lastError != nil {
                    DegradedBanner(state: .healthUnreadable)
                } else if store.showsGarminSyncHint {
                    // An unsynced Garmin Connect is a gap with a real fix, so
                    // this hint stays.
                    GarminSyncHintCard()
                }
                heroCard(snapshot: snapshot)
                TodayStatsGrid(snapshot: snapshot) { selectedMetric = $0 }
                HydrationHomeCard(preferences: preferences, store: hydration)
                    .id("hydrationCard")
                RecapHomeCard(
                    goalMinutes: store.minutesGoal,
                    activeDays: preferences.activeDays,
                    todayMinutes: snapshot.minutes
                ) { RecapRouter.shared.open($0) }
                if snapshot.weather.isAvailable {
                    // Guideline 5.2.5: WeatherKit data on screen needs Apple
                    // Weather's attribution on the same screen.
                    WeatherAttributionView()
                }
            }
            .screenColumn()
            .padding(.bottom, 40)
        }
        .refreshable { await store.refresh() }
        .modifier(HydrationDeepLinkScroll(proxy: proxy, pending: $scrollToHydration))
        }
    }

    /// The gap between two sections of the home.
    private static let sectionSpacing: CGFloat = 20

    private var placeholder: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(FouleeColor.accentMid)
            Text("Connexion à Santé…")
                .font(FouleeFont.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func header(snapshot: TodaySnapshot) -> some View {
        // The streak and the gear under the title at the accessibility sizes:
        // beside it, « Aujourd'hui » was cut to « Aujou… ».
        AdaptiveStack(
            stacked: VStackLayout(alignment: .leading, spacing: 8),
            regular: HStackLayout(alignment: .center, spacing: 12)
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatted(date: snapshot.date))
                    .font(FouleeFont.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
                Text("Aujourd'hui")
                    .font(FouleeFont.largeTitle)
                    // Shrinks rather than breaking into « Aujourd'-hui » when
                    // the streak beside it runs to three digits, or the text
                    // size is large, on a narrow iPhone.
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // The screen's title, read once with its date.
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                // The streak lives in the Bilan, on the month in progress (#445).
                TodayStreakBadge(streak: snapshot.streak, bestStreak: snapshot.bestStreak) {
                    RecapRouter.shared.open(.month)
                }
                Button { isShowingSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .scaledSystemFont(size: 32)
                        .foregroundStyle(FouleeColor.accentMid)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Réglages")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatted(date: Date) -> String {
        date.dayText.uppercased()
    }

    /// Only steps + minutes have a daily goal to draw on the stats chart.
    private func dailyGoal(for metric: MetricID) -> Double? {
        switch metric {
        case .steps: Double(store.stepsGoal)
        case .minutes: Double(store.minutesGoal)
        case .distance, .calories: nil
        }
    }
}

/// Scrolls the home to the hydration card when a hydration link fires (widget
/// tap, getfoulee.app/hydratation). Handles both orders: URL before the content is
/// mounted (cold launch → `onAppear`) and after (warm open → `onChange`).
private struct HydrationDeepLinkScroll: ViewModifier {
    let proxy: ScrollViewProxy
    @Binding var pending: Bool

    func body(content: Content) -> some View {
        content
            .onAppear(perform: scrollIfPending)
            .onChange(of: pending) { _, _ in scrollIfPending() }
    }

    private func scrollIfPending() {
        guard pending else { return }
        pending = false
        // Slight delay so the freshly mounted scroll content has laid out.
        // No stored handle: a repeat deep link just scrolls to the same card,
        // so a stale fire is harmless and cancellation would be dead weight.
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            withAnimation { proxy.scrollTo("hydrationCard", anchor: .center) }
        }
    }
}

/// Single value that flips whenever any preference the Today store reads
/// changes — drives the `.task(id:)` re-sync. File-scope so it stays out of
/// the view's body-length budget.
///
/// Internal rather than private, for the same reason `TodayStore.hasChanged`
/// is: `.task(id:)` lives in a `View` and cannot be driven from a test
/// process, so this key is the only assertable answer to "will a settings
/// change be noticed in the session it was made?".
func todayPreferencesKey(_ preferences: UserPreferences) -> String {
    let goals = "\(preferences.stepsGoal)-\(preferences.minutesGoal)"
    let window = "\(preferences.walkWindowStart.rawMinutes)-\(preferences.activeDays.bitmask)"
    let hydration = "\(preferences.hydrationEnabled)-\(preferences.hydrationGoalML)-\(preferences.hydrationGlassML)"
    // The favourites and the last sport decide what « Démarrer » starts and
    // what the wrist is sent (issues #224, #743).
    let favorites = preferences.favoriteSports.map(\.rawValue).sorted().joined(separator: ",")
    let sport = "\(favorites)-\(preferences.lastSport?.sport.rawValue ?? "")"
    return "\(goals)-\(window)-\(hydration)-\(sport)"
}

private struct TodayPreviewWithData: View {
    init() {
        prepareDependencies { $0.healthKit = .previewValue }
    }
    var body: some View {
        TodayScreen()
            .environment(UserPreferences(defaults: previewDefaults(suite: "preview-today-light")))
            .preferredColorScheme(.light)
    }
}

private struct TodayPreviewLoading: View {
    init() {
        prepareDependencies {
            $0.healthKit = HealthKitClient(
                requestAuthorization: {
                    try await Task.sleep(for: .seconds(60))
                    return true
                },
                todayMetrics: { .zero },
                saveWorkout: { _ in },
                dailyMinutes: { _ in [] },
                recentWorkouts: { _ in [] },
                workoutDetail: { summary in
                    WorkoutDetail(summary: summary, heartRateSamples: [], stepsCount: 0)
                }
            )
        }
    }
    var body: some View {
        TodayScreen()
            .environment(UserPreferences(defaults: previewDefaults(suite: "preview-today-loading")))
    }
}

private struct TodayPreviewDark: View {
    init() {
        prepareDependencies { $0.healthKit = .previewValue }
    }
    var body: some View {
        TodayScreen()
            .environment(UserPreferences(defaults: previewDefaults(suite: "preview-today-dark")))
            .preferredColorScheme(.dark)
    }
}

private func previewDefaults(suite: String) -> UserDefaults {
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

#Preview("With data") { TodayPreviewWithData() }
#Preview("Loading") { TodayPreviewLoading() }
#Preview("Dark") { TodayPreviewDark() }

private extension TodayScreen {
    /// Push the active walk sheet. Available from the hero even once today's
    /// goal is met (the card then also offers "Voir le bilan"), so a second
    /// walk can always be started.
    /// Start on the phone — unless the wrist is already recording (issue #279).
    ///
    /// **The watch always wins**, and not by a coin toss: it is the only one of
    /// the two HealthKit lets mirror, so a phone session beside it would be
    /// invisible from there. Two overlapping `HKWorkout` records are also
    /// plainly false, which App Store review has its own wording for.
    ///
    /// Nothing prevented this before the mirror existed — the phone had no way
    /// of knowing.
    ///
    /// - Parameters:
    ///   - activity: a shortcut's or the picker's sport; `nil` for the home
    ///     button, which starts the last one.
    ///   - donates: teach Siri the habit, so « Commencer une sortie » shows up
    ///     in its suggestions and Spotlight (issue #608). A shortcut run is
    ///     donated by the system already.
    func startWalk(_ activity: SessionActivity? = nil, donates: Bool = true) {
        guard !mirroredSession.isMirroring else {
            isShowingMirroredWalk = true
            return
        }
        startingActivity = store.beginStart(requested: activity, preferences: preferences)
        if donates {
            StartOutingIntent().donate()
        }
        // Capture today's totals now so the post-walk overlay lands on the
        // right baseline (see TodayStore.registerFinishedWalk).
        store.walkWillStart()
        isWalking = true
    }

    /// Starts what « Commencer une sortie » asked for (issue #604). A session
    /// already on screen wins.
    func startPendingShortcut() {
        guard let request = sessionStartRouter.take(), !isWalking else { return }
        startWalk(request.activity, donates: false)
    }

    /// The wrist records a better outing (#283), so the phone hands it the
    /// sport the buttons name and the wrist opens the session.
    func startOnWatch() {
        let activity = store.beginStart(requested: nil, preferences: preferences)
        Task { await mirroredSession.startOnWatch(activity) }
    }

    /// The session screen, on a fresh store or on one that took back an
    /// outing the app had lost (#729).
    var walkScreen: some View {
        ActiveSessionScreen(
            minutesGoal: store.minutesGoal,
            // Resolved by the store at the tap (issues #223, #743), and
            // unlike this body the store is reachable from a test.
            activity: startingActivity,
            store: recoveredWalk ?? ActiveSessionStore(),
            onDismiss: { session in
                isWalking = false
                recoveredWalk = nil
                Task {
                    await store.registerFinishedWalk(session)
                    review.recordOuting()
                }
            },
            // Backed out of the picker: close, and register nothing.
            // The baseline `walkWillStart` captured is simply left
            // unused — no `PendingSession` is created, so the home shows
            // the same numbers it already showed.
        )
        .preferredColorScheme(preferredScheme)
    }

    /// Back on the session screen when iOS kept the outing's session running
    /// after the app was killed (#729), rather than on a home that ignores it.
    func reopenRecoveredWalk() async {
        guard !isWalking, let walk = await ActiveSessionStore.recovered(minutesGoal: store.minutesGoal) else { return }
        recoveredWalk = walk
        isWalking = true
    }
}
