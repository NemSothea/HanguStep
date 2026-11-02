import Domain
import XCTest

final class LoadDashboardSummaryTests: XCTestCase {
    private struct StubVocabulary: VocabularyRepository {
        let total: Int
        func item(id: VocabularyID) async throws -> VocabularyItem? { nil }
        func items(matching filter: VocabularyFilter) async throws -> [VocabularyItem] { [] }
        func search(_ query: String, filter: VocabularyFilter) async throws -> [VocabularyItem] { [] }
        func count() async throws -> Int { total }
    }

    private struct StubGrammar: GrammarRepository {
        let total: Int
        func pattern(id: GrammarID) async throws -> GrammarPattern? { nil }
        func patterns(level: TOPIKLevel?) async throws -> [GrammarPattern] { [] }
        func count() async throws -> Int { total }
    }

    private struct StubAttempts: AttemptRepository {
        let summaryValue: AttemptSummary
        func record(_ attempt: Attempt) async throws {}
        func attempts(inSession sessionID: StudySessionID) async throws -> [Attempt] { [] }
        func attempts(forQuestion questionID: QuestionID) async throws -> [Attempt] { [] }
        func summary() async throws -> AttemptSummary { summaryValue }
    }

    private struct FailingAttempts: AttemptRepository {
        func record(_ attempt: Attempt) async throws {}
        func attempts(inSession sessionID: StudySessionID) async throws -> [Attempt] { [] }
        func attempts(forQuestion questionID: QuestionID) async throws -> [Attempt] { [] }
        func summary() async throws -> AttemptSummary { throw DomainError.storage(description: "disk") }
    }

    func testCombinesCountsFromAllRepositories() async throws {
        let useCase = LoadDashboardSummary(
            vocabulary: StubVocabulary(total: 120),
            grammar: StubGrammar(total: 7),
            attempts: StubAttempts(summaryValue: AttemptSummary(total: 40, correct: 30))
        )
        let summary = try await useCase.execute()
        XCTAssertEqual(summary.vocabularyCount, 120)
        XCTAssertEqual(summary.grammarCount, 7)
        XCTAssertEqual(summary.attempts.accuracy, 0.75, accuracy: 0.0001)
        XCTAssertEqual(summary.attempts.incorrect, 10)
    }

    func testAccuracyIsZeroWithoutAttempts() {
        XCTAssertEqual(AttemptSummary(total: 0, correct: 0).accuracy, 0)
    }

    func testRepositoryErrorPropagates() async {
        let useCase = LoadDashboardSummary(
            vocabulary: StubVocabulary(total: 0),
            grammar: StubGrammar(total: 0),
            attempts: FailingAttempts()
        )
        do {
            _ = try await useCase.execute()
            XCTFail("expected error")
        } catch let error as DomainError {
            XCTAssertEqual(error, .storage(description: "disk"))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
