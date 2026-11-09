import SwiftUI

/// The page under every screen and sheet: one flat neutral from the ramp
/// (`FouleeColor.page`), edge to edge.
///
/// Sheets mount it through `.presentationBackground`, so iOS keeps it during
/// the drag to dismiss. Flat, it costs nothing to composite and fills any
/// window as it is — the iPhone Duo's inner screen included.
struct PageBackground: View {
    var body: some View {
        FouleeColor.page
            .ignoresSafeArea()
    }
}
