import Foundation

nonisolated extension SportDescriptor {
    // Rides (#749), on the watch only until #750: the iPhone has no honest
    // distance without steps. The watch measures their energy; the per-minute
    // rate is only the rule every recordable sport follows (MET 6 for about
    // 70 kg, rounded down).

    static let cycling = SportDescriptor(
        id: .cycling,
        family: .cycling,
        location: .outdoor,
        capabilities: [.route, .distance, .elevation, .cyclingSensors],
        speedDisplay: .speed,
        gait: nil,
        followsGaitChanges: false,
        isRecordable: true,
        devices: .watchOnly,
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
    /// cadence and power a sensor sends.
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
