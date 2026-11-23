import Dependencies
import Foundation

extension ActiveWalkStore {
    /// A store already carrying the outing iOS kept running while the app was
    /// gone (#729), or `nil` when there is none. Never prompts.
    static func recovered(minutesGoal: Int) async -> ActiveWalkStore? {
        @Dependency(\.phoneWorkoutSession) var workoutSession
        guard let recovered = await workoutSession.recover() else { return nil }
        let store = ActiveWalkStore()
        await store.adopt(recovered, minutesGoal: minutesGoal)
        return store
    }
}
