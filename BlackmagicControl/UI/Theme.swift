import SwiftUI

/// Visual language for the monitor HUD: near-black strips, thin dividers,
/// grey uppercase micro-labels over large light numerals, orange accent for
/// active/selected controls and red for record.
enum HUD {
    static let barBackground = Color(white: 0.06).opacity(0.92)
    static let panelBackground = Color(white: 0.09)
    static let tileHighlight = Color.white.opacity(0.06)
    static let divider = Color.white.opacity(0.12)
    static let label = Color.white.opacity(0.55)
    static let value = Color.white.opacity(0.94)
    static let dimValue = Color.white.opacity(0.35)
    static let accent = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let record = Color(red: 0.96, green: 0.16, blue: 0.12)
    static let ok = Color(red: 0.24, green: 0.86, blue: 0.43)

    static func labelFont(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func valueFont(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .regular).monospacedDigit()
    }
}

// MARK: - Top bar parameter tile

struct HUDParameterTile: View {
    let label: String
    let value: String
    var isSelected = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label.uppercased())
                    .font(HUD.labelFont())
                    .foregroundStyle(isSelected ? HUD.accent : HUD.label)
                    .tracking(1.2)

                Text(value)
                    .font(HUD.valueFont(23))
                    .foregroundStyle(isEnabled ? HUD.value : HUD.dimValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(minWidth: 74)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? HUD.accent.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isSelected ? HUD.accent.opacity(0.7) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

// MARK: - Icon toggle used in the bottom bar

struct HUDToolButton: View {
    let title: String
    let systemImage: String
    var isActive = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.6)
            }
            .foregroundStyle(isActive ? HUD.accent : (isEnabled ? HUD.value : HUD.dimValue))
            .frame(width: 56, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? HUD.accent.opacity(0.14) : HUD.tileHighlight)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

// MARK: - Preset chip

struct HUDPresetChip: View {
    let label: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .foregroundStyle(isSelected ? .black : HUD.value)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? HUD.accent : HUD.tileHighlight)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Labeled slider row (settings + panels)

struct HUDSliderRow: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var display: ((Double) -> String)?
    var onCommit: (Double) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title.uppercased())
                .font(HUD.labelFont())
                .foregroundStyle(HUD.label)
                .tracking(1)
                .frame(width: 92, alignment: .leading)

            Slider(value: $value, in: range) { editing in
                if !editing {
                    onCommit(value)
                }
            }
            .tint(HUD.accent)

            Text(display?(value) ?? value.formatted(.number.precision(.fractionLength(2))))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(HUD.value)
                .frame(width: 56, alignment: .trailing)
        }
    }
}

// MARK: - Settings list helpers

struct HUDSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(HUD.labelFont(11))
                .foregroundStyle(HUD.accent)
                .tracking(1.6)

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HUD.panelBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct HUDSegmentedRow<Value: Hashable>: View {
    let title: String
    let options: [(value: Value, label: String)]
    let selection: Value?
    let onSelect: (Value) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(HUD.labelFont())
                .foregroundStyle(HUD.label)
                .tracking(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                        HUDPresetChip(
                            label: option.label,
                            isSelected: selection == option.value
                        ) {
                            onSelect(option.value)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Error toast

struct HUDToast: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(HUD.accent)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HUD.value)
                .lineLimit(2)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(HUD.label)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(HUD.barBackground, in: Capsule())
        .overlay(Capsule().stroke(HUD.divider, lineWidth: 1))
    }
}
