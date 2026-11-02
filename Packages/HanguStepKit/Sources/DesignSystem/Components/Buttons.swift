import SwiftUI

public struct HSButtonStyle: ButtonStyle {
    public enum Variant: Sendable {
        case primary
        case secondary
        case destructive
    }

    private let variant: Variant
    @Environment(\.isEnabled) private var isEnabled

    public init(_ variant: Variant) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: Layout.minimumTapTarget + 4)
            .padding(.horizontal, Spacing.md)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                if variant == .secondary {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(HSColor.accent, lineWidth: 1.5)
                }
            }
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch variant {
        case .primary, .destructive: return .white
        case .secondary: return HSColor.accent
        }
    }

    private var background: Color {
        switch variant {
        case .primary: return HSColor.accent
        case .destructive: return HSColor.danger
        case .secondary: return .clear
        }
    }
}

/// Full-width action button with optional icon and loading state.
public struct HSButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let variant: HSButtonStyle.Variant
    private let isLoading: Bool
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        variant: HSButtonStyle.Variant = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(variant == .secondary ? HSColor.accent : .white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(HSButtonStyle(variant))
        .disabled(isLoading)
        .accessibilityHint(isLoading ? "In progress" : "")
    }
}

#Preview("Buttons") {
    VStack(spacing: Spacing.md) {
        HSButton("Start review", systemImage: "play.fill") {}
        HSButton("Quick quiz", systemImage: "bolt.fill", variant: .secondary) {}
        HSButton("Reset local data", variant: .destructive) {}
        HSButton("Saving", isLoading: true) {}
        HSButton("Disabled") {}.disabled(true)
    }
    .padding()
}
