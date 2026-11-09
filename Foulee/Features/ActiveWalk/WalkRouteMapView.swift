import FouleeKit
import MapKit
import SwiftUI

/// Sheet that draws the path walked so far as a polyline over a map. Shows a
/// friendly empty state until enough fixes have come in to draw a line.
///
/// One line per stretch, in that stretch's colour: a single stroke for the
/// phone's own walk, one per portion for an outing mirrored from the wrist
/// (issue #334).
struct WalkRouteMapView: View {
    let strokes: [RouteLines.Stroke]
    var onClose: () -> Void

    init(route: [Coordinate], onClose: @escaping () -> Void) {
        self.strokes = WalkRouteMap.strokes(route: route)
        self.onClose = onClose
    }

    init(strokes: [RouteLines.Stroke], onClose: @escaping () -> Void) {
        self.strokes = strokes
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            WalkRouteMap(strokes: strokes, isFullBleed: true)
            SheetCloseButton(accessibilityLabel: "Fermer la carte", action: onClose)
        }
    }
}

/// The route itself, or a friendly wait until there is a line to draw: the
/// sheet's content, and the map beside the figures on a screen wider than
/// tall (#662).
struct WalkRouteMap: View {
    let strokes: [RouteLines.Stroke]
    /// The map runs under the bars and the screen's margins; the wait stays
    /// in the safe area, clear of the camera and the hinge (#663).
    var isFullBleed = false

    /// The live route is a single stroke; its identity never changes.
    private static let strokeID = UUID()

    /// The phone's own walk: one stroke, in the accent colour — the phone
    /// cannot tell a walk from a run while it records (issue #246).
    static func strokes(route: [Coordinate]) -> [RouteLines.Stroke] {
        [RouteLines.Stroke(id: strokeID, coordinates: route.map(\.locationCoordinate), tint: FouleeColor.accent)]
    }

    private var isDrawable: Bool {
        strokes.contains { $0.coordinates.count >= 2 }
    }

    var body: some View {
        if isDrawable {
            map
                .ignoresSafeArea(edges: isFullBleed ? .all : [])
        } else {
            emptyState
        }
    }

    private var map: some View {
        Map(initialPosition: .automatic) {
            RouteLines(strokes: strokes)
            if let last = strokes.last?.coordinates.last {
                Annotation("Position", coordinate: last) {
                    // Neutral glyph (#222): the map is drawn from a route, and
                    // nothing here knows whether it was walked or run.
                    Image(systemName: FouleeIcon.mixedCardio)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(FouleeColor.accent, in: Circle())
                        // Edged in white, like the kilometre marks, so it
                        // stands off any map tile.
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                }
            }
        }
    }

    private var emptyState: some View {
        ZStack {
            PageBackground()
            VStack(spacing: 12) {
                Image(systemName: FouleeIcon.location)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Tracé en attente")
                    .font(FouleeFont.title3)
                Text("Ton parcours apparaîtra ici dès les premiers points GPS.")
                    .font(FouleeFont.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

#Preview("Route") {
    WalkRouteMapView(
        route: [
            Coordinate(latitude: 48.8634, longitude: 2.3270),
            Coordinate(latitude: 48.8638, longitude: 2.3285),
            Coordinate(latitude: 48.8641, longitude: 2.3301),
            Coordinate(latitude: 48.8647, longitude: 2.3318)
        ],
        onClose: {}
    )
}

#Preview("Empty") {
    WalkRouteMapView(route: [], onClose: {})
}
