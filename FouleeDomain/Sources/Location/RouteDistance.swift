import Foundation

/// The distance along a route, from its GPS fixes (#750): what a phone ride
/// measures, with no steps to estimate one from.
nonisolated public enum RouteDistance {
    /// The largest step two fixes may be apart and still count. Beyond it the
    /// fix is a jump of the GPS, not a stretch ridden: under-crediting is the
    /// rule for an estimate.
    public static let maximumStepMeters: Double = 200

    /// The great-circle distance between two fixes, in metres (haversine).
    public static func meters(from start: Coordinate, to end: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (end.longitude - start.longitude) * .pi / 180
        let haversine = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * atan2(sqrt(haversine), sqrt(1 - haversine))
    }

    /// What the step from `previous` to `next` adds to the distance: nothing
    /// for the first fix, or for a jump.
    public static func step(from previous: Coordinate?, to next: Coordinate) -> Double {
        guard let previous else { return 0 }
        let meters = meters(from: previous, to: next)
        return meters <= maximumStepMeters ? meters : 0
    }
}
