import SwiftUI

/// Semantic colors. Brand colors come from the asset catalog with light and dark
/// variants; neutrals come from the system so they follow Increase Contrast.
public enum HSColor {
    public static let accent = Color("accent", bundle: .module)
    public static let accentSoft = Color("accentSoft", bundle: .module)
    public static let success = Color("success", bundle: .module)
    public static let danger = Color("danger", bundle: .module)
    public static let warning = Color("warning", bundle: .module)

    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary

    #if canImport(UIKit)
    public static let background = Color(uiColor: .systemGroupedBackground)
    public static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    public static let surfaceElevated = Color(uiColor: .tertiarySystemGroupedBackground)
    public static let separator = Color(uiColor: .separator)
    #else
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let surface = Color(nsColor: .controlBackgroundColor)
    public static let surfaceElevated = Color(nsColor: .textBackgroundColor)
    public static let separator = Color(nsColor: .separatorColor)
    #endif

    /// TOPIK level tint, 1 to 6. Out-of-range values clamp.
    public static func level(_ level: Int) -> Color {
        Color("level\(min(max(level, 1), 6))", bundle: .module)
    }
}
