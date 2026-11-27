import FouleeDomain
import Foundation
@preconcurrency import WatchConnectivity

/// Sends the sport just started on the wrist to the iPhone (#830).
///
/// `transferUserInfo` rather than a message: it is queued and delivered in
/// the background, even when the iPhone is out of reach or its app is not
/// running, so a run started far from the phone still reaches it later.
nonisolated enum LastSportTransfer {
    static func send(_ last: LastSport) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else {
            FouleeLog.session.error("dernier sport non envoyé : pas de liaison avec l'iPhone")
            return
        }
        WCSession.default.transferUserInfo(last.transferUserInfo)
    }
}
