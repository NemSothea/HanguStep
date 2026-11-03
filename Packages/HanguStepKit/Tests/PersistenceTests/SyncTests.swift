import CloudKit
import CoreData
import Domain
@testable import Persistence
import XCTest

/// Phase 6: store options, fallback and post-import deduplication (PRD FR-S3, FR-S6, risk R3).
final class SyncTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("HanguStepSyncTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        // The monitor's best-effort history purge is queued on a background context;
        // let it drain before the store files disappear so Core Data logs no I/O errors.
        try await Task.sleep(for: .milliseconds(150))
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: Store descriptions

    func testLearnerStoreTracksHistoryAndPostsRemoteChangesOnDisk() throws {
        let description = PersistenceController.learnerDescription(mode: .onDisk(directory: directory), sync: .off)
        XCTAssertEqual(description.options[NSPersistentHistoryTrackingKey] as? NSNumber, true)
        XCTAssertEqual(description.options[NSPersistentStoreRemoteChangeNotificationPostOptionKey] as? NSNumber, true)
        XCTAssertNil(description.cloudKitContainerOptions)
        let content = PersistenceController.description(for: PersistenceController.contentConfiguration, mode: .onDisk(directory: directory))
        XCTAssertNil(content.options[NSPersistentHistoryTrackingKey], "content store is never mirrored")
    }

    func testCloudKitOptionsOnlyOnLearnerStore() {
        let description = PersistenceController.learnerDescription(mode: .onDisk(directory: directory), sync: .cloudKit(containerIdentifier: "iCloud.test"))
        XCTAssertEqual(description.cloudKitContainerOptions?.containerIdentifier, "iCloud.test")
        XCTAssertEqual(description.cloudKitContainerOptions?.databaseScope, .private)
        let memory = PersistenceController.learnerDescription(mode: .inMemory, sync: .cloudKit(containerIdentifier: "iCloud.test"))
        XCTAssertNil(memory.cloudKitContainerOptions, "in-memory stores never sync")
    }

    func testOnDiskControllerOpensWithSyncOffAndKeepsLearnerData() async throws {
        let controller = try PersistenceController(mode: .onDisk(directory: directory), sync: .off)
        XCTAssertFalse(controller.isCloudKitEnabled)
        XCTAssertNil(controller.syncFallbackError)
        let bookmarks = CoreDataBookmarkRepository(controller: controller)
        try await bookmarks.add(Bookmark(id: BookmarkID("b"), target: .vocabulary(VocabularyID("v")), createdAt: .now))
        let reopened = try PersistenceController(mode: .onDisk(directory: directory), sync: .off)
        let stored = try await CoreDataBookmarkRepository(controller: reopened).contains(target: .vocabulary(VocabularyID("v")))
        XCTAssertTrue(stored)
    }

    /// Without an iCloud entitlement the CloudKit store either opens in CloudKit mode
    /// (and fails later in events) or refuses to open. Either way the app must start
    /// with its local data (PRD FR-S3).
    func testCloudKitRequestNeverPreventsStartup() async throws {
        let controller = try PersistenceController(mode: .onDisk(directory: directory), sync: .cloudKit(containerIdentifier: "iCloud.com.nemsothea.hangustep.tests"))
        let configurations = controller.container.persistentStoreCoordinator.persistentStores.compactMap(\.configurationName)
        XCTAssertEqual(Set(configurations), ["Content", "Learner"])
        if !controller.isCloudKitEnabled {
            XCTAssertNotNil(controller.syncFallbackError, "fallback must explain why sync is off")
        }
        let monitor = SyncMonitor(controller: controller)
        XCTAssertEqual(monitor.currentState.isEnabled, controller.isCloudKitEnabled)
        XCTAssertEqual(monitor.currentState.lastError, controller.syncFallbackError)
    }

    func testForcedLearnerFailureFallsBackToLocalOnly() async throws {
        let controller = try PersistenceController(mode: .onDisk(directory: directory), sync: .cloudKit(containerIdentifier: "iCloud.test"), failLearnerStoreOnce: true)
        XCTAssertEqual(controller.sync, .off)
        XCTAssertFalse(controller.isCloudKitEnabled)
        XCTAssertEqual(controller.syncFallbackError, "simulated CloudKit store failure")
        let stores = controller.container.persistentStoreCoordinator.persistentStores.compactMap(\.configurationName)
        XCTAssertEqual(stores.sorted(), ["Content", "Learner"], "exactly one of each store after fallback")
        let monitor = SyncMonitor(controller: controller)
        XCTAssertFalse(monitor.currentState.isEnabled)
        XCTAssertEqual(monitor.currentState.lastError, "simulated CloudKit store failure")
    }

    func testStartAndStopAreIdempotent() throws {
        let controller = try PersistenceController(mode: .onDisk(directory: directory), sync: .off)
        let monitor = SyncMonitor(controller: controller)
        monitor.start()
        monitor.start()
        monitor.stop()
        monitor.stop()
        monitor.start()
        monitor.stop()
    }

    // MARK: Deduplication

    private func makeController() throws -> PersistenceController {
        try PersistenceController(mode: .inMemory)
    }

    private func insert(_ entity: String, _ values: [String: Any], in controller: PersistenceController) async throws {
        let context = controller.newBackgroundContext()
        try await context.perform {
            let row = NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
            for (key, value) in values { row.setValue(value, forKey: key) }
            try context.save()
        }
    }

    private func count(_ entity: String, in controller: PersistenceController) async throws -> Int {
        let context = controller.newBackgroundContext()
        return try await context.perform { try context.count(for: NSFetchRequest<NSManagedObject>(entityName: entity)) }
    }

    func testDuplicateBookmarksKeepLatestModified() async throws {
        let controller = try makeController()
        let old = Date(timeIntervalSince1970: 1_000)
        let new = Date(timeIntervalSince1970: 2_000)
        try await insert("CDBookmark", ["id": "mac", "targetKind": "vocabulary", "targetID": "v1", "createdAt": old, "modifiedAt": old], in: controller)
        try await insert("CDBookmark", ["id": "phone", "targetKind": "vocabulary", "targetID": "v1", "createdAt": new, "modifiedAt": new], in: controller)
        try await insert("CDBookmark", ["id": "other", "targetKind": "vocabulary", "targetID": "v2", "createdAt": old, "modifiedAt": old], in: controller)

        let report = try await LearnerDeduplicator(controller: controller).run()
        XCTAssertEqual(report.removed["CDBookmark"], 1)
        let bookmarkCount = try await count("CDBookmark", in: controller)
        XCTAssertEqual(bookmarkCount, 2)
        let survivors = try await CoreDataBookmarkRepository(controller: controller).all()
        XCTAssertEqual(Set(survivors.map(\.id.rawValue)), ["phone", "other"])
    }

    func testDuplicateSchedulesKeepLatestReview() async throws {
        let controller = try makeController()
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 5_000)
        // The Mac row was modified later (sync bookkeeping) but reviewed earlier; the review wins.
        try await insert("CDReviewSchedule", ["id": "mac", "targetKind": "vocabulary", "targetID": "v1", "easeFactor": 2.5, "intervalDays": Int32(1), "repetitions": Int32(1), "nextReviewDate": late, "lastReviewedAt": early, "modifiedAt": late], in: controller)
        try await insert("CDReviewSchedule", ["id": "phone", "targetKind": "vocabulary", "targetID": "v1", "easeFactor": 2.6, "intervalDays": Int32(6), "repetitions": Int32(2), "nextReviewDate": late, "lastReviewedAt": late, "modifiedAt": early], in: controller)

        let report = try await LearnerDeduplicator(controller: controller).run()
        XCTAssertEqual(report.removed["CDReviewSchedule"], 1)
        let survivor = try await CoreDataReviewScheduleRepository(controller: controller).schedule(for: .vocabulary(VocabularyID("v1")))
        XCTAssertEqual(survivor?.id.rawValue, "phone")
        XCTAssertEqual(survivor?.repetitions, 2)
    }

    func testDuplicateAttemptsKeepFirstAnswerAndSessionsKeepLatest() async throws {
        let controller = try makeController()
        let first = Date(timeIntervalSince1970: 1_000)
        let second = Date(timeIntervalSince1970: 1_500)
        try await insert("CDAttempt", ["id": "a1", "sessionID": "s", "questionID": "q", "selectedOptionID": "o1", "isCorrect": true, "answeredAt": first, "responseTime": 1.0], in: controller)
        try await insert("CDAttempt", ["id": "a2", "sessionID": "s", "questionID": "q", "selectedOptionID": "o2", "isCorrect": false, "answeredAt": second, "responseTime": 1.0], in: controller)
        try await insert("CDAttempt", ["id": "a3", "sessionID": "s", "questionID": "q2", "selectedOptionID": "o1", "isCorrect": true, "answeredAt": second, "responseTime": 1.0], in: controller)
        try await insert("CDStudySession", ["id": "s", "mode": "quiz", "startedAt": first, "questionIDs": "[\"q\",\"q2\"]", "currentIndex": Int16(1), "deviceName": "mac", "modifiedAt": first], in: controller)
        try await insert("CDStudySession", ["id": "s", "mode": "quiz", "startedAt": first, "questionIDs": "[\"q\",\"q2\"]", "currentIndex": Int16(2), "deviceName": "phone", "modifiedAt": second], in: controller)
        try await insert("CDLearnerSettings", ["id": "settings", "glossLanguage": "en", "dailyGoal": Int32(20), "reviewLimit": Int32(50), "pronunciationEnabled": true, "modifiedAt": first], in: controller)
        try await insert("CDLearnerSettings", ["id": "settings", "glossLanguage": "km", "dailyGoal": Int32(10), "reviewLimit": Int32(50), "pronunciationEnabled": true, "modifiedAt": second], in: controller)

        let report = try await LearnerDeduplicator(controller: controller).run()
        XCTAssertEqual(report.removed["CDAttempt"], 1)
        XCTAssertEqual(report.removed["CDStudySession"], 1)
        XCTAssertEqual(report.removed["CDLearnerSettings"], 1)
        XCTAssertEqual(report.total, 3)
        let attempts = try await CoreDataAttemptRepository(controller: controller).attempts(inSession: StudySessionID("s"))
        XCTAssertEqual(Set(attempts.map(\.id.rawValue)), ["a1", "a3"])
        let session = try await CoreDataStudySessionRepository(controller: controller).session(id: StudySessionID("s"))
        XCTAssertEqual(session?.currentIndex, 2)
        let settings = try await CoreDataLearnerSettingsRepository(controller: controller).load()
        XCTAssertEqual(settings.glossLanguage, .khmer)
    }

    func testEqualDatesBreakTiesByIDOnEveryDevice() async throws {
        // Two rows with identical policy dates: the survivor must not depend on fetch order.
        let same = Date(timeIntervalSince1970: 1_000)
        for order in [["b-row", "a-row"], ["a-row", "b-row"]] {
            let controller = try makeController()
            for id in order {
                try await insert("CDBookmark", ["id": id, "targetKind": "grammar", "targetID": "g1", "createdAt": same, "modifiedAt": same], in: controller)
                try await insert("CDReviewSchedule", ["id": id, "targetKind": "grammar", "targetID": "g1", "easeFactor": 2.5, "intervalDays": Int32(1), "repetitions": Int32(1), "nextReviewDate": same, "lastReviewedAt": same, "modifiedAt": same], in: controller)
                try await insert("CDAttempt", ["id": id, "sessionID": "s", "questionID": "q", "selectedOptionID": "o", "isCorrect": true, "answeredAt": same, "responseTime": 1.0], in: controller)
            }
            _ = try await LearnerDeduplicator(controller: controller).run()
            let bookmark = try await CoreDataBookmarkRepository(controller: controller).all().first
            XCTAssertEqual(bookmark?.id.rawValue, "b-row", "largest id wins on a tie (insert order \(order))")
            let schedule = try await CoreDataReviewScheduleRepository(controller: controller).schedule(for: .grammar(GrammarID("g1")))
            XCTAssertEqual(schedule?.id.rawValue, "b-row", "insert order \(order)")
            let attempts = try await CoreDataAttemptRepository(controller: controller).attempts(inSession: StudySessionID("s"))
            XCTAssertEqual(attempts.map(\.id.rawValue), ["a-row"], "earliest answer, smallest id wins on a tie (insert order \(order))")
        }
    }

    func testCleanStoreIsUntouched() async throws {
        let controller = try makeController()
        try await insert("CDLearnerNote", ["id": "n", "targetKind": "grammar", "targetID": "g1", "text": "hi", "modifiedAt": Date()], in: controller)
        let report = try await LearnerDeduplicator(controller: controller).run()
        XCTAssertTrue(report.isEmpty)
        let noteCount = try await count("CDLearnerNote", in: controller)
        XCTAssertEqual(noteCount, 1)
    }

    func testAccountStatusAndErrorMapping() {
        XCTAssertEqual(SyncMonitor.map(.available), .available)
        XCTAssertEqual(SyncMonitor.map(.noAccount), .noAccount)
        XCTAssertEqual(SyncMonitor.map(.restricted), .restricted)
        XCTAssertEqual(SyncMonitor.map(.temporarilyUnavailable), .temporarilyUnavailable)
        XCTAssertEqual(SyncMonitor.describe(DomainError.emptyPool), "No questions match the selected filters.")
        XCTAssertEqual(SyncMonitor.describe(CKError(.notAuthenticated)), "Not signed in to iCloud.")
        XCTAssertEqual(SyncMonitor.describe(CKError(.quotaExceeded)), "iCloud storage is full.")
        XCTAssertEqual(SyncMonitor.describe(CKError(.networkFailure)), "No network. Changes will sync later.")
        XCTAssertEqual(SyncMonitor.describe(CKError(.partialFailure)), "Some records failed to sync. They will be retried.")
    }
}
