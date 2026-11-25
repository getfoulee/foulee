import FouleeKit
import Foundation
@preconcurrency import WatchConnectivity

/// Sends a finished trace to the iPhone (#727), as a file WatchConnectivity
/// delivers in the background, even if the phone app is not running.
nonisolated enum DetectionTraceTransfer {
    static func send(_ trace: DetectionTrace) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else {
            FouleeLog.session.error("trace non envoyée : pas de liaison avec l'iPhone")
            return
        }
        // Outside the temporary directory, which the system may empty before
        // the transfer is done; `WatchSyncReceiver` removes it once delivered.
        let folder = URL.cachesDirectory.appending(path: "DetectionTraces")
        let url = folder.appending(path: trace.fileName)
        guard (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil,
              let data = try? DetectionTrace.encoder().encode(trace),
              (try? data.write(to: url, options: .atomic)) != nil
        else {
            FouleeLog.session.error("trace non écrite")
            return
        }
        WCSession.default.transferFile(url, metadata: DetectionTrace.transferMetadata)
    }
}
