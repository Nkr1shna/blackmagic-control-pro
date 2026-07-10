import Foundation

struct DiagnosticsSnapshot {
    var blePhase: String
    var recentErrors: [String]
    var cameraModel: String?
    var ccuProtocolVersion: String?
    var feedFormat: String?

    static let empty = DiagnosticsSnapshot(
        blePhase: "",
        recentErrors: [],
        cameraModel: nil,
        ccuProtocolVersion: nil,
        feedFormat: nil
    )
}
