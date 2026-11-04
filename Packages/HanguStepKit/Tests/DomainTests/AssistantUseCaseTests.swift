import Domain
@testable import Persistence
import XCTest

/// Phase 8: the mock provider and the two use cases that wrap any provider.
final class AssistantUseCaseTests: XCTestCase {
    private var vocabulary: InMemoryVocabularyRepository!
    private var grammar: InMemoryGrammarRepository!
    private var questions: InMemoryQuestionRepository!

    override func setUp() {
        vocabulary = InMemoryVocabularyRepository(items: SampleContent.vocabulary)
        grammar = InMemoryGrammarRepository(patterns: SampleContent.grammar)
        questions = InMemoryQuestionRepository(questions: SampleContent.questions)
    }

    private func generator(provider: any AssistantProvider = MockAssistantProvider()) -> GeneratePracticeQuestions {
        GeneratePracticeQuestions(
            providers: FixedAssistantProviderSource(provider), vocabulary: vocabulary, grammar: grammar,
            store: questions, ids: CountingIDGenerator(), shuffler: IdentityShuffler()
        )
    }

    // MARK: Mock provider

    func testMockExplanationMentionsChoiceAndWord() async throws {
        let question = SampleContent.questions[0]   // 학교, correct o1
        let request = ExplanationRequest(question: question, selectedOptionID: OptionID("o2"), language: .english, vocabulary: SampleContent.vocabulary[0])
        let explanation = try await MockAssistantProvider().explain(request)
        XCTAssertTrue(explanation.text.contains("friend / មិត្តភក្តិ"), "names the wrong choice")
        XCTAssertTrue(explanation.text.contains("school / សាលារៀន"), "names the right answer")
        XCTAssertTrue(explanation.text.contains("학교 (hakgyo) means \"school\""))
        XCTAssertEqual(explanation.providerName, "Built-in assistant")

        let khmer = try await MockAssistantProvider().explain(ExplanationRequest(question: question, selectedOptionID: question.correctOptionID, language: .khmer))
        XCTAssertTrue(khmer.text.hasPrefix("ត្រឹមត្រូវ។"))
    }

