import SwiftUI
import UIKit

struct ControlPanelView: View {
    @ObservedObject var store: CameraStateStore

    @State private var isoText = ""
    @State private var shutterText = ""
    @State private var whiteBalanceText = ""
    @State private var tintText = ""
    @State private var focusValue = 0.0
    @State private var irisValue = 0.0
    @State private var isAdjustingFocus = false
    @State private var isAdjustingIris = false

    private var isRecording: Bool {
        store.state.isRecording.value ?? false
    }

    private var canRecord: Bool {
        store.state.isRecording.isAvailable
    }

    private var canSetISO: Bool {
        store.state.iso.isAvailable
    }

    private var canSetShutter: Bool {
        store.state.shutter.isAvailable
    }

    private var canSetWhiteBalance: Bool {
        store.state.whiteBalance.isAvailable && store.state.tint.isAvailable
    }

    private var canSetFocus: Bool {
        store.state.focus.isAvailable
    }

    private var canTriggerAutoFocus: Bool {
        store.state.canAutoFocus.value == true
    }

    private var canSetIris: Bool {
        store.state.iris.isAvailable
    }

    private var canTriggerAutoWhiteBalance: Bool {
        store.state.whiteBalance.isAvailable || store.state.tint.isAvailable
    }

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    recordButton

                    ControlCluster(title: "Exposure") {
                        HStack(spacing: 8) {
                            CompactField(
                                title: "ISO",
                                text: $isoText,
                                width: 76,
                                placeholder: "800",
                                keyboardType: .numberPad,
                                isEnabled: canSetISO,
                                onSubmit: submitISO
                            )

                            IconCommandButton(
                                title: "Set ISO",
                                systemImage: "checkmark",
                                isEnabled: canSetISO,
                                action: submitISO
                            )

                            CompactField(
                                title: "Shutter",
                                text: $shutterText,
                                width: 84,
                                placeholder: "180",
                                keyboardType: .numbersAndPunctuation,
                                isEnabled: canSetShutter,
                                onSubmit: submitShutter
                            )

                            IconCommandButton(
                                title: "Set shutter",
                                systemImage: "checkmark",
                                isEnabled: canSetShutter,
                                action: submitShutter
                            )
                        }
                    }

                    ControlCluster(title: "Color") {
                        HStack(spacing: 8) {
                            CompactField(
                                title: "WB",
                                text: $whiteBalanceText,
                                width: 82,
                                placeholder: "5600",
                                keyboardType: .numberPad,
                                isEnabled: store.state.whiteBalance.isAvailable,
                                onSubmit: submitWhiteBalance
                            )

                            CompactField(
                                title: "Tint",
                                text: $tintText,
                                width: 66,
                                placeholder: "0",
                                keyboardType: .numbersAndPunctuation,
                                isEnabled: store.state.tint.isAvailable,
                                onSubmit: submitWhiteBalance
                            )

                            IconCommandButton(
                                title: "Set white balance",
                                systemImage: "checkmark",
                                isEnabled: canSetWhiteBalance,
                                action: submitWhiteBalance
                            )

                            IconCommandButton(
                                title: "Auto white balance",
                                systemImage: "wand.and.stars",
                                isEnabled: canTriggerAutoWhiteBalance,
                                action: triggerAutoWhiteBalance
                            )
                        }
                    }

