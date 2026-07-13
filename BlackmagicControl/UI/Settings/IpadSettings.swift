import SwiftUI

// MARK: - iPad (local recording)

struct IpadSettings: View {
    @ObservedObject var previewModel: ExternalCameraPreviewModel
    @State private var showFolderPicker = false

    var body: some View {
        HUDSection(title: "Video Feed") {
            HUDInfoRow(
                title: "Incoming Feed",
                value: previewModel.feedDescription ?? "No feed",
                multiline: true
            )
            HUDInfoRow(title: "Status", value: previewModel.status, multiline: true)
        }

        HUDSection(title: "Record to iPad") {
            HUDInfoRow(
                title: "Destination",
                value: previewModel.externalDestinationName ?? "On My iPad → Blackmagic Control Pro → Recordings",
                multiline: true
            )

            HStack(spacing: 10) {
                Button {
                    showFolderPicker = true
                } label: {
                    Label("Choose Folder / Drive", systemImage: "folder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HUD.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                if previewModel.externalDestinationName != nil {
                    Button {
                        previewModel.clearExternalDestination()
                    } label: {
                        Text("Reset")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HUD.value)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(HUD.tileHighlight, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let message = previewModel.localRecordingMessage {
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(HUD.accent)
            }
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                previewModel.setExternalDestination(url)
            }
        }
    }

}

