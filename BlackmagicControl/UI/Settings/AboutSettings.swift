import MessageUI
import SwiftUI

// MARK: - About

struct AboutSettings: View {
    @ObservedObject var controller: CameraBleController
    @ObservedObject var previewModel: ExternalCameraPreviewModel
    @ObservedObject var diagnosticsHub: DiagnosticsHub

    @State private var isExporting = false
    @State private var diagnosticsURL: URL?
    @State private var exportError: String?
    @State private var isPresentingMail = false
    @State private var mailAttachmentData: Data?
    @State private var mailAttachmentFileName = ""

    private let legalDisclaimer = "Blackmagic Control Pro is an independent app. It is not affiliated with, endorsed by, sponsored by, or supported by Blackmagic Design Pty Ltd. “Blackmagic” and “Blackmagic Design” are trademarks of Blackmagic Design Pty Ltd, referenced only to describe camera compatibility. This app stores recordings and settings only on this iPad and sends no data anywhere. Alpha software — expect bugs; use at your own risk."

    var body: some View {
        HUDSection(title: "App") {
            HUDInfoRow(
                title: "Version",
                value: bundleValue(for: "CFBundleShortVersionString"),
                multiline: true
            )
            HUDInfoRow(title: "Build", value: buildDescription, multiline: true)
            channelRow
        }

        HUDSection(title: "Support") {
            HUDInfoRow(title: "Contact", value: "krishnanelloore@gmail.com", multiline: true)

            Text("Found a bug? Tap below — an email opens with the diagnostics attached. Just hit Send. (No Mail app? Use Share instead.)")
                .font(.system(size: 12))
                .foregroundStyle(HUD.label)

            HStack(spacing: 10) {
                Button(action: exportDiagnostics) {
                    Label("Send Diagnostics", systemImage: "paperplane")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HUD.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isExporting)

                if isExporting {
                    ProgressView()
                        .tint(HUD.accent)
                }

                if let diagnosticsURL {
                    ShareLink(item: diagnosticsURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HUD.value)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let exportError {
                Text(exportError)
                    .font(.system(size: 11))
                    .foregroundStyle(HUD.record)
            }
        }

        HUDSection(title: "Legal") {
            Text(legalDisclaimer)
                .font(.system(size: 11))
                .foregroundStyle(HUD.label)
                .fixedSize(horizontal: false, vertical: true)
        }

        HUDSection(title: "Compatibility") {
            HUDInfoRow(
                title: "Camera",
                value: "Blackmagic Pocket Cinema Camera 4K / 6K. Other models may work but are untested.",
                multiline: true
            )
        }
        .sheet(isPresented: $isPresentingMail) {
            if let mailAttachmentData {
                MailComposeView(
                    recipients: ["krishnanelloore@gmail.com"],
                    subject: mailSubject,
                    body: "Please describe what happened right before the problem:\n\n",
                    attachment: mailAttachmentData,
                    mimeType: "application/zip",
                    fileName: mailAttachmentFileName,
                    dismiss: { isPresentingMail = false }
                )
            }
        }
    }

    private var mailSubject: String {
        let version = bundleValue(for: "CFBundleShortVersionString")
        let build = bundleValue(for: "CFBundleVersion")
        return "Blackmagic Control Pro diagnostics — v\(version) (\(build))"
    }

    private var buildDescription: String {
        let build = bundleValue(for: "CFBundleVersion")
        guard let sha = Bundle.main.object(forInfoDictionaryKey: "KNBuildSHA") as? String,
              !sha.isEmpty else {
            return build
        }
        return "\(build) (\(sha))"
    }

    private func bundleValue(for key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "—"
    }

    private func exportDiagnostics() {
        isExporting = true
        diagnosticsURL = nil
        exportError = nil

        Task { @MainActor in
            await Task.yield()

            let snapshot = DiagnosticsSnapshot(
                blePhase: controller.phase.label,
                recentErrors: controller.errorHistory.map {
                    "\($0.date.formatted(.iso8601)) \($0.message)"
                },
                cameraModel: controller.camera.modelName,
                ccuProtocolVersion: controller.camera.protocolVersion,
                feedFormat: previewModel.feedDescription
            )

            do {
                let url = try diagnosticsHub.exportDiagnostics(snapshot: snapshot)
                diagnosticsURL = url

                if MFMailComposeViewController.canSendMail(),
                   let data = try? Data(contentsOf: url) {
                    mailAttachmentData = data
                    mailAttachmentFileName = url.lastPathComponent
                    isPresentingMail = true
                }
            } catch {
                exportError = error.localizedDescription
            }
            isExporting = false
        }
    }

    private var channelRow: some View {
        HStack {
            Text("CHANNEL")
                .font(HUD.labelFont())
                .foregroundStyle(HUD.label)
                .tracking(1)

            Spacer()

            Text("Alpha")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(HUD.accent, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

