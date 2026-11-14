import Domain
@testable import Persistence
import XCTest

/// Phase 8: generated questions sit beside the library in the content store and
/// survive a content import (ADR-008).
final class GeneratedQuestionStoreTests: XCTestCase {
    private var controller: PersistenceController!
    private var store: CoreDataGeneratedQuestionStore!
    private var questions: CoreDataQuestionRepository!

    override func setUpWithError() throws {
        controller = try PersistenceController(mode: .inMemory)
        store = CoreDataGeneratedQuestionStore(controller: controller)
        questions = CoreDataQuestionRepository(controller: controller)
    }

    private func generated(_ number: Int, target: LearningTarget = .vocabulary(VocabularyID("vocab.sample.0001"))) -> Question {
        Question(
            id: QuestionID("q.ai.\(number)"), kind: .sentenceCompletion, level: .level1, prompt: "prompt \(number) ______",
            options: [QuestionOption(id: OptionID("o1"), text: "a"), QuestionOption(id: OptionID("o2"), text: "b")],
            correctOptionID: OptionID("o1"), explanation: Gloss(english: "e", khmer: "ខ"),
            relatedVocabularyID: { if case let .vocabulary(id) = target { return id } else { return nil } }(),
            relatedGrammarID: { if case let .grammar(id) = target { return id } else { return nil } }(),
            source: ContentSource(origin: .aiGenerated, name: "test provider", license: "Generated"), contentVersion: 0
        )
    }

    func testSaveReadCountAndDelete() async throws {
        try await store.save([generated(1), generated(2), generated(3, target: .grammar(GrammarID("grammar.sample.0001")))])
        let forWord = try await store.generated(for: .vocabulary(VocabularyID("vocab.sample.0001")))
        XCTAssertEqual(forWord.map(\.id.rawValue), ["q.ai.1", "q.ai.2"])
        XCTAssertEqual(forWord[0].source.origin, .aiGenerated)
        XCTAssertEqual(forWord[0].options.count, 2)
        let forPattern = try await store.generated(for: .grammar(GrammarID("grammar.sample.0001")))
        XCTAssertEqual(forPattern.map(\.id.rawValue), ["q.ai.3"])
        let count = try await store.generatedCount()
        XCTAssertEqual(count, 3)

        let served = try await questions.question(id: QuestionID("q.ai.2"))
        XCTAssertEqual(served?.prompt, "prompt 2 ______", "ordinary repository serves generated rows")
        let total = try await questions.count()
        XCTAssertEqual(total, 3)

        // Saving the same id again updates in place.
        var changed = generated(1)
        changed.prompt = "changed ______"
        try await store.save([changed])
        let after = try await store.generated(for: .vocabulary(VocabularyID("vocab.sample.0001")))
        XCTAssertEqual(after.map(\.prompt), ["changed ______", "prompt 2 ______"])

        let deleted = try await store.deleteAllGenerated()
        XCTAssertEqual(deleted, 3)
        let remaining = try await questions.count()
        XCTAssertEqual(remaining, 0)
    }

    func testStoreRejectsInvalidOrNonGeneratedQuestions() async throws {
        var invalid = generated(1)
        invalid.correctOptionID = OptionID("missing")
        do {
            try await store.save([invalid])
            XCTFail("expected invalidContent")
        } catch let error as DomainError {
            guard case .invalidContent = error else { return XCTFail("\(error)") }
        }
        var curated = generated(2)
        curated.source = SampleContent.source
        do {
            try await store.save([curated])
            XCTFail("expected invalidPackage")
        } catch let error as DomainError {
            guard case .invalidPackage = error else { return XCTFail("\(error)") }
        }
        let count = try await store.generatedCount()
        XCTAssertEqual(count, 0)
    }

    func testContentImportKeepsGeneratedQuestionsAndRetiresTheRest() async throws {
        let content = CoreDataContentStore(controller: controller)
        _ = try await content.apply(SampleContent.package)
        try await store.save([generated(1)])

        let upgraded = ContentPackage(
            version: SampleContent.version + 1,
            vocabulary: SampleContent.vocabulary, grammar: SampleContent.grammar,
            questions: Array(SampleContent.questions.dropLast())
        )
        let result = try await content.apply(upgraded)
        XCTAssertEqual(result.retired, 1, "only the dropped curated question is retired")

        let stillThere = try await store.generated(for: .vocabulary(VocabularyID("vocab.sample.0001")))
        XCTAssertEqual(stillThere.map(\.id.rawValue), ["q.ai.1"])
        let active = try await questions.count()
        XCTAssertEqual(active, SampleContent.questions.count - 1 + 1)

        // A session built from generated ids resolves them.
        let fetched = try await questions.questions(ids: [QuestionID("q.ai.1")])
        XCTAssertEqual(fetched.count, 1)
    }
}
