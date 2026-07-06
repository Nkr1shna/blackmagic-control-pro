import CoreBluetooth

enum BlackmagicBleConstants {
    static let deviceInformationService = CBUUID(string: "180A")
    static let manufacturerCharacteristic = CBUUID(string: "2A29")
    static let modelCharacteristic = CBUUID(string: "2A24")

    static let cameraService = CBUUID(string: "291D567A-6D75-11E6-8B77-86F30CA893D3")
    static let outgoingCameraControl = CBUUID(string: "5DD3465F-1AEE-4299-8493-D2ECA2F8E1BB")
    static let incomingCameraControl = CBUUID(string: "B864E140-76A0-416A-BF30-5876504537D9")
    static let timecode = CBUUID(string: "6D8F2110-86F1-41BF-9AFB-451D87E976C8")
    static let cameraStatus = CBUUID(string: "7FE8691D-95DC-4FC5-8ABD-CA74339B51B9")
    static let deviceName = CBUUID(string: "FFAC0C52-C9FB-41A0-B063-CC76282EB89C")
    static let protocolVersion = CBUUID(string: "8F1FD018-B508-456F-8F82-3D392BEE2706")
}
