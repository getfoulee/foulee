import FouleeLiveActivityModel
import SwiftUI
import WidgetKit

@main
struct FouleeLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        SessionLiveActivity<SessionActivityAttributes>()
        // One release, for an activity a build before #732 left running.
        SessionLiveActivity<WalkActivityAttributes>()
    }
}
