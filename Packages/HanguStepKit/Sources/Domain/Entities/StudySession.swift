import Foundation

public enum StudyMode: String, Sendable, Codable, CaseIterable {
    case quiz
    case review
    case mistakes
}

/// A run through a fixed list of questions. The list is frozen at creation so an
/// interrupted session resumes with exactly the same questions (PRD FR-Q6).
public struct StudySession: Identifiable, Hashable, Sendable, Codable {
    public let id: StudySessionID
    public var mode: StudyMode
    public let startedAt: Date
    public var endedAt: Date?
    public let questionIDs: [QuestionID]
    public var currentIndex: Int
    public let deviceName: String

    public init(
        id: StudySessionID,
        mode: StudyMode,
        startedAt: Date,
        endedAt: Date? = nil,
        questionIDs: [QuestionID],
        currentIndex: Int = 0,
        deviceName: String
    ) {
        self.id = id
        self.mode = mode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.questionIDs = questionIDs
        self.currentIndex = currentIndex
        self.deviceName = deviceName
    }

    public var isFinished: Bool { endedAt != nil }
    public var totalQuestions: Int { questionIDs.count }
}
