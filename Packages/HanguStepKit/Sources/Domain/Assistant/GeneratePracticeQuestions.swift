import Foundation

public protocol GeneratePracticeQuestionsUseCase: Sendable {
    /// Returns the questions that passed validation and were stored, in order.
    /// Throws `AssistantError.nothingUsable` when the provider's drafts all failed.
    func execute(target: LearningTarget, count: Int) async throws -> [Question]
}

/// Asks the provider for drafts, keeps only those that validate like bundled
/// content (PRD FR-A2), stamps provenance and stores them for later practice.
public struct GeneratePracticeQuestions: GeneratePracticeQuestionsUseCase {
    public static let distractorPoolSize = 12
    public static let maximumCount = 10

    private let providers: any AssistantProviderSource
    private let vocabulary: any VocabularyRepository
    private let grammar: any GrammarRepository
    private let store: any GeneratedQuestionStore
    private let ids: any IDGenerator
    private let shuffler: any Shuffler

    public init(
        providers: any AssistantProviderSource,
        vocabulary: any VocabularyRepository,
        grammar: any GrammarRepository,
        store: any GeneratedQuestionStore,
        ids: any IDGenerator = UUIDGenerator(),
        shuffler: any Shuffler = SystemShuffler()
    ) {
        self.providers = providers
        self.vocabulary = vocabulary
        self.grammar = grammar
        self.store = store
        self.ids = ids
        self.shuffler = shuffler
    }

    public func execute(target: LearningTarget, count: Int) async throws -> [Question] {
        let provider = try await providers.currentProvider()
        let subject = try await subject(for: target)
        let existing = try await store.generated(for: target)
        let request = PracticeRequest(
            subject: subject,
            count: min(max(1, count), Self.maximumCount),
            existingPrompts: existing.map(\.prompt)
        )
        let drafts = try await provider.generate(request)
        let source = ContentSource(origin: .aiGenerated, name: provider.name, license: "Generated for this learner")
        var seenPrompts = Set(existing.map(\.prompt))
        var accepted: [Question] = []
        for draft in drafts where seenPrompts.insert(draft.prompt).inserted {
            guard let question = Self.question(from: draft, target: target, level: subject.level, source: source, id: QuestionID("q.ai.\(ids.next())")) else { continue }
            accepted.append(question)
        }
        guard !accepted.isEmpty else { throw AssistantError.nothingUsable }
        try await store.save(accepted)
        return accepted
    }

    /// Converts a draft into a `Question`, or nil when it would not pass `validate()`.
    public static func question(from draft: DraftQuestion, target: LearningTarget, level: TOPIKLevel, source: ContentSource, id: QuestionID) -> Question? {
        let trimmed = draft.options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard trimmed.indices.contains(draft.answer), !trimmed.contains(where: \.isEmpty) else { return nil }
        let options = trimmed.enumerated().map { QuestionOption(id: OptionID("o\($0.offset + 1)"), text: $0.element) }
        let question = Question(
            id: id, kind: draft.kind, level: level,
            prompt: draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            passage: draft.passage?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            options: options, correctOptionID: OptionID("o\(draft.answer + 1)"),
            explanation: Gloss(english: draft.explanation.english.trimmingCharacters(in: .whitespacesAndNewlines), khmer: draft.explanation.khmer.trimmingCharacters(in: .whitespacesAndNewlines)),
            relatedVocabularyID: { if case let .vocabulary(id) = target { return id } else { return nil } }(),
            relatedGrammarID: { if case let .grammar(id) = target { return id } else { return nil } }(),
            source: source, contentVersion: 0
        )
        return question.isValid ? question : nil
    }

    private func subject(for target: LearningTarget) async throws -> PracticeSubject {
        switch target {
        case let .vocabulary(id):
            guard let item = try await vocabulary.item(id: id) else { throw DomainError.notFound(entity: "VocabularyItem", id: id.rawValue) }
            let siblings = try await vocabulary.items(matching: VocabularyFilter(levels: [item.level], partsOfSpeech: [item.partOfSpeech]))
                .filter { $0.id != item.id }
            let pool = siblings.count >= 3 ? siblings : try await vocabulary.items(matching: VocabularyFilter(levels: [item.level])).filter { $0.id != item.id }
            return .vocabulary(item, distractors: Array(shuffler.shuffle(pool).prefix(Self.distractorPoolSize)))
        case let .grammar(id):
            guard let pattern = try await grammar.pattern(id: id) else { throw DomainError.notFound(entity: "GrammarPattern", id: id.rawValue) }
            let siblings = try await grammar.patterns(level: pattern.level).filter { $0.id != pattern.id }
            let pool = siblings.count >= 3 ? siblings : try await grammar.patterns(level: nil).filter { $0.id != pattern.id }
            return .grammar(pattern, others: Array(shuffler.shuffle(pool).prefix(Self.distractorPoolSize)))
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
