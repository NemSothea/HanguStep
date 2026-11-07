import Domain
@testable import Persistence
import XCTest

/// Phase 9, NFR-3 proxies on the Mac test host: vocabulary search over 10 000
/// entries and answer feedback latency. Device numbers are recorded in QA_REPORT.md.
final class PerformanceTests: XCTestCase {
    private static func syntheticVocabulary(count: Int) -> [VocabularyItem] {
        (0..<count).map { n in
            VocabularyItem(
                id: VocabularyID(String(format: "vocab.perf.%05d", n)),
                hangul: "단어\(n)", romanization: "daneo\(n)", hanja: nil,
                partOfSpeech: PartOfSpeech.allCases[n % PartOfSpeech.allCases.count],
                level: TOPIKLevel.allCases[n % TOPIKLevel.allCases.count], category: "perf",
                meaning: Gloss(english: "word number \(n)", khmer: "ពាក្យ \(n)"),
                examples: [ExampleSentence(korean: "단어\(n)을 배워요.", translation: Gloss(english: "learn word \(n)", khmer: "រៀនពាក្យ \(n)"))],
                source: SampleContent.source, contentVersion: 1
            )
        }
    }

    func testVocabularySearchOverTenThousandEntriesStaysUnder150ms() async throws {
        let controller = try PersistenceController(mode: .inMemory)
        let package = ContentPackage(version: 1, vocabulary: Self.syntheticVocabulary(count: 10_000), grammar: [], questions: [])
        _ = try await CoreDataContentStore(controller: controller).apply(package)
        let repository = CoreDataVocabularyRepository(controller: controller)

        var worst: TimeInterval = 0
        for query in ["daneo99", "ពាក្យ 12", "단어777", "word number 5"] {
            let start = ContinuousClock.now
            let results = try await repository.search(query, filter: .all)
            let elapsed = ContinuousClock.now - start
            XCTAssertFalse(results.isEmpty, query)
            worst = max(worst, Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
        }
        print("PERF vocabulary search worst case: \(Int(worst * 1000)) ms over 10 000 entries")
        XCTAssertLessThan(worst, 0.150, "NFR-3: search under 150 ms")
    }

    func testAnswerFeedbackStaysUnder100ms() async throws {
        let controller = try PersistenceController(mode: .inMemory)
        _ = try await CoreDataContentStore(controller: controller).apply(SampleContent.package)
        let sessions = CoreDataStudySessionRepository(controller: controller)
        let attempts = CoreDataAttemptRepository(controller: controller)
        let schedules = CoreDataReviewScheduleRepository(controller: controller)
        let start = StartQuizSession(
            questions: CoreDataQuestionRepository(controller: controller), sessions: sessions, attempts: attempts,
            schedules: schedules, settings: CoreDataLearnerSettingsRepository(controller: controller), deviceName: "perf"
        )
        let submit = SubmitAnswer(sessions: sessions, attempts: attempts, schedules: schedules)
        let snapshot = try await start.execute(QuizConfiguration(pool: .mixed, count: 5))

        var worst: TimeInterval = 0
        for question in snapshot.questions {
            let clock = ContinuousClock.now
            _ = try await submit.execute(session: snapshot.session, question: question, selectedOptionID: question.correctOptionID, responseTime: 1)
            let elapsed = ContinuousClock.now - clock
            worst = max(worst, Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
        }
        print("PERF answer feedback worst case: \(String(format: "%.2f", worst * 1000)) ms")
        XCTAssertLessThan(worst, 0.100, "NFR-3: feedback under 100 ms")
    }
}
