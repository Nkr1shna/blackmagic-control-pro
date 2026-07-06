import Foundation
import SwiftUI

struct StatusStripView: View {
    @ObservedObject var store: CameraStateStore
    @ObservedObject var previewModel: ExternalCameraPreviewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                StatusPill(
                    icon: previewModel.errorMessage == nil ? "video.fill" : "video.slash.fill",
                    title: "Preview",
                    value: previewModel.status,
                    tint: previewModel.errorMessage == nil ? .green : .orange
                )

                StatusPill(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "Connection",
                    value: store.state.connectionStatus,
                    tint: connectionTint
                )

                StatusPill(
                    icon: "point.3.connected.trianglepath.dotted",
                    title: "Transport",
                    value: transportLabel,
                    tint: transportTint
                )

                if let timecode = store.state.timecode.value {
                    StatusPill(
                        icon: "timer",
                        title: "TC",
                        value: timecode,
                        tint: .white
                    )
                }

                if let percent = store.state.battery.value?.percent {
                    StatusPill(
                        icon: "battery.75percent",
                        title: "Battery",
                        value: "\(percent)%",
                        tint: batteryTint(percent)
                    )
                }

                if let seconds = remainingRecordTimeSeconds {
                    StatusPill(
                        icon: "recordingtape",
                        title: "Media",
                        value: formattedRecordTime(seconds),
                        tint: .cyan
                    )
                }
            }
            .padding(8)
        }
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private var transportLabel: String {
        switch store.state.controlTransport {
        case .disconnected:
            return "None"
        case .rest:
            return "REST"
        case .ble:
            return "BLE"
        case .degraded:
            return "Degraded"
        }
    }

    private var connectionTint: Color {
        store.state.controlTransport == .disconnected ? .orange : .green
    }

    private var transportTint: Color {
        switch store.state.controlTransport {
        case .disconnected:
            return .orange
        case .rest:
            return .green
        case .ble:
            return .blue
        case .degraded:
            return .yellow
        }
    }

    private var remainingRecordTimeSeconds: Int? {
        if let seconds = store.state.remainingRecordTime.value {
            return seconds
        }

        return store.state.mediaSlots.value?
            .first(where: \.isActive)?
            .remainingRecordTimeSeconds
    }

    private func batteryTint(_ percent: Int) -> Color {
        switch percent {
        case ..<15:
            return .red
        case ..<35:
            return .yellow
        default:
            return .green
        }
    }

    private func formattedRecordTime(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let seconds = seconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct StatusPill: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16, height: 16)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.56))

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(minHeight: 28)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
