import Foundation

public protocol ResumeQuizSessionUseCase: Sendable {
    /// The most recent unfinished session with its questions and answers, or nil.
    func execute() async throws -> QuizSessionSnapshot?
    func discardUnfinished() async throws
}

public struct ResumeQuizSession: ResumeQuizSessionUseCase {
    private let questions: any QuestionRepository
    private let sessions: any StudySessionRepository
    private let attempts: any AttemptRepository
    private let dates: any DateProvider

    public init(
        questions: any QuestionRepository,
        sessions: any StudySessionRepository,
        attempts: any AttemptRepository,
        dates: any DateProvider = SystemDateProvider()
    ) {
        self.questions = questions
        self.sessions = sessions
        self.attempts = attempts
        self.dates = dates
    }

    public func execute() async throws -> QuizSessionSnapshot? {
        guard var session = try await sessions.unfinishedSession() else { return nil }
        let loaded = try await questions.questions(ids: session.questionIDs)
        let answered = try await attempts.attempts(inSession: session.id)
        // Content may have been retired since; if nothing is left, close the session.
        guard !loaded.isEmpty else {
            session.endedAt = dates.now()
            try await sessions.save(session)
            return nil
        }
        // Resume position is derived from attempts, not trusted blindly (PRD AC-2).
        let answeredIDs = Set(answered.map(\.questionID))
        let firstUnanswered = loaded.firstIndex { !answeredIDs.contains($0.id) } ?? loaded.count
        if session.currentIndex != firstUnanswered {
            session.currentIndex = firstUnanswered
            try await sessions.save(session)
        }
        return QuizSessionSnapshot(session: session, questions: loaded, attempts: answered, requestedCount: loaded.count)
    }

    public func discardUnfinished() async throws {
        guard var session = try await sessions.unfinishedSession() else { return }
        session.endedAt = dates.now()
        try await sessions.save(session)
    }
}
