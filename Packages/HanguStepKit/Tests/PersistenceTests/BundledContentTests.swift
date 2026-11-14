import Domain
@testable import Persistence
import XCTest

/// The library that ships in the app bundle (AC-10) and its upgrade path from the Phase 3 sample data.
final class BundledContentTests: XCTestCase {
    func testBundledLibraryLoadsAndValidates() throws {
        let result = try BundledContent.load()
        let package = result.package
        XCTAssertTrue(package.validate().isEmpty)
        XCTAssertGreaterThan(package.version, SampleContent.version, "bundle must supersede the sample data")
        XCTAssertGreaterThanOrEqual(package.vocabulary.count, 200)
        XCTAssertGreaterThanOrEqual(package.grammar.count, 30)
        XCTAssertGreaterThanOrEqual(package.questions.count, 500)
        XCTAssertFalse(result.source.license.isEmpty)
        XCTAssertFalse(result.source.name.isEmpty)
    }

    func testEveryWordAndPatternIsCoveredByQuestions() throws {
        let package = try BundledContent.load().package
        let targets = Set(package.questions.compactMap(\.learningTarget))
        for item in package.vocabulary {
            XCTAssertTrue(targets.contains(.vocabulary(item.id)), "\(item.id.rawValue) has no question")
        }
        let grammarTargets = Set(package.questions.compactMap(\.relatedGrammarID))
        for pattern in package.grammar {
            XCTAssertTrue(grammarTargets.contains(pattern.id), "\(pattern.id.rawValue) has no question")
        }
        XCTAssertEqual(Set(package.vocabulary.map(\.level)), [.level1, .level2, .level3, .level4])
        for kind in QuestionKind.allCases {
            XCTAssertTrue(package.questions.contains { $0.kind == kind }, "no \(kind) questions")
        }
    }

    func testEveryItemCarriesSourceAndLicense() throws {
        let package = try BundledContent.load().package
        for item in package.vocabulary { XCTAssertFalse(item.source.license.isEmpty, item.id.rawValue) }
        for pattern in package.grammar { XCTAssertFalse(pattern.source.license.isEmpty, pattern.id.rawValue) }
        for question in package.questions { XCTAssertFalse(question.source.license.isEmpty, question.id.rawValue) }
    }

    /// ADR-010: Wiktionary meanings are CC BY-SA and must be attributed with a link.
    func testImportedItemsAreAttributedWithLink() throws {
        let package = try BundledContent.load().package
        let imported = package.vocabulary.filter { $0.source.origin == .imported }
        XCTAssertFalse(imported.isEmpty)
        for item in imported {
            XCTAssertEqual(item.source.license, "CC BY-SA 4.0", item.id.rawValue)
            XCTAssertNotNil(item.source.url.flatMap(URL.init(string:)), item.id.rawValue)
        }
        XCTAssertEqual(package.importedCredits, ["Wiktionary (meaning); HanguStep (examples, Khmer) · CC BY-SA 4.0"])
    }

    func testBundledLibraryReplacesSampleDataAndKeepsAttempts() async throws {
        let controller = try PersistenceController(mode: .inMemory)
        let store = CoreDataContentStore(controller: controller)
        _ = try await store.apply(SampleContent.package)
        let attempts = CoreDataAttemptRepository(controller: controller)
        try await attempts.record(Attempt(
            id: AttemptID("a1"), sessionID: StudySessionID("s1"), questionID: QuestionID("question.sample.0001"),
            selectedOptionID: OptionID("o1"), isCorrect: true, answeredAt: Date(), responseTime: 1
        ))

        let library = try BundledContent.load()
        let result = try await store.apply(library.package)
        XCTAssertFalse(result.skipped)
        XCTAssertEqual(result.retired, SampleContent.vocabulary.count + SampleContent.grammar.count + SampleContent.questions.count)
        XCTAssertEqual(result.inserted, library.package.vocabulary.count + library.package.grammar.count + library.package.questions.count)
        let version = try await store.installedContentVersion()
        XCTAssertEqual(version, library.package.version)

        let questions = CoreDataQuestionRepository(controller: controller)
        let active = try await questions.count()
        XCTAssertEqual(active, library.package.questions.count)
        let retired = try await questions.question(id: QuestionID("question.sample.0001"))
        XCTAssertNotNil(retired, "retired sample question stays readable for history")
        let surviving = try await attempts.attempts(forQuestion: QuestionID("question.sample.0001"))
        XCTAssertEqual(surviving.count, 1)

        let again = try await store.apply(library.package)
        XCTAssertTrue(again.skipped, "same version is not re-imported")
    }

    // MARK: Warm launch (summary.json)

    func testSummaryMatchesTheFullLibrary() throws {
        let summary = try XCTUnwrap(BundledContent.summary(), "summary.json missing: run content-lint generate-questions")
        XCTAssertEqual(summary, try BundledContent.load().info, "summary.json is stale: run content-lint generate-questions")
    }

    func testWarmLaunchUsesSummaryAndStaleStoreStillImports() async throws {
        let controller = try PersistenceController(mode: .inMemory)
        let first = try await BundledContentInstaller.installIfNeeded(controller: controller)
        let installedVersion = try await CoreDataContentStore(controller: controller).installedContentVersion()
        XCTAssertEqual(installedVersion, first.version)
        let warm = try await BundledContentInstaller.installIfNeeded(controller: controller)
        XCTAssertEqual(warm, first, "warm launch reports the same library")

        // A store holding an older library is brought up to date, never skipped.
        let older = try PersistenceController(mode: .inMemory)
        _ = try await CoreDataContentStore(controller: older).apply(SampleContent.package)
        let upgraded = try await BundledContentInstaller.installIfNeeded(controller: older)
        XCTAssertEqual(upgraded.version, first.version)
        let upgradedVersion = try await CoreDataContentStore(controller: older).installedContentVersion()
        XCTAssertEqual(upgradedVersion, first.version)
    }

    func testEveryListeningQuestionHasARecording() throws {
        let audio = BundledListeningAudio()
        let listening = try BundledContent.load().package.questions.filter { $0.kind == .listening }
        XCTAssertFalse(listening.isEmpty)
        for question in listening {
            XCTAssertNotNil(audio.audioURL(for: question.id), "\(question.id.rawValue) has no recording")
        }
    }
}

