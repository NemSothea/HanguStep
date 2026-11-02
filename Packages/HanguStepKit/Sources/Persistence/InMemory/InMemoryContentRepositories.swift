import Domain
import Foundation

/// In-memory content repositories. Used for previews, tests and the Phase 1
/// skeleton. Core Data implementations replace them for production in Phase 3.
public actor InMemoryVocabularyRepository: VocabularyRepository {
    private var items: [VocabularyID: VocabularyItem]

    public init(items: [VocabularyItem]) {
        self.items = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    public func item(id: VocabularyID) async throws -> VocabularyItem? { items[id] }

    public func items(matching filter: VocabularyFilter) async throws -> [VocabularyItem] {
        items.values.filter(filter.matches).sorted { $0.hangul < $1.hangul }
    }

    public func search(_ query: String, filter: VocabularyFilter) async throws -> [VocabularyItem] {
        let needle = TextNormalizer.normalize(query)
        guard !needle.isEmpty else { return try await items(matching: filter) }
        return try await items(matching: filter).filter { item in
            [item.hangul, item.romanization, item.meaning.english, item.meaning.khmer]
                .contains { TextNormalizer.normalize($0).contains(needle) }
        }
    }

    public func count() async throws -> Int { items.count }
}

public actor InMemoryGrammarRepository: GrammarRepository {
    private var patterns: [GrammarID: GrammarPattern]

    public init(patterns: [GrammarPattern]) {
        self.patterns = Dictionary(uniqueKeysWithValues: patterns.map { ($0.id, $0) })
    }

    public func pattern(id: GrammarID) async throws -> GrammarPattern? { patterns[id] }

    public func patterns(level: TOPIKLevel?) async throws -> [GrammarPattern] {
        patterns.values
            .filter { level == nil || $0.level == level }
            .sorted { ($0.level, $0.pattern) < ($1.level, $1.pattern) }
    }

    public func count() async throws -> Int { patterns.count }
}

public actor InMemoryQuestionRepository: QuestionRepository {
    private var questions: [QuestionID: Question]

    public init(questions: [Question]) {
        self.questions = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
    }

    public func question(id: QuestionID) async throws -> Question? { questions[id] }

    public func questions(ids: [QuestionID]) async throws -> [Question] {
        ids.compactMap { questions[$0] }
    }

    public func questions(matching filter: QuestionFilter) async throws -> [Question] {
        questions.values.filter(filter.matches).sorted { $0.id.rawValue < $1.id.rawValue }
    }

    public func count() async throws -> Int { questions.count }
}

/// Shared normalization for search. Khmer text must be NFC-normalized because
/// the same visible word can be typed with different code point orders.
public enum TextNormalizer {
    public static func normalize(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
