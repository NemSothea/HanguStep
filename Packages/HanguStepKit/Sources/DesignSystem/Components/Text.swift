import SwiftUI

/// Hangul hero text. Scales with Dynamic Type relative to Large Title.
public struct HangulText: View {
    public enum Style: Sendable {
        case display
        case title
        case body
    }

    private let text: String
    private let style: Style
    @ScaledMetric(relativeTo: .largeTitle) private var displaySize = Typography.hangulDisplayBaseSize

    public init(_ text: String, style: Style = .title) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(font)
            .minimumScaleFactor(style == .display ? 0.7 : 1)
            .lineLimit(style == .display ? 2 : nil)
            .foregroundStyle(HSColor.textPrimary)
            .accessibilityLabel(Text(AttributedString.korean(text)))
    }

    private var font: Font {
        switch style {
        case .display: return .system(size: displaySize, weight: .semibold)
        case .title: return Typography.hangulTitle
        case .body: return Typography.hangulBody
        }
    }
}

/// A meaning shown in two languages. The caller decides which is primary.
public struct GlossText: View {
    public struct Line: Equatable, Sendable {
        public let text: String
        public let script: Script
        public let languageCode: String

        public init(_ text: String, script: Script, languageCode: String) {
            self.text = text
            self.script = script
            self.languageCode = languageCode
        }

        public static func english(_ text: String) -> Line { Line(text, script: .latin, languageCode: "en") }
        public static func khmer(_ text: String) -> Line { Line(text, script: .khmer, languageCode: "km-KH") }
    }

    private let primary: Line
    private let secondary: Line?

    public init(primary: Line, secondary: Line? = nil) {
        self.primary = primary
        self.secondary = secondary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(primary.text)
                .font(Typography.body.weight(.medium))
                .foregroundStyle(HSColor.textPrimary)
                .scriptSpacing(primary.script)
                .accessibilityLabel(Text(AttributedString.spoken(primary.text, language: primary.languageCode)))
            if let secondary {
                Text(secondary.text)
                    .font(Typography.caption)
                    .foregroundStyle(HSColor.textSecondary)
                    .scriptSpacing(secondary.script)
                    .accessibilityLabel(Text(AttributedString.spoken(secondary.text, language: secondary.languageCode)))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension AttributedString {
    static func korean(_ text: String) -> AttributedString {
        spoken(text, language: "ko-KR")
    }

    /// Tags the text with its language so VoiceOver can pick the matching voice.
    /// Verified against VoiceOver in Phase 9; SwiftUI exposes no dedicated speech-language key.
    static func spoken(_ text: String, language: String) -> AttributedString {
        var string = AttributedString(text)
        string.languageIdentifier = language
        return string
    }
}

#Preview("Text") {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        HangulText("학교", style: .display)
        HangulText("저는 학교에 가요.", style: .body)
        GlossText(primary: .khmer("សាលារៀន"), secondary: .english("school"))
        GlossText(primary: .english("school"), secondary: .khmer("សាលារៀន"))
    }
    .padding()
}
