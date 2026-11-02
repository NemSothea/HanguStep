import Foundation

/// One answer to one question inside one study session. Append-only: attempts
/// are never edited or deleted, and all statistics are derived from them (PRD FR-P6).
public struct Attempt: Identifiable, Hashable, Sendable, Codable {
    public let id: AttemptID
    public let sessionID: StudySessionID
    public let questionID: QuestionID
    public let selectedOptionID: OptionID
    public let isCorrect: Bool
    public let answeredAt: Date
    public let responseTime: TimeInterval

    public init(
        id: AttemptID,
        sessionID: StudySessionID,
        questionID: QuestionID,
        selectedOptionID: OptionID,
        isCorrect: Bool,
        answeredAt: Date,
        responseTime: TimeInterval
    ) {
        self.id = id
        self.sessionID = sessionID
        self.questionID = questionID
        self.selectedOptionID = selectedOptionID
        self.isCorrect = isCorrect
        self.answeredAt = answeredAt
        self.responseTime = responseTime
    }
}

/// Aggregate over attempts. Computed, never stored.
public struct AttemptSummary: Hashable, Sendable {
    public let total: Int
    public let correct: Int

    public init(total: Int, correct: Int) {
        self.total = total
        self.correct = correct
    }

    public var incorrect: Int { total - correct }

    /// 0...1. Zero when there are no attempts.
    public var accuracy: Double {
        total == 0 ? 0 : Double(correct) / Double(total)
    }
}
