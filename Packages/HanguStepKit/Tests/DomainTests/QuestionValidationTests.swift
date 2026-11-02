import Domain
import XCTest

final class QuestionValidationTests: XCTestCase {
    private let source = ContentSource(origin: .curated, name: "test", license: "none")

    private func question(
        prompt: String = "Prompt",
        options: [QuestionOption] = [
            QuestionOption(id: OptionID("a"), text: "A"),
            QuestionOption(id: OptionID("b"), text: "B"),
        ],
        correct: OptionID = OptionID("a"),
        explanation: Gloss = Gloss(english: "because", khmer: "ព្រោះ")
    ) -> Question {
        Question(
            id: QuestionID("q"), kind: .vocabularyMeaning, level: .level1,
            prompt: prompt, options: options, correctOptionID: correct,
            explanation: explanation, source: source, contentVersion: 1
        )
    }

    func testValidQuestionHasNoIssues() {
        XCTAssertTrue(question().isValid)
    }

    func testEmptyPromptIsReported() {
        XCTAssertEqual(question(prompt: "   ").validate(), [.emptyPrompt])
    }

    func testCorrectOptionMustBeAmongOptions() {
        XCTAssertEqual(question(correct: OptionID("zzz")).validate(), [.correctOptionMissing])
    }

    func testDuplicateOptionTextIsCaseInsensitive() {
        let options = [
            QuestionOption(id: OptionID("a"), text: "School"),
            QuestionOption(id: OptionID("b"), text: "school "),
        ]
        XCTAssertEqual(question(options: options).validate(), [.duplicateOptionText])
    }

    func testTooFewAndTooManyOptions() {
        XCTAssertEqual(question(options: [QuestionOption(id: OptionID("a"), text: "A")]).validate(), [.tooFewOptions(count: 1)])
        let five = (0..<5).map { QuestionOption(id: OptionID("\($0)"), text: "\($0)") }
        XCTAssertEqual(question(options: five, correct: OptionID("0")).validate(), [.tooManyOptions(count: 5)])
    }

    func testMissingKhmerExplanationIsReported() {
        XCTAssertEqual(question(explanation: Gloss(english: "x", khmer: "")).validate(), [.emptyExplanation(.khmer)])
    }

    func testTOPIKLevelExamMapping() {
        XCTAssertEqual(TOPIKLevel.level2.exam, .topikI)
        XCTAssertEqual(TOPIKLevel.level3.exam, .topikII)
        XCTAssertLessThan(TOPIKLevel.level1, TOPIKLevel.level6)
    }
}
