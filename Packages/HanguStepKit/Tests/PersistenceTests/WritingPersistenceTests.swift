import Domain
@testable import Persistence
import XCTest

/// Writing practice storage (ADR-012). Migration from v1 is covered by MigrationTests.
final class WritingPersistenceTests: XCTestCase {
    private static let feedback = WritingFeedback(
        providerName: "Claude", estimatedScore: 21, maxScore: 30,
        criteria: [.init(name: "Language use", score: 11, maxScore: 16, comment: "Good connectives.")],
        corrections: [.init(original: "많은 사람이에요", suggestion: "많은 사람이다", reason: "Use 한다체.")],
        summary: "Solid answer.", language: .english
    )

    func testAttemptRoundTripWithFeedbackAndUpdate() async throws {
        let controller = try PersistenceController(mode: .inMemory)
        let repository = CoreDataWritingAttemptRepository(controller: controller)
        let task = WritingTaskID("w.53.001")
        var first = WritingAttempt(taskID: task, text: "첫 번째 답", createdAt: Date(timeIntervalSince1970: 100))
        let second = WritingAttempt(taskID: task, text: "두 번째 답", createdAt: Date(timeIntervalSince1970: 200))
        try await repository.save(first)
        try await repository.save(second)
        try await repository.save(WritingAttempt(taskID: WritingTaskID("w.54.001"), text: "다른 과제", createdAt: .now))

        first.feedback = Self.feedback
        try await repository.save(first)

        let forTask = try await repository.attempts(for: task)
        XCTAssertEqual(forTask.map(\.text), ["두 번째 답", "첫 번째 답"], "newest first, update did not duplicate")
        XCTAssertEqual(forTask.last?.feedback, Self.feedback)
        let all = try await repository.allAttempts()
        XCTAssertEqual(all.count, 3)
    }

    func testBundledWritingTasksAreValid() throws {
        let tasks = try BundledWritingTasks().load()
        XCTAssertEqual(tasks.count, 30)
        XCTAssertEqual(Set(tasks.map(\.type)), Set(WritingTaskType.allCases))
        for task in tasks where task.type != .shortAnswer {
            XCTAssertNotNil(task.lengthRange, task.id.rawValue)
        }
    }
}
