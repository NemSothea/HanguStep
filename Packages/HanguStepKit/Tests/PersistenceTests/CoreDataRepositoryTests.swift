import Domain
@testable import Persistence
import XCTest

final class CoreDataRepositoryTests: XCTestCase {
    private var controller: PersistenceController!

    override func setUpWithError() throws {
        controller = try PersistenceController(mode: .inMemory)
    }

    private func importSample() async throws -> ContentImportResult {
        try await CoreDataContentStore(controller: controller).apply(SampleContent.package)
    }

    // 1. Model and stores
    func testBothStoresOpenInMemory() {
        let configurations = controller.container.persistentStoreCoordinator.persistentStores.compactMap(\.configurationName)
        XCTAssertEqual(Set(configurations), ["Content", "Learner"])
    }

    // 2. Round trips
    func testVocabularyRoundTripPreservesEveryField() async throws {
        _ = try await importSample()
        let repository = CoreDataVocabularyRepository(controller: controller)
        for expected in SampleContent.vocabulary {
            let stored = try await repository.item(id: expected.id)
            XCTAssertEqual(stored, expected, expected.id.rawValue)
        }
    }

    func testGrammarAndQuestionRoundTrip() async throws {
        _ = try await importSample()
        let grammar = CoreDataGrammarRepository(controller: controller)
        for expected in SampleContent.grammar {
            let stored = try await grammar.pattern(id: expected.id)
            XCTAssertEqual(stored, expected)
        }
        let questions = CoreDataQuestionRepository(controller: controller)
        for expected in SampleContent.questions {
            let stored = try await questions.question(id: expected.id)
            XCTAssertEqual(stored, expected)
        }
        let ordered = try await questions.questions(ids: [QuestionID("question.sample.0003"), QuestionID("question.sample.0001")])
        XCTAssertEqual(ordered.map(\.id.rawValue), ["question.sample.0003", "question.sample.0001"], "caller order preserved")
    }

    // 3. Search
    func testSearchAcrossScripts() async throws {
        _ = try await importSample()
        let repository = CoreDataVocabularyRepository(controller: controller)
        async let khmer = repository.search("ទឹក", filter: .all)
        async let english = repository.search("FRIEND", filter: .all)
        async let romanization = repository.search("hakgyo", filter: .all)
        async let hangul = repository.search("선생", filter: .all)
        let results = try await (khmer, english, romanization, hangul)
        XCTAssertEqual(results.0.map(\.hangul), ["물"])
        XCTAssertEqual(results.1.map(\.hangul), ["친구"])
        XCTAssertEqual(results.2.map(\.hangul), ["학교"])
        XCTAssertEqual(results.3.map(\.hangul), ["선생님"])
    }

    // 4. Filters
    func testFilterByLevelAndPartOfSpeech() async throws {
        _ = try await importSample()
        let repository = CoreDataVocabularyRepository(controller: controller)
        let level3 = try await repository.items(matching: VocabularyFilter(levels: [.level3]))
        XCTAssertEqual(Set(level3.map(\.hangul)), ["회의", "경험"])
        let verbs = try await repository.items(matching: VocabularyFilter(partsOfSpeech: [.verb]))
        XCTAssertEqual(Set(verbs.map(\.hangul)), ["가다", "먹다"])
        let count = try await repository.count()
        XCTAssertEqual(count, SampleContent.vocabulary.count)
    }

    // 5. Attempts
    func testAttemptDuplicateGuardAndDenormalizedTarget() async throws {
        _ = try await importSample()
        let questions = CoreDataQuestionRepository(controller: controller)
        let repository = CoreDataAttemptRepository(controller: controller, questions: questions)
        let attempt = Attempt(
            id: AttemptID("a1"), sessionID: StudySessionID("s1"), questionID: QuestionID("question.sample.0001"),
            selectedOptionID: OptionID("o1"), isCorrect: true, answeredAt: Date(), responseTime: 2.5
        )
        try await repository.record(attempt)

        do {
            try await repository.record(Attempt(
                id: AttemptID("a2"), sessionID: StudySessionID("s1"), questionID: QuestionID("question.sample.0001"),
                selectedOptionID: OptionID("o2"), isCorrect: false, answeredAt: Date(), responseTime: 1
            ))
            XCTFail("expected duplicateSubmission")
        } catch let error as DomainError {
            XCTAssertEqual(error, .duplicateSubmission(questionID: QuestionID("question.sample.0001")))
        }

        try await repository.record(Attempt(
            id: AttemptID("a3"), sessionID: StudySessionID("s2"), questionID: QuestionID("question.sample.0001"),
            selectedOptionID: OptionID("o2"), isCorrect: false, answeredAt: Date(), responseTime: 1
        ))
        let summary = try await repository.summary()
        XCTAssertEqual(summary, AttemptSummary(total: 2, correct: 1))

        let forQuestion = try await repository.attempts(forQuestion: QuestionID("question.sample.0001"))
        XCTAssertEqual(forQuestion.count, 2)
        XCTAssertEqual(forQuestion.first?.responseTime, 2.5)

        let context = controller.newBackgroundContext()
        let target: (String, String) = try await context.perform {
            let request = NSFetchRequest<CDAttempt>(entityName: "CDAttempt")
            request.predicate = NSPredicate(format: "id == %@", "a1")
            let row = try XCTUnwrap(context.fetch(request).first)
            return (row.targetKind, row.targetID)
        }
        XCTAssertEqual(target.0, "vocabulary")
        XCTAssertEqual(target.1, "vocab.sample.0001")
    }

