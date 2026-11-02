import SwiftUI

/// Top-level destinations. Tabs on compact iPhone, sidebar on iPad and Mac.
public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case home, learn, quiz, review, progress

    public var id: String { rawValue }

    public var title: LocalizedStringKey {
        switch self {
        case .home: return "Home"
        case .learn: return "Learn"
        case .quiz: return "Quiz"
        case .review: return "Review"
        case .progress: return "Progress"
        }
    }

    public var systemImage: String {
        switch self {
        case .home: return "house"
        case .learn: return "book"
        case .quiz: return "checkmark.circle"
        case .review: return "arrow.counterclockwise"
        case .progress: return "chart.bar"
        }
    }
}
