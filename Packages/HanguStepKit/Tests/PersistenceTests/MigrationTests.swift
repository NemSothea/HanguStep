import Domain
@testable import Persistence
import XCTest

/// Opens learner store fixtures written by earlier model versions with the current model.
/// Add a fixture whenever a model version ships (see DATABASE_SCHEMA.md §7).
final class MigrationTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hangustep-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testOnDiskStoresOpenAndPersistAcrossRelaunch() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try PersistenceController(mode: .onDisk(directory: directory))
        try await CoreDataBookmarkRepository(controller: first).add(
            Bookmark(id: BookmarkID("b1"), target: .vocabulary(VocabularyID("vocab.sample.0001")), createdAt: Date())
        )
        _ = try await CoreDataContentStore(controller: first).apply(SampleContent.package)

        let second = try PersistenceController(mode: .onDisk(directory: directory))
        let bookmarks = try await CoreDataBookmarkRepository(controller: second).all()
        XCTAssertEqual(bookmarks.map(\.id.rawValue), ["b1"])
        let version = try await CoreDataContentStore(controller: second).installedContentVersion()
        XCTAssertEqual(version, SampleContent.version)
    }

    func testLearnerFixtureV1OpensWithCurrentModel() async throws {
        guard let fixture = Bundle.module.url(forResource: "Learner-v1", withExtension: "sqlite", subdirectory: "Fixtures") else {
            return XCTFail("missing fixture Learner-v1.sqlite")
        }
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.copyItem(at: fixture, to: directory.appendingPathComponent("Learner.sqlite"))

        let controller = try PersistenceController(mode: .onDisk(directory: directory))
        let bookmarks = try await CoreDataBookmarkRepository(controller: controller).all()
        XCTAssertEqual(bookmarks.map(\.id.rawValue), ["fixture-bookmark"])
        let settings = try await CoreDataLearnerSettingsRepository(controller: controller).load()
        XCTAssertEqual(settings.dailyGoal, 25)
        let session = try await CoreDataStudySessionRepository(controller: controller).session(id: StudySessionID("fixture-session"))
        XCTAssertEqual(session?.questionIDs.map(\.rawValue), ["question.sample.0001", "question.sample.0002"])
    }
}
