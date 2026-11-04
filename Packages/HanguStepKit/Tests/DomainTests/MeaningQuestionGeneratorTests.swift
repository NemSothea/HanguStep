@testable import Domain
import XCTest

final class MeaningQuestionGeneratorTests: XCTestCase {
    private let source = ContentFile.Source(origin: .curated, name: "gen", license: "CC BY 4.0")

    private func word(_ n: Int, _ hangul: String, en: String, pos: PartOfSpeech = .noun, level: Int = 1, review: ContentFile.ReviewStatus? = nil) -> ContentFile.Vocabulary {
        ContentFile.Vocabulary(
            id: String(format: "vocab.%04d", n), hangul: hangul, romanization: "r\(n)", pos: pos, level: level, category: "c",
            meaning: ContentFile.Text(en: en, km: "km\(n)"), review: review
        )
    }

    private var words: [ContentFile.Vocabulary] {
        [
            word(1, "학교", en: "school"), word(2, "친구", en: "friend"), word(3, "물", en: "water"), word(4, "책", en: "book"),
            word(5, "가다", en: "to go", pos: .verb), word(6, "오다", en: "to come", pos: .verb), word(7, "먹다", en: "to eat", pos: .verb),
            word(8, "회의", en: "meeting", level: 3), word(9, "경험", en: "experience", level: 3, review: .pending),
        ]
    }

    func testTwoQuestionsPerWordAndAllValidate() throws {
        let generated = MeaningQuestionGenerator.generate(from: words, source: source)
        XCTAssertEqual(generated.count, words.count * 2)
        XCTAssertEqual(Set(generated.map(\.id)).count, generated.count)
        let part = try JSONEncoder().encode(ContentFile.Part(questions: generated))
        let vocabulary = try JSONEncoder().encode(ContentFile.Package(version: 1, source: source, vocabulary: words))
        let result = try ContentFile.load(package: vocabulary, parts: [(name: "questions/g.json", data: part)])
        XCTAssertTrue(result.package.validate().isEmpty)
        XCTAssertEqual(result.pendingReview, 1 + 2, "word 9 and its two questions are pending")
    }

    func testCorrectAnswerMatchesTheWord() {
        for question in MeaningQuestionGenerator.generate(from: words, source: source) {
            let entry = words.first { $0.id == question.vocabulary }!
            XCTAssertEqual(question.options.count, MeaningQuestionGenerator.optionCount)
            switch question.kind {
            case .vocabularyMeaning:
                XCTAssertEqual(question.options[question.answer], "\(entry.meaning.en) / \(entry.meaning.km)")
                XCTAssertTrue(question.prompt.contains(entry.hangul))
            case .meaningToWord:
                XCTAssertEqual(question.options[question.answer], entry.hangul)
                XCTAssertTrue(question.prompt.contains(entry.meaning.en))
            default:
                XCTFail("unexpected kind \(question.kind)")
            }
            XCTAssertEqual(Set(question.options).count, question.options.count, "no duplicate options in \(question.id)")
            XCTAssertEqual(question.level, entry.level)
            XCTAssertEqual(question.review, entry.review)
        }
    }

    func testOutputIsDeterministicAndIndependentOfInputOrder() {
        let first = MeaningQuestionGenerator.generate(from: words, source: source)
        let second = MeaningQuestionGenerator.generate(from: words.reversed(), source: source)
        XCTAssertEqual(first, second)
    }

    func testDistractorsPreferSamePartOfSpeechAndLevel() {
        let generated = MeaningQuestionGenerator.generate(from: words, source: source)
        let schoolQuestion = generated.first { $0.id == "q.mw.vocab.0001" }!
        let distractors = schoolQuestion.options.filter { $0 != "학교" }
        for distractor in distractors {
            let entry = words.first { $0.hangul == distractor }!
            XCTAssertEqual(entry.pos, .noun, "\(distractor) should be a level 1 noun like 학교")
            XCTAssertEqual(entry.level, 1)
        }
        // Only three verbs exist, so the verb question must fall back to other parts of speech.
        let goQuestion = generated.first { $0.id == "q.mw.vocab.0005" }!
        XCTAssertEqual(goQuestion.options.count, 4)
        XCTAssertTrue(goQuestion.options.contains("오다"))
        XCTAssertTrue(goQuestion.options.contains("먹다"))
    }

    func testTooFewWordsProducesNothing() {
        XCTAssertTrue(MeaningQuestionGenerator.generate(from: Array(words.prefix(3)), source: source).isEmpty)
    }

    func testStableHashAndShuffle() {
        XCTAssertEqual(MeaningQuestionGenerator.hash("vocab.0001#vm"), MeaningQuestionGenerator.hash("vocab.0001#vm"))
        XCTAssertNotEqual(MeaningQuestionGenerator.hash("a"), MeaningQuestionGenerator.hash("b"))
        let order = MeaningQuestionGenerator.shuffledOrder(seed: 42, count: 4)
        XCTAssertEqual(order.sorted(), [0, 1, 2, 3])
        XCTAssertEqual(order, MeaningQuestionGenerator.shuffledOrder(seed: 42, count: 4))
    }
}
