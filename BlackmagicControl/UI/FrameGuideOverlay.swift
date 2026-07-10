import SwiftUI

/// Local monitoring aids drawn over the iPad preview. The camera's own
/// overlay commands only affect its LCD/HDMI outputs — the USB webcam feed
/// is clean — so guides shown on the iPad are rendered here.
struct FrameGuideOverlay: View {
    /// Aspect ratio of the guide (width / height), nil = off.
    var guideRatio: Double?
    var guideOpacity: Double = 0.6
    var safeAreaPercentage: Int = 0
    var showThirds = false
    var showCrosshair = false
    var showCenterDot = false
    /// Aspect ratio of the video feed itself.
    var videoAspect: Double = 16.0 / 9.0

    var body: some View {
        GeometryReader { proxy in
            let videoRect = Self.fittedRect(for: videoAspect, in: proxy.size)

            ZStack {
                if let guideRatio {
                    letterbox(in: videoRect, ratio: guideRatio)
                }

                if safeAreaPercentage > 0 {
                    let scale = Double(safeAreaPercentage) / 100.0
                    Rectangle()
                        .stroke(.white.opacity(0.55), lineWidth: 1)
                        .frame(width: videoRect.width * scale, height: videoRect.height * scale)
                        .position(x: videoRect.midX, y: videoRect.midY)
                }

                if showThirds {
                    thirdsGrid(in: videoRect)
                }

                if showCrosshair {
                    Path { path in
                        path.move(to: CGPoint(x: videoRect.midX - 18, y: videoRect.midY))
                        path.addLine(to: CGPoint(x: videoRect.midX + 18, y: videoRect.midY))
                        path.move(to: CGPoint(x: videoRect.midX, y: videoRect.midY - 18))
                        path.addLine(to: CGPoint(x: videoRect.midX, y: videoRect.midY + 18))
                    }
                    .stroke(.white.opacity(0.75), lineWidth: 1.5)
                }

                if showCenterDot {
                    Circle()
                        .fill(.white.opacity(0.8))
                        .frame(width: 5, height: 5)
                        .position(x: videoRect.midX, y: videoRect.midY)
                }
            }
        }
        .allowsHitTesting(false)
    }

    static func fittedRect(for aspect: Double, in size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0, aspect > 0 else { return .zero }
        let containerAspect = size.width / size.height
        if containerAspect > aspect {
            let width = size.height * aspect
            return CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        } else {
            let height = size.width / aspect
            return CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
        }
    }

    @ViewBuilder
    private func letterbox(in rect: CGRect, ratio: Double) -> some View {
        let guideAspect = ratio
        let videoAspect = rect.width / rect.height

        if guideAspect >= videoAspect {
            // Guide is wider than the feed: horizontal mattes.
            let guideHeight = rect.width / guideAspect
            let matteHeight = (rect.height - guideHeight) / 2
            Group {
                Rectangle()
                    .fill(.black.opacity(guideOpacity))
                    .frame(width: rect.width, height: matteHeight)
                    .position(x: rect.midX, y: rect.minY + matteHeight / 2)
                Rectangle()
                    .fill(.black.opacity(guideOpacity))
                    .frame(width: rect.width, height: matteHeight)
                    .position(x: rect.midX, y: rect.maxY - matteHeight / 2)
            }
        } else {
            // Guide is narrower (e.g. 4:5, 1:1): vertical mattes.
            let guideWidth = rect.height * guideAspect
            let matteWidth = (rect.width - guideWidth) / 2
            Group {
                Rectangle()
                    .fill(.black.opacity(guideOpacity))
                    .frame(width: matteWidth, height: rect.height)
                    .position(x: rect.minX + matteWidth / 2, y: rect.midY)
                Rectangle()
                    .fill(.black.opacity(guideOpacity))
                    .frame(width: matteWidth, height: rect.height)
                    .position(x: rect.maxX - matteWidth / 2, y: rect.midY)
            }
        }
    }

    private func thirdsGrid(in rect: CGRect) -> some View {
        Path { path in
            for fraction in [1.0 / 3.0, 2.0 / 3.0] {
                let x = rect.minX + rect.width * fraction
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))

                let y = rect.minY + rect.height * fraction
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
        .stroke(.white.opacity(0.45), lineWidth: 1)
    }
}
