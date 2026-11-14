import Foundation

public protocol BrowseGrammarUseCase: Sendable {
    func execute(level: TOPIKLevel?) async throws -> [GrammarPattern]
}

public struct BrowseGrammar: BrowseGrammarUseCase {
    private let grammar: any GrammarRepository

    public init(grammar: any GrammarRepository) {
        self.grammar = grammar
    }

    public func execute(level: TOPIKLevel?) async throws -> [GrammarPattern] {
        try await grammar.patterns(level: level)
    }
}

public struct GrammarDetail: Hashable, Sendable {
    public let pattern: GrammarPattern
    public let related: [GrammarPattern]
    public let practiceQuestions: [Question]
    public var isBookmarked: Bool
    public var note: LearnerNote?

    public init(pattern: GrammarPattern, related: [GrammarPattern], practiceQuestions: [Question], isBookmarked: Bool, note: LearnerNote?) {
        self.pattern = pattern
        self.related = related
        self.practiceQuestions = practiceQuestions
        self.isBookmarked = isBookmarked
        self.note = note
    }
}

public protocol GetGrammarDetailUseCase: Sendable {
    func execute(id: GrammarID) async throws -> GrammarDetail
}

public struct GetGrammarDetail: GetGrammarDetailUseCase {
    private let grammar: any GrammarRepository
    private let questions: any QuestionRepository
    private let bookmarks: any BookmarkRepository
    private let notes: any LearnerNoteRepository

    public init(grammar: any GrammarRepository, questions: any QuestionRepository, bookmarks: any BookmarkRepository, notes: any LearnerNoteRepository) {
        self.grammar = grammar
        self.questions = questions
        self.bookmarks = bookmarks
        self.notes = notes
    }

    public func execute(id: GrammarID) async throws -> GrammarDetail {
        guard let pattern = try await grammar.pattern(id: id) else {
            throw DomainError.notFound(entity: "GrammarPattern", id: id.rawValue)
        }
        var related: [GrammarPattern] = []
        for relatedID in pattern.relatedPatternIDs {
            if let found = try await grammar.pattern(id: relatedID) { related.append(found) }
        }
        let practice = try await questions.questions(matching: .all)
            .filter { $0.relatedGrammarID == id && $0.isValid }
        let target = LearningTarget.grammar(id)
        async let bookmarked = bookmarks.contains(target: target)
        async let note = notes.note(for: target)
        return try await GrammarDetail(pattern: pattern, related: related, practiceQuestions: practice, isBookmarked: bookmarked, note: note)
    }
}
