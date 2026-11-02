import Foundation

/// A piece of content the learner can bookmark, review or be scheduled on.
/// Learner records reference content by stable ID only, never by object relationship,
/// so content can be re-imported without orphaning progress (PRD FR-S7).
public enum LearningTarget: Hashable, Sendable, Codable {
    case vocabulary(VocabularyID)
    case grammar(GrammarID)
}

public struct Bookmark: Identifiable, Hashable, Sendable, Codable {
    public let id: BookmarkID
    public let target: LearningTarget
    public let createdAt: Date

    public init(id: BookmarkID, target: LearningTarget, createdAt: Date) {
        self.id = id
        self.target = target
        self.createdAt = createdAt
    }
}

/// SM-2 state for one learning target. The algorithm itself lives in Phase 5.
public struct ReviewSchedule: Identifiable, Hashable, Sendable, Codable {
    public let id: ReviewScheduleID
    public let target: LearningTarget
    public var easeFactor: Double
    public var intervalDays: Int
    public var repetitions: Int
    public var nextReviewDate: Date
    public var lastReviewedAt: Date?

    public init(
        id: ReviewScheduleID,
        target: LearningTarget,
        easeFactor: Double = 2.5,
        intervalDays: Int = 0,
        repetitions: Int = 0,
        nextReviewDate: Date,
        lastReviewedAt: Date? = nil
    ) {
        self.id = id
        self.target = target
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.nextReviewDate = nextReviewDate
        self.lastReviewedAt = lastReviewedAt
    }
}

public extension LearningTarget {
    var kind: String {
        switch self {
        case .vocabulary: return "vocabulary"
        case .grammar: return "grammar"
        }
    }

    var contentID: String {
        switch self {
        case let .vocabulary(id): return id.rawValue
        case let .grammar(id): return id.rawValue
        }
    }

    init?(kind: String, contentID: String) {
        switch kind {
        case "vocabulary": self = .vocabulary(VocabularyID(contentID))
        case "grammar": self = .grammar(GrammarID(contentID))
        default: return nil
        }
    }
}
