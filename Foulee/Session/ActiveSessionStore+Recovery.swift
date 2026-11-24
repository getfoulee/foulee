import Dependencies
import Foundation

extension ActiveSessionStore {
    /// A store already carrying the outing iOS kept running while the app was
    /// gone (#729), or `nil` when there is none. Never prompts.
    static func recovered(minutesGoal: Int) async -> ActiveSessionStore? {
        @Dependency(\.phoneWorkoutSession) var workoutSession
        guard let recovered = await workoutSession.recover() else { return nil }
        let store = ActiveSessionStore()
        await store.adopt(recovered, minutesGoal: minutesGoal)
        return store
    }
}
