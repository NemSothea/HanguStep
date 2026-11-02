import SwiftUI

/// 8-point spacing scale. Features never hard-code layout numbers.
public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

public enum Radius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 20
    public static let pill: CGFloat = 999
}

public enum Layout {
    /// Maximum readable width for long Khmer and English explanations on regular widths.
    public static let readableWidth: CGFloat = 720
    public static let minimumTapTarget: CGFloat = 44
    public static let optionRowHeight: CGFloat = 56
}
