import Foundation

/// Free-text note on a word or pattern. Independent of bookmarks (PRD US-06).
public struct LearnerNote: Identifiable, Hashable, Sendable, Codable {
    public let id: LearnerNoteID
    public let target: LearningTarget
    public var text: String
    public var modifiedAt: Date

    public init(id: LearnerNoteID, target: LearningTarget, text: String, modifiedAt: Date) {
        self.id = id
        self.target = target
        self.text = text
        self.modifiedAt = modifiedAt
    }
}

public enum LearnerNoteTag: Sendable {}
public typealias LearnerNoteID = ID<LearnerNoteTag>
