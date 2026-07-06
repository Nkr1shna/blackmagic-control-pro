import Foundation

protocol CameraControlClient: AnyObject {
    var transport: CameraControlTransport { get }

    func connect() async throws -> CameraState
    func disconnect() async
    func refreshState() async throws -> CameraState

    func setRecording(_ recording: Bool) async throws -> CameraState
    func setISO(_ iso: Int) async throws -> CameraState
    func setShutter(_ shutter: String) async throws -> CameraState
    func setWhiteBalance(kelvin: Int, tint: Int) async throws -> CameraState
    func triggerAutoWhiteBalance() async throws -> CameraState
    func setIris(_ iris: Double) async throws -> CameraState
    func setFocus(_ focus: Double) async throws -> CameraState
    func triggerAutoFocus() async throws -> CameraState
}
