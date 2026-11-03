import Domain
@testable import Persistence
import XCTest

final class LibraryUseCaseTests: XCTestCase {
    private let clock = FixedDateProvider(Date(timeIntervalSince1970: 1_700_000_000))

    func testToggleBookmarkRoundTrip() async throws {
        let bookmarks = InMemoryBookmarkRepository()
        let toggle = ToggleBookmark(bookmarks: bookmarks, dates: clock)
        let target = LearningTarget.vocabulary(VocabularyID("vocab.sample.0001"))
        let on = try await toggle.execute(target: target)
        XCTAssertTrue(on)
        let off = try await toggle.execute(target: target)
        XCTAssertFalse(off)
        let all = try await bookmarks.all()
        XCTAssertTrue(all.isEmpty)
    }

    func testListBookmarksJoinsContent() async throws {
        let bookmarks = InMemoryBookmarkRepository()
        try await bookmarks.add(Bookmark(id: BookmarkID("b1"), target: .vocabulary(VocabularyID("vocab.sample.0003")), createdAt: clock.now()))
        try await bookmarks.add(Bookmark(id: BookmarkID("b2"), target: .grammar(GrammarID("grammar.sample.0001")), createdAt: clock.now().addingTimeInterval(10)))
        try await bookmarks.add(Bookmark(id: BookmarkID("b3"), target: .vocabulary(VocabularyID("missing")), createdAt: clock.now()))
        let list = try await ListBookmarks(
            bookmarks: bookmarks,
            vocabulary: InMemoryVocabularyRepository(items: SampleContent.vocabulary),
            grammar: InMemoryGrammarRepository(patterns: SampleContent.grammar)
        ).execute()
        XCTAssertEqual(list.map(\.title), ["-아/어요", "물"], "newest first, missing content skipped")
    }

    func testVocabularyDetailIncludesBookmarkAndNote() async throws {
        let bookmarks = InMemoryBookmarkRepository()
        let notes = InMemoryLearnerNoteRepository()
        let id = VocabularyID("vocab.sample.0002")
        _ = try await ToggleBookmark(bookmarks: bookmarks, dates: clock).execute(target: .vocabulary(id))
        let saved = try await SaveNote(notes: notes, dates: clock).execute(target: .vocabulary(id), text: " 친 = close ")
        XCTAssertEqual(saved?.text, "친 = close")
        let detail = try await GetVocabularyDetail(
            vocabulary: InMemoryVocabularyRepository(items: SampleContent.vocabulary), bookmarks: bookmarks, notes: notes
        ).execute(id: id)
        XCTAssertEqual(detail.item.hangul, "친구")
        XCTAssertTrue(detail.isBookmarked)
        XCTAssertEqual(detail.note?.text, "친 = close")

        let removed = try await SaveNote(notes: notes, dates: clock).execute(target: .vocabulary(id), text: "")
        XCTAssertNil(removed)
    }

    func testGrammarDetailCollectsRelatedAndPractice() async throws {
        let detail = try await GetGrammarDetail(
            grammar: InMemoryGrammarRepository(patterns: SampleContent.grammar),
            questions: InMemoryQuestionRepository(questions: SampleContent.questions),
            bookmarks: InMemoryBookmarkRepository(),
            notes: InMemoryLearnerNoteRepository()
        ).execute(id: GrammarID("grammar.sample.0002"))
        XCTAssertEqual(detail.related.map(\.id.rawValue), ["grammar.sample.0001"])
        XCTAssertEqual(detail.practiceQuestions.map(\.id.rawValue), ["question.sample.0006"])
        XCTAssertFalse(detail.isBookmarked)
    }

    func testMissingContentThrowsNotFound() async throws {
        do {
            _ = try await GetVocabularyDetail(
                vocabulary: InMemoryVocabularyRepository(items: []), bookmarks: InMemoryBookmarkRepository(), notes: InMemoryLearnerNoteRepository()
            ).execute(id: VocabularyID("x"))
            XCTFail("expected notFound")
        } catch let error as DomainError {
            XCTAssertEqual(error, .notFound(entity: "VocabularyItem", id: "x"))
        }
    }

    func testSaveSettingsClampsAndStamps() async throws {
        let repository = InMemoryLearnerSettingsRepository()
        var settings = LearnerSettings.default
        settings.dailyGoal = 0
        settings.glossLanguage = .khmer
        let saved = try await SaveSettings(repository: repository, dates: clock).execute(settings)
        XCTAssertEqual(saved.dailyGoal, 1)
        XCTAssertEqual(saved.modifiedAt, clock.now())
        let loaded = try await LoadSettings(repository: repository).execute()
        XCTAssertEqual(loaded.glossLanguage, .khmer)
    }
}
