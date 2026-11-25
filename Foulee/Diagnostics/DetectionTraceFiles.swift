import FouleeDomain
import Foundation

/// The traces the watch sent (#727), kept on this iPhone until shared. Each is
/// one file in Application Support, named by when its outing began.
nonisolated enum DetectionTraceFiles {
    static let folder = URL.applicationSupportDirectory.appending(path: "DetectionTraces")

    /// Moves a received file in. Synchronous on purpose: WatchConnectivity
    /// deletes the file once its callback returns.
    static func keep(_ received: URL) {
        let destination = folder.appending(path: received.lastPathComponent)
        let manager = FileManager.default
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        try? manager.removeItem(at: destination)
        guard (try? manager.moveItem(at: received, to: destination)) != nil else {
            FouleeLog.session.error("trace reçue mais non gardée")
            return
        }
        FouleeLog.session.notice("trace reçue : \(destination.lastPathComponent, privacy: .public)")
    }

    /// The traces kept, newest first: their names begin with their date.
    static func all() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        return names.filter { $0.hasSuffix(".json") }.sorted(by: >).map { folder.appending(path: $0) }
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: folder)
    }
}
