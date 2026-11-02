import Domain
import Features
import Persistence

/// Composition root. The only place that knows concrete repository types.
/// Phase 3 swaps the in-memory repositories for Core Data without touching Features.
@MainActor
final class AppContainer {
    let dependencies: AppDependencies

    init() {
        let vocabulary = InMemoryVocabularyRepository(items: SampleContent.vocabulary)
        let grammar = InMemoryGrammarRepository(patterns: SampleContent.grammar)
        let attempts = InMemoryAttemptRepository()

        dependencies = AppDependencies(
            loadDashboardSummary: LoadDashboardSummary(
                vocabulary: vocabulary,
                grammar: grammar,
                attempts: attempts
            )
        )
    }
}
