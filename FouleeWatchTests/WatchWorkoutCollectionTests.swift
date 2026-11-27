import FouleeHealth
import FouleeDomain
import Foundation
import HealthKit
import Testing

/// What a live session actually collects (issue #223).
///
/// The open question the issue asked to settle was "what does
/// `HKLiveWorkoutDataSource` infer for `.running`?" — a type read back in
/// `ingest` but never collected is a counter frozen at 0 for a whole session,
/// silently. It was thought to need a device; it does not. `typesToCollect` is
/// the data source's own answer, readable in the simulator, and the tests below
/// pin both the inference and the fix for it.
///
/// What still needs a real watch is the other half — whether the sensors then
/// produce non-zero values for a run — which no simulator can answer. See the
/// open item recorded on the issue.
@Suite("Watch workout collection")
struct WatchWorkoutCollectionTests {
    private func configuration(_ activity: SessionActivity) -> HKWorkoutConfiguration {
        WorkoutEngine.configuration(for: activity)
    }

    private func inferredTypes(_ activity: SessionActivity) -> Set<HKQuantityType> {
        HKLiveWorkoutDataSource(
            healthStore: HKHealthStore(),
            workoutConfiguration: configuration(activity)
        ).typesToCollect
    }

    private func collectedTypes(_ activity: SessionActivity) -> Set<HKQuantityType> {
        WorkoutEngine.makeDataSource(
            healthStore: HKHealthStore(),
            configuration: configuration(activity),
            collecting: .measured
        ).typesToCollect
    }

    @Test("Every type the store reads back is collected, for a walk and for a run")
    func everyIngestedTypeIsCollected() {
        // The contract that matters: `ingest` reads exactly
        // `WorkoutEngine.collectedTypes`, so anything missing here is a live counter
        // stuck at 0 for the whole session. Both activities, because the
        // inference is not the same for both — see the next test.
        for activity in SessionActivity.allCases {
            #expect(collectedTypes(activity).isSuperset(of: WorkoutEngine.collectedTypes(for: activity.sport)))
        }
    }

    @Test("The inference alone would freeze the step counter on a walk")
    func walkingInferenceOmitsStepCount() {
        // This is why the explicit enable exists: measured on device before
        // #223 (the live "pas" counter stayed at 0 while distance and heart
        // rate updated), and reproduced here from the data source itself.
        //
        // A failure here is not a Foulée bug — it means watchOS started
        // inferring step count for a walk and the enable became redundant.
        // Update the record; don't remove the enable.
        #expect(!inferredTypes(.walking).contains(HKQuantityType(.stepCount)))
        #expect(inferredTypes(.walking).contains(HKQuantityType(.distanceWalkingRunning)))
        #expect(inferredTypes(.walking).contains(HKQuantityType(.activeEnergyBurned)))
        #expect(inferredTypes(.walking).contains(HKQuantityType(.heartRate)))
    }

    @Test("A run infers everything the store reads — the answer #223 was missing")
    func runningInferenceCoversEveryIngestedType() {
        // The unknown the issue flagged: for `.running` the data source already
        // infers step count too (plus the running-dynamics types Foulée doesn't
        // read). So the enable changes nothing for a run — it is not what makes
        // running work, it is what keeps a future inference change from
        // breaking it.
        #expect(inferredTypes(.running).isSuperset(of: WorkoutEngine.collectedTypes(for: .running)))
    }

    @Test("Enabling never drops a type the source had already inferred")
    func enablingIsAdditive() {
        // The "no-op when already inferred" claim in `WorkoutEngine.makeDataSource`, held
        // rather than asserted in prose: a walk keeps its inferred set and
        // gains step count; a run keeps everything, running dynamics included.
        for activity in SessionActivity.allCases {
            #expect(collectedTypes(activity).isSuperset(of: inferredTypes(activity)))
        }
    }

    @Test("A session that measures nothing collects nothing (#730)")
    func phoneCollectsNothing() {
        // The iPhone's builder: iOS already writes the phone's steps and
        // distance, so a sample from the builder would count the day twice.
        for activity in SessionActivity.allCases {
            let source = WorkoutEngine.makeDataSource(
                healthStore: HKHealthStore(),
                configuration: configuration(activity),
                collecting: .nothing
            )
            #expect(source.typesToCollect.isEmpty)
        }
    }

    @Test("A sport on foot collects steps, distance, energy and heart rate; an indoor one energy and heart rate")
    func collectedTypesFollowTheCapabilities() {
        let measured: Set<HKQuantityType> = [HKQuantityType(.activeEnergyBurned), HKQuantityType(.heartRate)]
        let onFoot = measured.union([HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning)])
        // A ride's distance, and its bike sensor's figures (#749).
        let ride = measured.union(
            [.distanceCycling, .cyclingSpeed, .cyclingCadence, .cyclingPower].map { HKQuantityType($0) }
        )
        for activity in SessionActivity.allCases {
            let expected = switch activity.sport.descriptor.family {
            case .onFoot: onFoot
            case .training: measured
            case .cycling: ride
            }
            #expect(Set(WorkoutEngine.collectedTypes(for: activity.sport)) == expected)
        }
    }
}
