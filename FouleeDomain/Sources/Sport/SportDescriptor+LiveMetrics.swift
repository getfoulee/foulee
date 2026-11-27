import Foundation

nonisolated public extension SportDescriptor {
    /// The figures a live screen shows for this sport, in the order they are
    /// drawn (#732): steps for a sport the pedometer counts, distance for one
    /// that measures it, and the calories every sport burns. A sport without a
    /// distance shows no « 0,00 km ».
    var liveMetrics: [MetricID] {
        var metrics: [MetricID] = []
        if capabilities.contains(.steps) { metrics.append(.steps) }
        if capabilities.contains(.distance) { metrics.append(.distance) }
        metrics.append(.calories)
        return metrics
    }

    /// Whether a live screen shows the climb and the descent: only for a sport
    /// the altimeter follows.
    var showsElevation: Bool { capabilities.contains(.elevation) }

    /// The main figure of a live screen: the climb for a sport told by it
    /// (#744), the calories for one without steps (#745), the steps otherwise.
    var liveLead: MetricLead {
        if showsElevation, benchmarks.leadingRecord == .climb { return .climb }
        return capabilities.contains(.steps) ? .steps : .calories
    }

    /// Whether a live screen draws a route, and so asks for the GPS.
    var tracksRoute: Bool { capabilities.contains(.route) }

    /// Whether a live screen shows a distance: with a route, or on a
    /// treadmill without one (#746).
    var measuresDistance: Bool { capabilities.contains(.distance) }
}

/// What a live screen shows first.
nonisolated public enum MetricLead: Equatable, Sendable {
    case steps
    case climb
    case calories
}
