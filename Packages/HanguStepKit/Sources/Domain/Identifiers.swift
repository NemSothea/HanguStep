import Foundation

/// Type-safe string identifier. `Tag` is a phantom type so a `VocabularyID`
/// can never be passed where a `GrammarID` is expected.
///
/// Identifiers are strings, not UUIDs, because content identifiers are authored
/// in JSON (for example `"vocab.topik1.0001"`) and must stay stable across
/// content versions and across CloudKit sync.
public struct ID<Tag>: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public var description: String { rawValue }
}

public enum VocabularyTag: Sendable {}
public enum GrammarTag: Sendable {}
public enum QuestionTag: Sendable {}
public enum OptionTag: Sendable {}
public enum AttemptTag: Sendable {}
public enum StudySessionTag: Sendable {}
public enum BookmarkTag: Sendable {}
public enum ReviewScheduleTag: Sendable {}

public typealias VocabularyID = ID<VocabularyTag>
public typealias GrammarID = ID<GrammarTag>
public typealias QuestionID = ID<QuestionTag>
public typealias OptionID = ID<OptionTag>
public typealias AttemptID = ID<AttemptTag>
public typealias StudySessionID = ID<StudySessionTag>
public typealias BookmarkID = ID<BookmarkTag>
public typealias ReviewScheduleID = ID<ReviewScheduleTag>
