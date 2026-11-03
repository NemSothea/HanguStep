import Domain
import XCTest

final class MistakeDerivationTests: XCTestCase {
    private let word = LearningTarget.vocabulary(VocabularyID("w"))
    private let pattern = LearningTarget.grammar(GrammarID("g"))

    private func attempt(_ n: Int, _ target: LearningTarget?, correct: Bool) -> Attempt {
        Attempt(
            id: AttemptID("a\(n)"), sessionID: StudySessionID("s"), questionID: QuestionID("q\(n)"),
            selectedOptionID: OptionID("o"), isCorrect: correct,
            answeredAt: Date(timeIntervalSince1970: TimeInterval(n)), responseTime: 1, target: target
        )
    }

    func testMissedTargetAppearsWithCounts() {
        let mistakes = MistakeDerivation.mistakes(from: [
            attempt(1, word, correct: true),
            attempt(2, word, correct: false),
            attempt(3, word, correct: false),
            attempt(4, pattern, correct: true),
        ])
        XCTAssertEqual(mistakes.count, 1)
        XCTAssertEqual(mistakes[0].target, word)
        XCTAssertEqual(mistakes[0].timesMissed, 2)
        XCTAssertEqual(mistakes[0].timesAnswered, 3)
        XCTAssertEqual(mistakes[0].lastMissedAt, Date(timeIntervalSince1970: 3))
        XCTAssertEqual(mistakes[0].accuracy, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testTwoConsecutiveCorrectClearsMistake() {
        let base = [attempt(1, word, correct: false), attempt(2, word, correct: true)]
        XCTAssertEqual(MistakeDerivation.mistakes(from: base).count, 1, "one correct is not enough")
        let cleared = base + [attempt(3, word, correct: true)]
        XCTAssertTrue(MistakeDerivation.mistakes(from: cleared).isEmpty)
        let relapsed = cleared + [attempt(4, word, correct: false)]
        XCTAssertEqual(MistakeDerivation.mistakes(from: relapsed).first?.consecutiveCorrect, 0)
    }

    func testOrderIndependentAndIgnoresUntargeted() {
        let shuffled = [attempt(3, word, correct: true), attempt(1, word, correct: false), attempt(2, word, correct: true), attempt(9, nil, correct: false)]
        XCTAssertTrue(MistakeDerivation.mistakes(from: shuffled).isEmpty, "sorted by time: miss, correct, correct → cleared")
    }

    func testSortedMostRecentFirst() {
        let mistakes = MistakeDerivation.mistakes(from: [attempt(1, word, correct: false), attempt(5, pattern, correct: false)])
        XCTAssertEqual(mistakes.map(\.target), [pattern, word])
    }
}
