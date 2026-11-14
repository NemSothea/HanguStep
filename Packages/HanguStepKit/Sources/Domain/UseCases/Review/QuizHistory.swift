import Foundation

public struct SessionSummary: Hashable, Sendable, Identifiable {
    public var id: StudySessionID { session.id }
    public let session: StudySession
    public let answered: Int
    public let correct: Int

    public init(session: StudySession, answered: Int, correct: Int) {
        self.session = session
        self.answered = answered
        self.correct = correct
    }

    public var accuracy: Double { answered == 0 ? 0 : Double(correct) / Double(answered) }
}

public protocol ListQuizHistoryUseCase: Sendable {
    func execute(limit: Int) async throws -> [SessionSummary]
}

public struct ListQuizHistory: ListQuizHistoryUseCase {
    private let sessions: any StudySessionRepository
    private let attempts: any AttemptRepository

    public init(sessions: any StudySessionRepository, attempts: any AttemptRepository) {
        self.sessions = sessions
        self.attempts = attempts
    }

    public func execute(limit: Int) async throws -> [SessionSummary] {
        let recent = try await sessions.sessions(limit: limit).filter(\.isFinished)
        var summaries: [SessionSummary] = []
        for session in recent {
            let answered = try await attempts.attempts(inSession: session.id)
            summaries.append(SessionSummary(session: session, answered: answered.count, correct: answered.filter(\.isCorrect).count))
        }
        return summaries
    }
}