                    ControlCluster(title: "Lens") {
                        VStack(spacing: 8) {
                            LensSliderRow(
                                title: "Focus",
                                value: $focusValue,
                                symbol: "scope",
                                isAdjusting: $isAdjustingFocus,
                                isEnabled: canSetFocus,
                                onCommit: submitFocus
                            ) {
                                IconCommandButton(
                                    title: "Auto focus",
                                    systemImage: "viewfinder",
                                    isEnabled: canTriggerAutoFocus,
                                    action: triggerAutoFocus
                                )
                            }

                            LensSliderRow(
                                title: "Iris",
                                value: $irisValue,
                                symbol: "camera.aperture",
                                isAdjusting: $isAdjustingIris,
                                isEnabled: canSetIris,
                                onCommit: submitIris
                            ) {
                                EmptyView()
                            }
                        }
                        .frame(minWidth: 270)
                    }
                }
            }

            if let error = store.state.errors.last {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    Text("\(error.subsystem): \(error.message)")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(10)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .disabled(store.isBusy)
        .opacity(store.isBusy ? 0.74 : 1)
        .onAppear(perform: syncFieldsFromState)
        .onChange(of: store.state) { _, _ in
            syncFieldsFromState()
        }
    }

    private var recordButton: some View {
        Button {
            guard canRecord else {
                return
            }

            Task {
                await store.setRecording(!isRecording)
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isRecording ? .white : .red)

                Text(isRecording ? "STOP" : "REC")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
            }
            .frame(width: 72, height: 70)
            .background(isRecording ? Color.red : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isRecording ? .red.opacity(0.9) : .red.opacity(0.55), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canRecord)
        .opacity(canRecord ? 1 : 0.44)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }

    private func syncFieldsFromState() {
        let state = store.state

        isoText = availableText(state.iso)
        shutterText = state.shutter.isAvailable ? state.shutter.value ?? "" : ""
        whiteBalanceText = availableText(state.whiteBalance)
        tintText = availableText(state.tint)

        if !isAdjustingFocus {
            if state.focus.isAvailable, let value = state.focus.value {
                focusValue = clamped(value)
            } else {
                focusValue = 0
            }
        }

        if !isAdjustingIris {
            if state.iris.isAvailable, let value = state.iris.value {
                irisValue = clamped(value)
            } else {
                irisValue = 0
            }
        }
    }

    private func submitISO() {
        guard
            canSetISO,
            let iso = Int(isoText.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return
        }

        Task {
            await store.setISO(iso)
        }
    }

    private func submitShutter() {
        guard
            canSetShutter,
            let shutter = normalizedShutterAngleText(shutterText)
        else {
            return
        }

        Task {
            await store.setShutter(shutter)
        }
    }

    private func submitWhiteBalance() {
        guard
            canSetWhiteBalance,
            let kelvin = Int(whiteBalanceText.trimmingCharacters(in: .whitespacesAndNewlines)),
            let tint = Int(tintText.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return
        }

        Task {
            await store.setWhiteBalance(kelvin: kelvin, tint: tint)
        }
    }

    private func triggerAutoWhiteBalance() {
        guard canTriggerAutoWhiteBalance else {
            return
        }

        Task {
            await store.triggerAutoWhiteBalance()
        }
    }

    private func submitFocus() {
        guard canSetFocus else {
            return
        }

        Task {
            await store.setFocus(focusValue)
        }
    }

    private func triggerAutoFocus() {
        guard canTriggerAutoFocus else {
            return
        }

        Task {
            await store.triggerAutoFocus()
        }
    }

    private func submitIris() {
        guard canSetIris else {
            return
        }

        Task {
            await store.setIris(irisValue)
        }
    }

    private func availableText<T: Equatable>(_ value: CameraValue<T>) -> String {
        guard value.isAvailable, let currentValue = value.value else {
            return ""
        }

        return "\(currentValue)"
    }

    private func normalizedShutterAngleText(_ shutter: String) -> String? {
        let normalized = shutter
            .replacingOccurrences(of: "degrees", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "degree", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "deg", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "°", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let angle = Double(normalized), angle.isFinite else {
            return nil
        }

        return normalized
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

private struct ControlCluster<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.white.opacity(0.58))

            content
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: 70, alignment: .topLeading)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct CompactField: View {
    let title: String
    @Binding var text: String
    let width: CGFloat
    let placeholder: String
    let keyboardType: UIKeyboardType
    let isEnabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.54))

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(isEnabled ? .white : .white.opacity(0.45))
                .multilineTextAlignment(.center)
                .frame(width: width, height: 34)
                .background(.black.opacity(isEnabled ? 0.55 : 0.34), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white.opacity(isEnabled ? 0.16 : 0.08), lineWidth: 1)
                )
                .disabled(!isEnabled)
        }
    }
}

private struct IconCommandButton: View {
    let title: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(isEnabled ? 0.11 : 0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white.opacity(isEnabled ? 0.16 : 0.07), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.48)
        .accessibilityLabel(title)
    }
}

private struct LensSliderRow<Trailing: View>: View {
    let title: String
    @Binding var value: Double
    let symbol: String
    @Binding var isAdjusting: Bool
    let isEnabled: Bool
    let onCommit: () -> Void
    let trailing: Trailing

    init(
        title: String,
        value: Binding<Double>,
        symbol: String,
        isAdjusting: Binding<Bool>,
        isEnabled: Bool,
        onCommit: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self._value = value
        self.symbol = symbol
        self._isAdjusting = isAdjusting
        self.isEnabled = isEnabled
        self.onCommit = onCommit
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 18)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 42, alignment: .leading)

            Slider(
                value: $value,
                in: 0...1,
                onEditingChanged: { editing in
                    isAdjusting = editing
                    if !editing, isEnabled {
                        onCommit()
                    }
                }
            )
            .frame(width: 150)
            .tint(.white)
            .disabled(!isEnabled)

            Text(isEnabled ? value.formatted(.number.precision(.fractionLength(2))) : "--")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 34, alignment: .trailing)

            trailing
        }
        .frame(height: 34)
    }
}
