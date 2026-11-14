import Domain
@testable import Persistence
import XCTest

/// Phase 9 coverage: the mistake list joins attempts with content and sorts (PRD FR-R1, FR-R2).
final class ListMistakesTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func attempt(_ n: Int, question: Question, correct: Bool, at offset: TimeInterval) -> Attempt {
        Attempt(
            id: AttemptID("a\(n)"), sessionID: StudySessionID("s\(n)"), questionID: question.id,
            selectedOptionID: correct ? question.correctOptionID : question.options.first { $0.id != question.correctOptionID }!.id,
            isCorrect: correct, answeredAt: base.addingTimeInterval(offset), responseTime: 2, target: question.learningTarget
        )
    }

    func testEntriesJoinVocabularyAndGrammarAndSkipMissingContent() async throws {
        let attempts = InMemoryAttemptRepository()
        let wordQuestion = SampleContent.questions[0]      // vocab.sample.0001
        let grammarQuestion = SampleContent.questions[5]   // grammar.sample.0002
        try await attempts.record(attempt(1, question: wordQuestion, correct: false, at: 10))
        try await attempts.record(attempt(2, question: grammarQuestion, correct: false, at: 20))
        try await attempts.record(attempt(3, question: grammarQuestion, correct: false, at: 30))
        var orphan = SampleContent.questions[1]
        orphan.relatedVocabularyID = VocabularyID("vocab.missing")
        try await attempts.record(attempt(4, question: orphan, correct: false, at: 40))

        let list = ListMistakes(
            attempts: attempts,
            vocabulary: InMemoryVocabularyRepository(items: SampleContent.vocabulary),
            grammar: InMemoryGrammarRepository(patterns: SampleContent.grammar)
        )
        let recent = try await list.execute(sort: .recent)
        XCTAssertEqual(recent.map(\.title), ["-(으)ㄹ 거예요", "학교"], "missing content is skipped, most recent first")
        XCTAssertEqual(recent[0].mistake.timesMissed, 2)
        XCTAssertEqual(recent[0].level, .level2)
        XCTAssertEqual(recent[1].gloss.english, "school")
        XCTAssertEqual(recent[1].id, .vocabulary(VocabularyID("vocab.sample.0001")))

        let frequent = try await list.execute(sort: .frequent)
        XCTAssertEqual(frequent.map(\.mistake.timesMissed), [2, 1])

        // Two consecutive correct answers clear the word (FR-R2).
        try await attempts.record(attempt(5, question: wordQuestion, correct: true, at: 50))
        try await attempts.record(attempt(6, question: wordQuestion, correct: true, at: 60))
        let cleared = try await list.execute(sort: .recent)
        XCTAssertEqual(cleared.map(\.title), ["-(으)ㄹ 거예요"])
    }

    func testEmptyWhenNoAttempts() async throws {
        let list = ListMistakes(attempts: InMemoryAttemptRepository(), vocabulary: InMemoryVocabularyRepository(items: []), grammar: InMemoryGrammarRepository(patterns: []))
        let entries = try await list.execute(sort: .frequent)
        XCTAssertTrue(entries.isEmpty)
    }
}
