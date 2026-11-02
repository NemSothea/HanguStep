import Foundation

public struct DashboardSummary: Hashable, Sendable {
    public let vocabularyCount: Int
    public let grammarCount: Int
    public let attempts: AttemptSummary

    public init(vocabularyCount: Int, grammarCount: Int, attempts: AttemptSummary) {
        self.vocabularyCount = vocabularyCount
        self.grammarCount = grammarCount
        self.attempts = attempts
    }
}

/// Use cases are protocols so view models can be tested with stubs.
public protocol LoadDashboardSummaryUseCase: Sendable {
    func execute() async throws -> DashboardSummary
}

public struct LoadDashboardSummary: LoadDashboardSummaryUseCase {
    private let vocabulary: any VocabularyRepository
    private let grammar: any GrammarRepository
    private let attempts: any AttemptRepository

    public init(
        vocabulary: any VocabularyRepository,
        grammar: any GrammarRepository,
        attempts: any AttemptRepository
    ) {
        self.vocabulary = vocabulary
        self.grammar = grammar
        self.attempts = attempts
    }

    public func execute() async throws -> DashboardSummary {
        async let vocabularyCount = vocabulary.count()
        async let grammarCount = grammar.count()
        async let attemptSummary = attempts.summary()
        return try await DashboardSummary(
            vocabularyCount: vocabularyCount,
            grammarCount: grammarCount,
            attempts: attemptSummary
        )
    }
}
