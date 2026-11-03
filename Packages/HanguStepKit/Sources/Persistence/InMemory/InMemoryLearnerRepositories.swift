import Domain
import Foundation

public actor InMemoryAttemptRepository: AttemptRepository {
    private var attempts: [Attempt] = []
    private var submitted: Set<SubmissionKey> = []

    private struct SubmissionKey: Hashable {
        let session: StudySessionID
        let question: QuestionID
    }

    public init() {}

    public func record(_ attempt: Attempt) async throws {
        let key = SubmissionKey(session: attempt.sessionID, question: attempt.questionID)
        guard submitted.insert(key).inserted else {
            throw DomainError.duplicateSubmission(questionID: attempt.questionID)
        }
        attempts.append(attempt)
    }

    public func attempts(inSession sessionID: StudySessionID) async throws -> [Attempt] {
        attempts.filter { $0.sessionID == sessionID }
    }

    public func attempts(forQuestion questionID: QuestionID) async throws -> [Attempt] {
        attempts.filter { $0.questionID == questionID }
    }

    public func summary() async throws -> AttemptSummary {
        AttemptSummary(total: attempts.count, correct: attempts.filter(\.isCorrect).count)
    }

    public func allAttempts() async throws -> [Attempt] {
        attempts.sorted { $0.answeredAt < $1.answeredAt }
    }
}

public actor InMemoryBookmarkRepository: BookmarkRepository {
    private var bookmarks: [LearningTarget: Bookmark] = [:]

    public init() {}

    public func add(_ bookmark: Bookmark) async throws { bookmarks[bookmark.target] = bookmark }
    public func remove(target: LearningTarget) async throws { bookmarks[target] = nil }
    public func contains(target: LearningTarget) async throws -> Bool { bookmarks[target] != nil }
    public func all() async throws -> [Bookmark] {
        bookmarks.values.sorted { $0.createdAt > $1.createdAt }
    }
}

public actor InMemoryReviewScheduleRepository: ReviewScheduleRepository {
    private var schedules: [LearningTarget: ReviewSchedule] = [:]

    public init() {}

    public func schedule(for target: LearningTarget) async throws -> ReviewSchedule? { schedules[target] }
    public func upsert(_ schedule: ReviewSchedule) async throws { schedules[schedule.target] = schedule }
    public func due(onOrBefore date: Date, limit: Int) async throws -> [ReviewSchedule] {
        Array(
            schedules.values
                .filter { $0.nextReviewDate <= date }
                .sorted { $0.nextReviewDate < $1.nextReviewDate }
                .prefix(limit)
        )
    }
    public func all() async throws -> [ReviewSchedule] {
        schedules.values.sorted { $0.nextReviewDate < $1.nextReviewDate }
    }
}

public actor InMemoryStudySessionRepository: StudySessionRepository {
    private var sessions: [StudySessionID: StudySession] = [:]

    public init() {}

    public func save(_ session: StudySession) async throws { sessions[session.id] = session }
    public func session(id: StudySessionID) async throws -> StudySession? { sessions[id] }
    public func unfinishedSession() async throws -> StudySession? {
        sessions.values.filter { !$0.isFinished }.max { $0.startedAt < $1.startedAt }
    }
    public func sessions(limit: Int) async throws -> [StudySession] {
        Array(sessions.values.sorted { $0.startedAt > $1.startedAt }.prefix(limit))
    }
}

public actor InMemoryLearnerNoteRepository: LearnerNoteRepository {
    private var notes: [LearningTarget: LearnerNote] = [:]

    public init() {}

    public func note(for target: LearningTarget) async throws -> LearnerNote? { notes[target] }
    public func upsert(_ note: LearnerNote) async throws {
        if note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes[note.target] = nil
        } else {
            notes[note.target] = note
        }
    }
    public func remove(target: LearningTarget) async throws { notes[target] = nil }
}

public actor InMemoryLearnerSettingsRepository: LearnerSettingsRepository {
    private var settings: LearnerSettings = .default

    public init() {}

    public func load() async throws -> LearnerSettings { settings }
    public func save(_ settings: LearnerSettings) async throws { self.settings = settings }
}
