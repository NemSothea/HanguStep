import SwiftUI

/// Script hints so text gets the vertical metrics it needs.
/// Khmer subscript consonants extend below the baseline and need extra line spacing.
public enum Script: Sendable {
    case hangul
    case latin
    case khmer

    var lineSpacing: CGFloat {
        switch self {
        case .khmer: return 4
        case .hangul, .latin: return 0
        }
    }
}

/// All styles map to Dynamic Type text styles so they scale with the user's setting.
public enum Typography {
    public static let hangulTitle = Font.system(.title2, weight: .semibold)
    public static let hangulBody = Font.system(.body)
    public static let title = Font.system(.title2, weight: .bold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let caption = Font.caption
    public static let statValue = Font.system(.title, design: .rounded, weight: .bold)

    /// Base point size of the Hangul hero style before Dynamic Type scaling.
    /// Applied through `@ScaledMetric(relativeTo: .largeTitle)` in `HangulText`.
    public static let hangulDisplayBaseSize: CGFloat = 44
}

public extension View {
    /// Applies script-appropriate line spacing.
    func scriptSpacing(_ script: Script) -> some View {
        lineSpacing(script.lineSpacing)
    }
}
