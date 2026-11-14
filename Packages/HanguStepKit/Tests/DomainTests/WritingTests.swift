@testable import Domain
import XCTest

final class WritingTests: XCTestCase {
    private func task(_ type: WritingTaskType, range: ClosedRange<Int>? = nil) -> WritingTask {
        WritingTask(id: WritingTaskID("w.\(type.rawValue)"), type: type, level: .level4, prompt: "p", material: "( ㉠ ) ( ㉡ )",
                    lengthRange: range, modelAnswer: "m", tips: Gloss(english: "t", khmer: "ត"))
    }

    func testCharacterCountIncludesSpacesNotLineBreaks() {
        XCTAssertEqual(WritingText.characterCount("한국 어\n공부"), 6)
        XCTAssertEqual(WritingText.characterCount(""), 0)
    }

    func testSaveRejectsBlankAndStoresTrimmedAnswer() async throws {
        let repository = MemoryAttempts()
        let save = SaveWritingAttempt(attempts: repository, dates: FixedDateProvider(Date(timeIntervalSince1970: 50)))
        do {
            _ = try await save.execute(taskID: WritingTaskID("w"), text: "  \n ")
            XCTFail("blank answer saved")
        } catch let error as DomainError {
            XCTAssertEqual(error, .emptyAnswer)
        }
        let saved = try await save.execute(taskID: WritingTaskID("w"), text: "  답입니다 \n")
        XCTAssertEqual(saved.text, "답입니다")
        XCTAssertEqual(saved.createdAt, Date(timeIntervalSince1970: 50))
        let stored = try await repository.allAttempts()
        XCTAssertEqual(stored.count, 1)
    }

    func testListShowsAttemptCountAndBestScore() async throws {
        let repository = MemoryAttempts()
        let essay = task(.essay, range: 600...700)
        let feedback = { (score: Int) in WritingFeedback(providerName: "c", estimatedScore: score, maxScore: 50, criteria: [], corrections: [], summary: "", language: .english) }
        try await repository.save(WritingAttempt(taskID: essay.id, text: "a", createdAt: .now, feedback: feedback(31)))
        try await repository.save(WritingAttempt(taskID: essay.id, text: "b", createdAt: .now, feedback: feedback(38)))
        try await repository.save(WritingAttempt(taskID: essay.id, text: "c", createdAt: .now))
        let list = try await ListWritingTasks(tasks: StaticTasks(tasks: [essay, task(.shortAnswer)]), attempts: repository).execute()
        XCTAssertEqual(list.map(\.attemptCount), [3, 0])
        XCTAssertEqual(list.map(\.bestScore), [38, nil])
    }

    func testReviewStoresFeedbackOnTheAttempt() async throws {
        let repository = MemoryAttempts()
        let attempt = WritingAttempt(taskID: WritingTaskID("w.essay"), text: "글", createdAt: .now)
        try await repository.save(attempt)
        let reviewed = try await ReviewWriting(providers: FixedAssistantProviderSource(MockAssistantProvider()), attempts: repository)
            .execute(attempt: attempt, task: task(.essay, range: 600...700), language: .english)
        XCTAssertNotNil(reviewed.feedback)
        let stored = try await repository.allAttempts()
        XCTAssertEqual(stored.first?.feedback, reviewed.feedback)
    }

    func testOfflineChecks() async throws {
        let mock = MockAssistantProvider()
        let short = try await mock.reviewWriting(WritingReviewRequest(task: task(.describeData, range: 200...300), answer: "조사 결과가 나왔어요.", language: .english))
        XCTAssertNil(short.estimatedScore, "offline checks never invent a score")
        XCTAssertEqual(short.criteria.map(\.name), ["Length", "Formal style (한다체)"])
        XCTAssertEqual(short.criteria.map(\.score), [0, 0])

        let blanks = try await mock.reviewWriting(WritingReviewRequest(task: task(.shortAnswer), answer: "㉠ 가방을 찾습니다\n㉡", language: .khmer))
        XCTAssertEqual(blanks.criteria.map(\.score), [0], "㉡ is empty")
        XCTAssertEqual(blanks.language, .khmer)

        let essayText = String(repeating: "환경을 보호해야 한다. ", count: 20) + "\n" + String(repeating: "개인의 노력도 중요하다. ", count: 20) + "\n" + String(repeating: "따라서 함께 실천해야 한다. ", count: 10)
        let essay = try await mock.reviewWriting(WritingReviewRequest(task: task(.essay, range: 600...700), answer: essayText, language: .english))
        XCTAssertEqual(essay.criteria.map(\.name), ["Length", "Formal style (한다체)", "Paragraphs"])
        XCTAssertEqual(essay.criteria.map(\.score), [WritingText.characterCount(essayText) >= 600 && WritingText.characterCount(essayText) <= 700 ? 1 : 0, 1, 1])
    }
}

private actor MemoryAttempts: WritingAttemptRepository {
    private var stored: [UUID: WritingAttempt] = [:]
    func save(_ attempt: WritingAttempt) async throws { stored[attempt.id] = attempt }
    func attempts(for taskID: WritingTaskID) async throws -> [WritingAttempt] { stored.values.filter { $0.taskID == taskID } }
    func allAttempts() async throws -> [WritingAttempt] { Array(stored.values) }
}

private struct StaticTasks: WritingTaskRepository {
    let tasks: [WritingTask]
    func tasks() async throws -> [WritingTask] { tasks }
}
