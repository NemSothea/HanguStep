import Domain
@testable import Persistence
import XCTest

/// Phase 9 coverage: the progress report joins weak items with content (PRD FR-P5).
final class LoadProgressReportTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func attempt(_ n: Int, question: Question, correct: Bool) -> Attempt {
        Attempt(
            id: AttemptID("a\(n)"), sessionID: StudySessionID("s\(n)"), questionID: question.id,
            selectedOptionID: correct ? question.correctOptionID : question.options.first { $0.id != question.correctOptionID }!.id,
            isCorrect: correct, answeredAt: base.addingTimeInterval(TimeInterval(n)), responseTime: 2, target: question.learningTarget
        )
    }

    func testWeakWordsAndPatternsAreJoinedAndMissingContentSkipped() async throws {
        let attempts = InMemoryAttemptRepository()
        let word = SampleContent.questions[0]        // vocab.sample.0001
        let grammar = SampleContent.questions[5]     // grammar.sample.0002
        var orphan = SampleContent.questions[1]
        orphan.relatedVocabularyID = VocabularyID("vocab.missing")
        var n = 0
        for question in [word, grammar, orphan] {
            for correct in [false, false, true] {   // 33%: weak
                n += 1
                try await attempts.record(attempt(n, question: question, correct: correct))
            }
        }
        let sessions = InMemoryStudySessionRepository()
        try await sessions.save(StudySession(id: StudySessionID("s"), mode: .quiz, startedAt: base, questionIDs: [word.id], deviceName: "t"))

        let report = try await LoadProgressReport(
            attempts: attempts, sessions: sessions, schedules: InMemoryReviewScheduleRepository(),
            settings: InMemoryLearnerSettingsRepository(),
            vocabulary: InMemoryVocabularyRepository(items: SampleContent.vocabulary),
            grammar: InMemoryGrammarRepository(patterns: SampleContent.grammar)
        ).execute()

        XCTAssertEqual(report.weakWords.map(\.title), ["학교"])
        XCTAssertEqual(report.weakWords[0].gloss.khmer, "សាលារៀន")
        XCTAssertEqual(report.weakWords[0].id, .vocabulary(VocabularyID("vocab.sample.0001")))
        XCTAssertEqual(report.weakGrammar.map(\.title), ["-(으)ㄹ 거예요"])
        XCTAssertEqual(report.weakGrammar[0].level, .level2)
        XCTAssertEqual(report.summary.totals.total, 9)
    }
}
