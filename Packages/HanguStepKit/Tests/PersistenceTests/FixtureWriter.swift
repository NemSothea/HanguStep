import Domain
@testable import Persistence
import XCTest

/// Not a test. Run with HANGUSTEP_WRITE_FIXTURE=<output dir> to regenerate a learner
/// fixture for the current model version, then copy it into Tests/PersistenceTests/Fixtures.
final class FixtureWriter: XCTestCase {
    func testWriteFixtureIfRequested() async throws {
        guard let output = ProcessInfo.processInfo.environment["HANGUSTEP_WRITE_FIXTURE"] else {
            throw XCTSkip("set HANGUSTEP_WRITE_FIXTURE to write a fixture")
        }
        let directory = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = try PersistenceController(mode: .onDisk(directory: directory))
        try await CoreDataBookmarkRepository(controller: controller).add(
            Bookmark(id: BookmarkID("fixture-bookmark"), target: .vocabulary(VocabularyID("vocab.sample.0001")), createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        )
        var settings = LearnerSettings.default
        settings.dailyGoal = 25
        try await CoreDataLearnerSettingsRepository(controller: controller).save(settings)
        try await CoreDataStudySessionRepository(controller: controller).save(StudySession(
            id: StudySessionID("fixture-session"), mode: .quiz, startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            questionIDs: [QuestionID("question.sample.0001"), QuestionID("question.sample.0002")], deviceName: "fixture"
        ))
        // v2: writing attempt with feedback (ADR-012).
        try await CoreDataWritingAttemptRepository(controller: controller).save(WritingAttempt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000053")!, taskID: WritingTaskID("w.53.001"), text: "fixture 답안",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            feedback: WritingFeedback(providerName: "fixture", estimatedScore: 20, maxScore: 30, criteria: [], corrections: [], summary: "fixture", language: .english)
        ))
        // Checkpoint the WAL so the fixture is a single file.
        let coordinator = controller.container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            guard let url = store.url, store.configurationName == "Learner" else { continue }
            try coordinator.remove(store)
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: "Learner", at: url, options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]])
        }
    }
}