    // 6. Sessions
    func testSessionSaveResumeFinish() async throws {
        let repository = CoreDataStudySessionRepository(controller: controller)
        let ids = (1...3).map { QuestionID("q\($0)") }
        var session = StudySession(id: StudySessionID("s1"), mode: .quiz, startedAt: Date(timeIntervalSince1970: 1_000), questionIDs: ids, deviceName: "test")
        try await repository.save(session)

        session.currentIndex = 2
        try await repository.save(session)
        let unfinished = try await repository.unfinishedSession()
        XCTAssertEqual(unfinished?.currentIndex, 2)
        XCTAssertEqual(unfinished?.questionIDs, ids)

        session.endedAt = Date(timeIntervalSince1970: 2_000)
        try await repository.save(session)
        let afterFinish = try await repository.unfinishedSession()
        XCTAssertNil(afterFinish)
        let all = try await repository.sessions(limit: 10)
        XCTAssertEqual(all.count, 1)
        XCTAssertTrue(all[0].isFinished)
    }

    // 7. Bookmarks
    func testBookmarkAddRemoveDedupe() async throws {
        let repository = CoreDataBookmarkRepository(controller: controller)
        let target = LearningTarget.vocabulary(VocabularyID("vocab.sample.0001"))
        try await repository.add(Bookmark(id: BookmarkID("b1"), target: target, createdAt: Date()))
        try await repository.add(Bookmark(id: BookmarkID("b2"), target: target, createdAt: Date()))
        let all = try await repository.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id.rawValue, "b1")
        let contains = try await repository.contains(target: target)
        XCTAssertTrue(contains)
        try await repository.remove(target: target)
        let after = try await repository.contains(target: target)
        XCTAssertFalse(after)
    }

    // 8. Review schedules
    func testScheduleUpsertReplacesAndDueRespectsLimit() async throws {
        let repository = CoreDataReviewScheduleRepository(controller: controller)
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        for (index, offset) in [-2.0, -1.0, 0.0, 1.0].enumerated() {
            try await repository.upsert(ReviewSchedule(
                id: ReviewScheduleID("r\(index)"),
                target: .vocabulary(VocabularyID("v\(index)")),
                nextReviewDate: today.addingTimeInterval(offset * 86_400)
            ))
        }
        try await repository.upsert(ReviewSchedule(
            id: ReviewScheduleID("replaced"), target: .vocabulary(VocabularyID("v0")),
            easeFactor: 2.8, intervalDays: 6, repetitions: 2, nextReviewDate: today.addingTimeInterval(5 * 86_400)
        ))
        let v0 = try await repository.schedule(for: .vocabulary(VocabularyID("v0")))
        XCTAssertEqual(v0?.id.rawValue, "r0", "upsert keeps the original row id")
        XCTAssertEqual(v0?.repetitions, 2)
        let due = try await repository.due(onOrBefore: today, limit: 1)
        XCTAssertEqual(due.map(\.id.rawValue), ["r1"])
    }

    // 9. Content import lifecycle
    func testImportIsIdempotentAndUpgradesWhileAttemptsSurvive() async throws {
        let store = CoreDataContentStore(controller: controller)
        let first = try await store.apply(SampleContent.package)
        XCTAssertFalse(first.skipped)
        XCTAssertEqual(first.inserted, SampleContent.vocabulary.count + SampleContent.grammar.count + SampleContent.questions.count)

        let again = try await store.apply(SampleContent.package)
        XCTAssertTrue(again.skipped)

        let questions = CoreDataQuestionRepository(controller: controller)
        let attempts = CoreDataAttemptRepository(controller: controller, questions: questions)
        try await attempts.record(Attempt(
            id: AttemptID("a1"), sessionID: StudySessionID("s1"), questionID: QuestionID("question.sample.0007"),
            selectedOptionID: OptionID("o1"), isCorrect: true, answeredAt: Date(), responseTime: 1
        ))

        var changed = SampleContent.vocabulary[0]
        changed.meaning = Gloss(english: "school (updated)", khmer: "សាលារៀន")
        let upgraded = ContentPackage(
            version: SampleContent.version + 1,
            vocabulary: [changed] + SampleContent.vocabulary.dropFirst(),
            grammar: SampleContent.grammar,
            questions: Array(SampleContent.questions.dropLast())   // retires question 7
        )
        let result = try await store.apply(upgraded)
        XCTAssertFalse(result.skipped)
        XCTAssertEqual(result.retired, 1)
        XCTAssertEqual(result.inserted, 0)

        let vocabulary = CoreDataVocabularyRepository(controller: controller)
        let updatedItem = try await vocabulary.item(id: changed.id)
        XCTAssertEqual(updatedItem?.meaning.english, "school (updated)")
        XCTAssertEqual(updatedItem?.examples.count, 1, "examples replaced, not duplicated")

        let activeCount = try await questions.count()
        XCTAssertEqual(activeCount, SampleContent.questions.count - 1)
        let retiredStillReadable = try await questions.question(id: QuestionID("question.sample.0007"))
        XCTAssertNotNil(retiredStillReadable, "retired questions stay readable for history")
        let survivingAttempts = try await attempts.attempts(forQuestion: QuestionID("question.sample.0007"))
        XCTAssertEqual(survivingAttempts.count, 1)
        let version = try await store.installedContentVersion()
        XCTAssertEqual(version, SampleContent.version + 1)
    }

    func testInvalidPackageIsRejectedBeforeWriting() async throws {
        let store = CoreDataContentStore(controller: controller)
        var broken = SampleContent.questions[0]
        broken.correctOptionID = OptionID("missing")
        let package = ContentPackage(version: 99, vocabulary: SampleContent.vocabulary, grammar: [], questions: [broken])
        do {
            _ = try await store.apply(package)
            XCTFail("expected invalidPackage")
        } catch let error as DomainError {
            guard case .invalidPackage = error else { return XCTFail("unexpected \(error)") }
        }
        let version = try await store.installedContentVersion()
        XCTAssertNil(version)
    }

    // Notes and settings
    func testNotesAndSettings() async throws {
        let notes = CoreDataLearnerNoteRepository(controller: controller)
        let target = LearningTarget.grammar(GrammarID("grammar.sample.0001"))
        try await notes.upsert(LearnerNote(id: LearnerNoteID("n1"), target: target, text: "  remember vowel harmony  ", modifiedAt: Date()))
        let stored = try await notes.note(for: target)
        XCTAssertEqual(stored?.text, "remember vowel harmony")
        try await notes.upsert(LearnerNote(id: LearnerNoteID("n1"), target: target, text: "   ", modifiedAt: Date()))
        let removed = try await notes.note(for: target)
        XCTAssertNil(removed, "empty text removes the note")

        let settings = CoreDataLearnerSettingsRepository(controller: controller)
        let initial = try await settings.load()
        XCTAssertEqual(initial, .default)
        let custom = LearnerSettings(glossLanguage: .khmer, dailyGoal: 30, reviewLimit: 40, pronunciationEnabled: false, modifiedAt: Date(timeIntervalSince1970: 5))
        try await settings.save(custom)
        let loaded = try await settings.load()
        XCTAssertEqual(loaded, custom)
    }

    func testResetLearnerDataKeepsContent() async throws {
        _ = try await importSample()
        let bookmarks = CoreDataBookmarkRepository(controller: controller)
        try await bookmarks.add(Bookmark(id: BookmarkID("b"), target: .vocabulary(VocabularyID("vocab.sample.0001")), createdAt: Date()))
        try await controller.resetLearnerData()
        let remaining = try await bookmarks.all()
        XCTAssertTrue(remaining.isEmpty)
        let words = try await CoreDataVocabularyRepository(controller: controller).count()
        XCTAssertEqual(words, SampleContent.vocabulary.count)
    }
}
