import Foundation

/// Per-learner preferences (PRD FR-X1). One row, synced across devices.
public struct LearnerSettings: Hashable, Sendable, Codable {
    public var glossLanguage: GlossLanguage
    public var dailyGoal: Int
    public var reviewLimit: Int
    public var pronunciationEnabled: Bool
    public var modifiedAt: Date

    public init(
        glossLanguage: GlossLanguage = .english,
        dailyGoal: Int = 20,
        reviewLimit: Int = 50,
        pronunciationEnabled: Bool = true,
        modifiedAt: Date = .distantPast
    ) {
        self.glossLanguage = glossLanguage
        self.dailyGoal = dailyGoal
        self.reviewLimit = reviewLimit
        self.pronunciationEnabled = pronunciationEnabled
        self.modifiedAt = modifiedAt
    }

    public static let `default` = LearnerSettings()
}
