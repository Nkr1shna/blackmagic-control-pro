import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.configure(session: session)
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.configure(session: session)
    }
}

final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func configure(session: AVCaptureSession) {
        videoPreviewLayer.videoGravity = .resizeAspect
        videoPreviewLayer.session = session
        updatePreviewConnection()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updatePreviewConnection()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePreviewConnection()
    }

    func updatePreviewConnection() {
        guard let connection = videoPreviewLayer.connection else {
            return
        }

        let orientation = window?.windowScene?.interfaceOrientation ?? .landscapeRight
        let rotationAngle = Self.previewRotationAngle(for: orientation)
        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }

        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = Self.isPreviewMirroringEnabled
        }
    }

    static let isPreviewMirroringEnabled = false

    static func previewRotationAngle(for orientation: UIInterfaceOrientation) -> CGFloat {
        switch orientation {
        case .landscapeLeft:
            return 180
        default:
            return 0
        }
    }
}
