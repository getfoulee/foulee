import Foundation

nonisolated public extension SportDescriptor {
    /// The figures a live screen shows for this sport, in the order they are
    /// drawn (#732): steps for a sport the pedometer counts, distance for one
    /// with a route, and the calories every sport burns. A sport without a
    /// distance shows no « 0,00 km ».
    var liveMetrics: [MetricID] {
        var metrics: [MetricID] = []
        if capabilities.contains(.steps) { metrics.append(.steps) }
        if capabilities.contains(.route) { metrics.append(.distance) }
        metrics.append(.calories)
        return metrics
    }

    /// Whether a live screen shows the climb and the descent: only for a sport
    /// the altimeter follows.
    var showsElevation: Bool { capabilities.contains(.elevation) }
}
