import Foundation

/// What the wrist can ask of the phone's session (issue #342).
nonisolated public enum PhoneSessionCommand: String, Codable, Sendable {
    case pause
    case resume
    case stop
}

/// The WatchConnectivity keys of the phone's session (issue #342). One
/// spelling, read by both apps.
nonisolated public enum PhoneSessionKey {
    /// Application context and live message: the latest `SessionSnapshot`.
    /// Absent from the context when there is no session.
    public static let snapshot = "phoneSession"
    /// Message from the wrist: a `PhoneSessionCommand`.
    public static let command = "phoneSessionCommand"
    /// Reply to a command: whether the phone carried it out.
    public static let done = "done"
}
