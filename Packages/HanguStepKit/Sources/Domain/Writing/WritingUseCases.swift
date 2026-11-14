import Foundation

/// A task with the learner's progress on it, for the task list.
public struct WritingTaskSummary: Identifiable, Hashable, Sendable {
    public let task: WritingTask
    public let attemptCount: Int
    public let bestScore: Int?

    public var id: WritingTaskID { task.id }

    public init(task: WritingTask, attemptCount: Int, bestScore: Int?) {
        self.task = task
        self.attemptCount = attemptCount
        self.bestScore = bestScore
    }
}

public protocol ListWritingTasksUseCase: Sendable {
    func execute() async throws -> [WritingTaskSummary]
}

public struct ListWritingTasks: ListWritingTasksUseCase {
    private let tasks: any WritingTaskRepository
    private let attempts: any WritingAttemptRepository

    public init(tasks: any WritingTaskRepository, attempts: any WritingAttemptRepository) {
        self.tasks = tasks
        self.attempts = attempts
    }

    public func execute() async throws -> [WritingTaskSummary] {
        let byTask = Dictionary(grouping: try await attempts.allAttempts(), by: \.taskID)
        return try await tasks.tasks().map { task in
            let done = byTask[task.id] ?? []
            return WritingTaskSummary(task: task, attemptCount: done.count, bestScore: done.compactMap { $0.feedback?.estimatedScore }.max())
        }
    }
}

public protocol SaveWritingAttemptUseCase: Sendable {
    /// Stores the answer and returns it; blank answers are rejected.
    func execute(taskID: WritingTaskID, text: String) async throws -> WritingAttempt
}

public struct SaveWritingAttempt: SaveWritingAttemptUseCase {
    private let attempts: any WritingAttemptRepository
    private let dates: any DateProvider

    public init(attempts: any WritingAttemptRepository, dates: any DateProvider) {
        self.attempts = attempts
        self.dates = dates
    }

    public func execute(taskID: WritingTaskID, text: String) async throws -> WritingAttempt {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DomainError.emptyAnswer }
        let attempt = WritingAttempt(taskID: taskID, text: trimmed, createdAt: dates.now())
        try await attempts.save(attempt)
        return attempt
    }
}

public protocol ReviewWritingUseCase: Sendable {
    /// Grades a saved attempt with the configured assistant and stores the feedback on it.
    func execute(attempt: WritingAttempt, task: WritingTask, language: GlossLanguage) async throws -> WritingAttempt
}

public struct ReviewWriting: ReviewWritingUseCase {
    private let providers: any AssistantProviderSource
    private let attempts: any WritingAttemptRepository

    public init(providers: any AssistantProviderSource, attempts: any WritingAttemptRepository) {
        self.providers = providers
        self.attempts = attempts
    }

    public func execute(attempt: WritingAttempt, task: WritingTask, language: GlossLanguage) async throws -> WritingAttempt {
        let provider = try await providers.currentProvider()
        let feedback = try await provider.reviewWriting(WritingReviewRequest(task: task, answer: attempt.text, language: language))
        var reviewed = attempt
        reviewed.feedback = feedback
        try await attempts.save(reviewed)
        return reviewed
    }
}
