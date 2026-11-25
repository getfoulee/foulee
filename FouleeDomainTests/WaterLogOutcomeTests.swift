import Foundation
import Testing
@testable import FouleeDomain

/// What Siri says after « J'ai bu un verre », the same on the phone and the
/// watch (#724).
@Suite("Water log outcome")
struct WaterLogOutcomeTests {
    @Test("A logged glass names its size")
    func loggedNamesTheGlass() {
        #expect(WaterLogOutcome.logged(milliliters: 250).dialog == "C'est noté : +250 ml d'eau.")
    }

    @Test("Every failure says what to do, each in its own words")
    func failuresAreDistinct() {
        let failures: [WaterLogOutcome] = [.unavailable, .denied, .notDetermined, .failed]
        let dialogs = failures.map(\.dialog)
        #expect(Set(dialogs).count == failures.count)
        #expect(WaterLogOutcome.failed.dialog == "Verre non enregistré — réessaie")
    }
}
