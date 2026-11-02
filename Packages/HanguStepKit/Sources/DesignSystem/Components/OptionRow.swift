import SwiftUI

public enum OptionState: Equatable, Sendable {
    case idle
    case selected
    case correct
    case incorrect
    case dimmed
}

/// TOPIK-style circled numbers ① to ④ for option labels.
public enum CircledNumber {
    public static func label(for index: Int) -> String {
        guard (0..<20).contains(index), let scalar = UnicodeScalar(0x2460 + index) else {
            return "\(index + 1)"
        }
        return String(Character(scalar))
    }
}

public struct OptionRow: View {
    private let index: Int
    private let text: String
    private let state: OptionState
    private let action: () -> Void

    public init(index: Int, text: String, state: OptionState, action: @escaping () -> Void) {
        self.index = index
        self.text = text
        self.state = state
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Text(CircledNumber.label(for: index))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                Text(text)
                    .font(Typography.hangulTitle)
                    .foregroundStyle(HSColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let statusSymbol {
                    Image(systemName: statusSymbol)
                        .font(.title3)
                        .foregroundStyle(tint)
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: Layout.optionRowHeight)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: state == .idle ? 1 : 2)
            }
            .opacity(state == .dimmed ? 0.5 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(state == .correct || state == .incorrect || state == .dimmed)
        .animation(.spring(duration: 0.3), value: state)
        .accessibilityLabel("Option \(index + 1), \(text)")
        .accessibilityValue(accessibilityValue)
    }

    private var tint: Color {
        switch state {
        case .idle, .dimmed: return HSColor.textSecondary
        case .selected: return HSColor.accent
        case .correct: return HSColor.success
        case .incorrect: return HSColor.danger
        }
    }

    private var borderColor: Color {
        state == .idle || state == .dimmed ? HSColor.separator : tint
    }

    private var background: Color {
        switch state {
        case .selected: return HSColor.accentSoft
        case .correct: return HSColor.success.opacity(0.12)
        case .incorrect: return HSColor.danger.opacity(0.12)
        case .idle, .dimmed: return HSColor.surface
        }
    }

    private var statusSymbol: String? {
        switch state {
        case .correct: return "checkmark.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        case .selected: return "circle.inset.filled"
        case .idle, .dimmed: return nil
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .idle, .dimmed: return ""
        case .selected: return "Selected"
        case .correct: return "Correct"
        case .incorrect: return "Incorrect"
        }
    }
}

#Preview("Options") {
    VStack(spacing: Spacing.sm) {
        OptionRow(index: 0, text: "school / សាលារៀន", state: .idle) {}
        OptionRow(index: 1, text: "friend / មិត្តភក្តិ", state: .selected) {}
        OptionRow(index: 2, text: "water / ទឹក", state: .correct) {}
        OptionRow(index: 3, text: "book / សៀវភៅ", state: .incorrect) {}
        OptionRow(index: 4, text: "dimmed", state: .dimmed) {}
    }
    .padding()
    .background(HSColor.background)
}