    func testMockVocabularyDraftsAreValidAndDeterministic() async throws {
        let item = SampleContent.vocabulary[0]
        let distractors = Array(SampleContent.vocabulary.dropFirst())
        let request = PracticeRequest(subject: .vocabulary(item, distractors: distractors), count: 10)
        let first = try await MockAssistantProvider().generate(request)
        let second = try await MockAssistantProvider().generate(request)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 3, "one cloze from the example plus two meaning questions")
        XCTAssertEqual(first.map(\.kind), [.sentenceCompletion, .vocabularyMeaning, .meaningToWord])
        XCTAssertEqual(first[0].prompt, "저는 ______에 가요.")
        for draft in first {
            XCTAssertEqual(draft.options.count, 4)
            XCTAssertEqual(Set(draft.options).count, 4)
            XCTAssertTrue(draft.options.indices.contains(draft.answer))
        }
        XCTAssertEqual(first[0].options[first[0].answer], "학교")
    }

    func testMockSkipsExistingPromptsAndHonoursCount() async throws {
        let item = SampleContent.vocabulary[0]
        let request = PracticeRequest(subject: .vocabulary(item, distractors: Array(SampleContent.vocabulary.dropFirst())), count: 1, existingPrompts: ["저는 ______에 가요."])
        let drafts = try await MockAssistantProvider().generate(request)
        XCTAssertEqual(drafts.map(\.kind), [.vocabularyMeaning])
    }

    func testMockGrammarDraftsNeedThreeForeignExamples() async throws {
        let pattern = SampleContent.grammar[0]   // two examples
        let other = SampleContent.grammar[1]     // one example: not enough
        let none = try await MockAssistantProvider().generate(PracticeRequest(subject: .grammar(pattern, others: [other]), count: 5))
        XCTAssertTrue(none.isEmpty)
        let padded = (0..<3).map { index in
            GrammarPattern(id: GrammarID("g\(index)"), pattern: "p\(index)", level: .level1, category: "c", explanation: Gloss(english: "e", khmer: "ខ"),
                           examples: [ExampleSentence(korean: "문장 \(index)", translation: Gloss(english: "s\(index)", khmer: "ប\(index)"))], source: SampleContent.source, contentVersion: 1)
        }
        let drafts = try await MockAssistantProvider().generate(PracticeRequest(subject: .grammar(pattern, others: padded), count: 5))
        XCTAssertEqual(drafts.count, 2)
        XCTAssertEqual(drafts[0].options[drafts[0].answer], pattern.examples[0].korean)
    }

    // MARK: ExplainAnswer

    func testExplainAnswerJoinsContentAndRespectsSource() async throws {
        let question = SampleContent.questions[5]   // grammar fill-in, related grammar 0002
        let recorder = RecordingProvider()
        let useCase = ExplainAnswer(providers: FixedAssistantProviderSource(recorder), vocabulary: vocabulary, grammar: grammar)
        _ = try await useCase.execute(question: question, selectedOptionID: OptionID("o2"), language: .khmer)
        let recorded = await recorder.lastExplanation
        let request = try XCTUnwrap(recorded)
        XCTAssertEqual(request.grammar?.id.rawValue, "grammar.sample.0002")
        XCTAssertNil(request.vocabulary)
        XCTAssertEqual(request.language, .khmer)

        let disabled = ExplainAnswer(providers: DisabledAssistantProviderSource(), vocabulary: vocabulary, grammar: grammar)
        do {
            _ = try await disabled.execute(question: question, selectedOptionID: OptionID("o1"), language: .english)
            XCTFail("expected disabled")
        } catch let error as AssistantError {
            XCTAssertEqual(error, .disabled)
        }
    }

    // MARK: GeneratePracticeQuestions

    func testGeneratedQuestionsAreValidatedStampedAndStored() async throws {
        let stored = try await generator().execute(target: .vocabulary(VocabularyID("vocab.sample.0001")), count: 3)
        XCTAssertEqual(stored.count, 3)
        for question in stored {
            XCTAssertTrue(question.id.rawValue.hasPrefix("q.ai."))
            XCTAssertEqual(question.source.origin, .aiGenerated)
            XCTAssertEqual(question.source.name, "Built-in assistant")
            XCTAssertEqual(question.relatedVocabularyID?.rawValue, "vocab.sample.0001")
            XCTAssertEqual(question.level, .level1)
            XCTAssertEqual(question.contentVersion, 0)
            XCTAssertTrue(question.isValid)
            XCTAssertEqual(question.options.map(\.id.rawValue), ["o1", "o2", "o3", "o4"])
        }
        let fromStore = try await questions.generated(for: .vocabulary(VocabularyID("vocab.sample.0001")))
        XCTAssertEqual(fromStore.map(\.id), stored.map(\.id))
        let readable = try await questions.question(id: stored[0].id)
        XCTAssertNotNil(readable, "generated questions are served by the ordinary repository")
        let count = try await questions.generatedCount()
        XCTAssertEqual(count, 3)
    }

    func testGeneratingAgainSkipsExistingPrompts() async throws {
        let target = LearningTarget.vocabulary(VocabularyID("vocab.sample.0001"))
        _ = try await generator().execute(target: target, count: 10)
        do {
            _ = try await generator().execute(target: target, count: 10)
            XCTFail("mock has no new prompts left")
        } catch let error as AssistantError {
            XCTAssertEqual(error, .nothingUsable)
        }
        let count = try await questions.generatedCount()
        XCTAssertEqual(count, 3)
    }

    func testInvalidDraftsAreDroppedNotStored() async throws {
        let bad = DraftQuestion(kind: .sentenceCompletion, prompt: "x ______", options: ["a", "a", "b", "c"], answer: 0, explanation: Gloss(english: "e", khmer: "ខ"))
        let outOfRange = DraftQuestion(kind: .sentenceCompletion, prompt: "y ______", options: ["a", "b"], answer: 5, explanation: Gloss(english: "e", khmer: "ខ"))
        let noKhmer = DraftQuestion(kind: .sentenceCompletion, prompt: "z ______", options: ["a", "b"], answer: 0, explanation: Gloss(english: "e", khmer: " "))
        let good = DraftQuestion(kind: .sentenceCompletion, prompt: "w ______", options: ["a", "b", "c"], answer: 2, explanation: Gloss(english: "e", khmer: "ខ"))
        let stored = try await generator(provider: StaticProvider(drafts: [bad, outOfRange, noKhmer, good, good])).execute(target: .grammar(GrammarID("grammar.sample.0001")), count: 5)
        XCTAssertEqual(stored.map(\.prompt), ["w ______"], "duplicates and invalid drafts are dropped")
        XCTAssertEqual(stored[0].correctOptionID.rawValue, "o3")
        XCTAssertEqual(stored[0].relatedGrammarID?.rawValue, "grammar.sample.0001")

        do {
            _ = try await generator(provider: StaticProvider(drafts: [bad])).execute(target: .grammar(GrammarID("grammar.sample.0002")), count: 1)
            XCTFail("expected nothingUsable")
        } catch let error as AssistantError {
            XCTAssertEqual(error, .nothingUsable)
        }
    }

    func testUnknownTargetThrowsNotFound() async {
        do {
            _ = try await generator().execute(target: .vocabulary(VocabularyID("missing")), count: 1)
            XCTFail("expected notFound")
        } catch let error as DomainError {
            XCTAssertEqual(error, .notFound(entity: "VocabularyItem", id: "missing"))
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testGeneratedQuestionsCanStartAFixedSession() async throws {
        let stored = try await generator().execute(target: .vocabulary(VocabularyID("vocab.sample.0001")), count: 2)
        let start = StartQuizSession(
            questions: questions, sessions: InMemoryStudySessionRepository(), attempts: InMemoryAttemptRepository(),
            schedules: InMemoryReviewScheduleRepository(), settings: InMemoryLearnerSettingsRepository(), deviceName: "test"
        )
        let snapshot = try await start.execute(QuizConfiguration(pool: .questions(stored.map(\.id)), count: stored.count))
        XCTAssertEqual(snapshot.questions.map(\.id), stored.map(\.id))
    }
}

// MARK: - Test doubles

private struct StaticProvider: AssistantProvider {
    let name = "static"
    let drafts: [DraftQuestion]
    func explain(_ request: ExplanationRequest) async throws -> AssistantExplanation { AssistantExplanation(text: "ok", language: request.language, providerName: name) }
    func generate(_ request: PracticeRequest) async throws -> [DraftQuestion] { drafts }
}

private actor RecordingProvider: AssistantProvider {
    nonisolated let name = "recorder"
    private(set) var lastExplanation: ExplanationRequest?
    func explain(_ request: ExplanationRequest) async throws -> AssistantExplanation {
        lastExplanation = request
        return AssistantExplanation(text: "recorded", language: request.language, providerName: name)
    }
    func generate(_ request: PracticeRequest) async throws -> [DraftQuestion] { [] }
}

private final class CountingIDGenerator: IDGenerator, @unchecked Sendable {
    private let lock = NSLock()
    private var counter = 0
    func next() -> String { lock.withLock { counter += 1; return String(format: "%04d", counter) } }
}
