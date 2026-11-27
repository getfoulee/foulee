import Foundation

nonisolated extension SportDescriptor {
    // Rides (#749). The watch measures their energy and reads a bike sensor;
    // the iPhone records an outdoor ride with the GPS alone (#750), its
    // distance summed along the route, and estimates the energy by the minute
    // (MET 6 for about 70 kg, rounded down).

    static let cycling = SportDescriptor(
        id: .cycling,
        family: .cycling,
        location: .outdoor,
        capabilities: [.route, .distance, .elevation, .cyclingSensors],
        speedDisplay: .speed,
        gait: nil,
        followsGaitChanges: false,
        isRecordable: true,
        labelResource: "Vélo",
        sessionTitleResource: "Ta sortie à vélo",
        glyph: ActivityGlyph.cycling,
        healthKitActivityRawValue: 13,
        garminSport: nil,
        kcalPerStep: nil,
        kcalPerMinute: 6,
        benchmarks: .ridden,
        nounResource: "sortie à vélo",
        verbResource: "tu roules"
    )

    /// A home trainer: no route and no distance of its own, but the speed,
    /// cadence and power a sensor sends. The watch's only: the iPhone would
    /// measure nothing indoors.
    static let indoorCycling = SportDescriptor(
        id: .indoorCycling,
        family: .cycling,
        location: .indoor,
        capabilities: [.cyclingSensors],
        speedDisplay: .speed,
        gait: nil,
        followsGaitChanges: false,
        isRecordable: true,
        devices: .watchOnly,
        labelResource: "Vélo d'intérieur",
        sessionTitleResource: "Ta séance de vélo d'intérieur",
        glyph: ActivityGlyph.indoorCycling,
        // A ride in Santé, indoors. Foulée's tag tells it apart.
        healthKitActivityRawValue: 13,
        garminSport: nil,
        kcalPerStep: nil,
        kcalPerMinute: 6,
        benchmarks: .stationary,
        nounResource: "séance de vélo d'intérieur",
        verbResource: "tu roules"
    )
}
