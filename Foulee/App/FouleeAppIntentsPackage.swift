import AppIntents
import FouleeIntents

/// The intents this process runs from FouleeIntents (#724), registered under
/// the identifiers they had when the app compiled them itself.
struct FouleeAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [FouleeIntentsPackage.self] }
}
