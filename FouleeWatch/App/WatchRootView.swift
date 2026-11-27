import FouleeDomain
import SwiftUI

/// Owns the workout store and routes to home / active / ended screens.
struct WatchRootView: View {
    @State private var store = WatchWorkoutStore()
    @State private var todayStore = WatchTodayStore()
    /// « Autre sport »: the picker is on screen and nothing has started.
    /// Local to the idle route — a session in flight clears it.
    @State private var isChoosingActivity = false
    /// A swim waiting for its pool (#751).
    @State private var swimWaitingForPool: SessionActivity?
    private let pendingStart = WatchPendingStart.shared
    /// A session that outlived the app, to pick up (issue #554).
    private let recovery = WatchWorkoutRecovery.shared
    /// The phone's session in flight, shown while the wrist records nothing
    /// itself (issue #342).
    private let phoneSession = WatchPhoneSession.shared

    var body: some View {
        Group {
            switch store.state {
            case .idle:
                if let snapshot = phoneSession.shown(at: .now) {
                    WatchPhoneSessionPager(
                        snapshot: snapshot,
                        isSending: phoneSession.isSending,
                        errorMessage: phoneSession.errorMessage,
                        onCommand: { command in Task { await phoneSession.send(command) } }
                    )
                } else {
                    idleScreen
                }
            case .active(let metrics):
                WatchSessionPager(
                    metrics: metrics,
                    today: todayStore,
                    route: store.route,
                    errorMessage: store.lastError,
                    isSaving: store.isSaving,
                    onTogglePause: { store.isPaused ? store.resume() : store.pause() },
                    onStop: { Task { await store.stop() } }
                )
            case .ended(let metrics, let saveFailed):
                WatchFinishedView(
                    metrics: metrics,
                    route: WatchRoutePortion.portions(
                        of: store.route.locations,
                        legs: metrics.legs,
                        current: nil
                    ),
                    saveFailed: saveFailed,
                    // The one sentence that explains a failure, shown where the
                    // failure is (issue #256). It used to reach only the home
                    // screen, which `reset()` clears on the way there.
                    errorMessage: store.lastError,
                    endedOnLowBattery: store.endedOnLowBattery,
                    onRetry: { Task { await store.retrySave() } },
                    onDone: { store.reset() }
                )
            }
        }
        .animation(.easeOut(duration: 0.25), value: store.state)
        .animation(.easeOut(duration: 0.25), value: isChoosingActivity)
        .fullScreenCover(isPresented: Binding(
            get: { swimWaitingForPool != nil },
            set: { if !$0 { swimWaitingForPool = nil } }
        )) {
            if let swim = swimWaitingForPool {
                WatchPoolLengthView(
                    current: PoolLengthPreference.read(from: WatchSyncStore.sharedDefaults),
                    onStart: { beginSwim(swim, in: $0) },
                    onCancel: { swimWaitingForPool = nil }
                )
            }
        }
        .task { await WatchWaterBackgroundDelivery.start() }
        // A session that outlived the app first (issue #554): a start the
        // phone asked for must not open a second one beside it. Then a start
        // asked for by the phone (issue #283) or by Siri (#607), drained on
        // appear *and* watched, because both orders happen: the request may
        // have launched this app, or landed while it was already on screen.
        .task {
            await store.recover()
            startIfAsked()
        }
        .onChange(of: recovery.requests) { _, _ in Task { await store.recover() } }
        .onChange(of: pendingStart.activity) { _, _ in startIfAsked() }
    }

    /// Home, with nothing in flight here or on the phone.
    private var idleScreen: some View {
        WatchIdleScreen(
            today: todayStore,
            errorMessage: store.lastError,
            isChoosingActivity: isChoosingActivity,
            onStart: begin,
            onChooseSport: { isChoosingActivity = true },
            onCancel: { isChoosingActivity = false }
        )
    }

    /// Start what the phone or Siri asked for, if anything, and if nothing is
    /// running.
    ///
    /// The guard is not politeness: the phone can ask while a session is
    /// already in flight — `startWatchApp` does not know what the wrist is
    /// doing — and starting a second one would strand the first. A phone
    /// outing on the wrist wins too: its mirror stays, as the phone's own
    /// shortcut opens the watch's mirror (#604). The request is taken either
    /// way, so a refused one does not start a session later, on some
    /// unrelated relaunch.
    private func startIfAsked() {
        let activity = pendingStart.take()
        guard case .idle = store.state, phoneSession.shown(at: .now) == nil, let activity else { return }
        begin(activity)
    }

    /// One place a session begins, whatever chose the sport. It becomes the
    /// one « Démarrer » starts next (#743).
    private func begin(_ activity: SessionActivity) {
        isChoosingActivity = false
        // A swim asks for its pool first (#751).
        guard activity.sport.descriptor.family != .swimming else {
            swimWaitingForPool = activity
            return
        }
        Self.recordStart(of: activity, at: .now)
        Task { await store.start(activity: activity) }
    }

    /// The swim starts in the pool chosen, which the next one offers first.
    private func beginSwim(_ activity: SessionActivity, in pool: PoolLength) {
        swimWaitingForPool = nil
        PoolLengthPreference.write(pool, to: WatchSyncStore.sharedDefaults)
        Self.recordStart(of: activity, at: .now)
        Task { await store.start(activity: activity, pool: pool) }
    }

    /// What « Démarrer » starts and « Autre sport » lists (issues #223,
    /// #743): the newer of the iPhone's last sport and the watch's own, among
    /// the favourites the phone synced.
    ///
    /// Read at tap time, not at view build: the phone can push a new payload
    /// while this screen sits on the wrist, and the stamp is permanent. A
    /// watch that has never received a payload starts a walk, the app's
    /// historical behaviour, unless it has started something itself.
    ///
    /// Static, internal, and taking the defaults suite rather than reading the
    /// shared one inline: this is the watch's whole half of the phone→wrist
    /// wire, and inside a `View` body nothing could assert it.
    static func sportChoice(
        syncedTo defaults: UserDefaults = WatchSyncStore.sharedDefaults
    ) -> SportChoice.Resolved {
        let payload = WatchSyncStore.read(from: defaults)
        let favorites = payload?.favorites ?? [.walking]
        let last = LastSportPreference.newest(payload?.lastSport, in: defaults)
        return SportChoice.resolve(last: last, favorites: favorites)
    }

    /// Remembers a sport started on the wrist, in the App Group beside the
    /// phone's payload, and sends it to the iPhone so that its « Démarrer »
    /// offers the same sport (#830).
    static func recordStart(
        of activity: SessionActivity,
        at date: Date,
        in defaults: UserDefaults = WatchSyncStore.sharedDefaults,
        sending send: (LastSport) -> Void = LastSportTransfer.send
    ) {
        let last = LastSport(activity, at: date)
        LastSportPreference.write(last, to: defaults)
        send(last)
    }
}
