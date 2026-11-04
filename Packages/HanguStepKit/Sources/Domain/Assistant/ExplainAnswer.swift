import Foundation

public protocol ExplainAnswerUseCase: Sendable {
    func execute(question: Question, selectedOptionID: OptionID, language: GlossLanguage) async throws -> AssistantExplanation
}

/// Joins the question with its word or pattern and asks the configured provider.
/// Nothing is stored; explanations are ephemeral.
public struct ExplainAnswer: ExplainAnswerUseCase {
    private let providers: any AssistantProviderSource
    private let vocabulary: any VocabularyRepository
    private let grammar: any GrammarRepository

    public init(providers: any AssistantProviderSource, vocabulary: any VocabularyRepository, grammar: any GrammarRepository) {
        self.providers = providers
        self.vocabulary = vocabulary
        self.grammar = grammar
    }

    public func execute(question: Question, selectedOptionID: OptionID, language: GlossLanguage) async throws -> AssistantExplanation {
        let provider = try await providers.currentProvider()
        var item: VocabularyItem?
        if let id = question.relatedVocabularyID { item = try await vocabulary.item(id: id) }
        var pattern: GrammarPattern?
        if let id = question.relatedGrammarID { pattern = try await grammar.pattern(id: id) }
        let request = ExplanationRequest(question: question, selectedOptionID: selectedOptionID, language: language, vocabulary: item, grammar: pattern)
        return try await provider.explain(request)
    }
}
