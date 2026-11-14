import Foundation

public protocol FinishQuizSessionUseCase: Sendable {
    /// Marks the session ended (idempotent) and computes its result.
    func execute(sessionID: StudySessionID) async throws -> QuizResult
}

public struct FinishQuizSession: FinishQuizSessionUseCase {
    private let sessions: any StudySessionRepository
    private let attempts: any AttemptRepository
    private let questions: any QuestionRepository
    private let dates: any DateProvider

    public init(
        sessions: any StudySessionRepository,
        attempts: any AttemptRepository,
        questions: any QuestionRepository,
        dates: any DateProvider = SystemDateProvider()
    ) {
        self.sessions = sessions
        self.attempts = attempts
        self.questions = questions
        self.dates = dates
    }

    public func execute(sessionID: StudySessionID) async throws -> QuizResult {
        guard var session = try await sessions.session(id: sessionID) else {
            throw DomainError.notFound(entity: "StudySession", id: sessionID.rawValue)
        }
        if session.endedAt == nil {
            session.endedAt = dates.now()
            try await sessions.save(session)
        }
        return try await QuizScoring.result(for: session, attempts: attempts, questions: questions)
    }
}

/// Scoring shared by results and history.
public enum QuizScoring {
    public static func result(for session: StudySession, attempts: any AttemptRepository, questions: any QuestionRepository) async throws -> QuizResult {
        let answered = try await attempts.attempts(inSession: session.id)
        let incorrectAttempts = answered.filter { !$0.isCorrect }
        let incorrectQuestions = try await questions.questions(ids: incorrectAttempts.map(\.questionID))
        let byID = Dictionary(uniqueKeysWithValues: incorrectQuestions.map { ($0.id, $0) })
        let incorrect = incorrectAttempts.compactMap { attempt -> IncorrectAnswer? in
            byID[attempt.questionID].map { IncorrectAnswer(question: $0, selectedOptionID: attempt.selectedOptionID) }
        }
        let duration = (session.endedAt ?? session.startedAt).timeIntervalSince(session.startedAt)
        let averageResponse = answered.isEmpty ? 0 : answered.map(\.responseTime).reduce(0, +) / Double(answered.count)
        return QuizResult(
            session: session,
            total: session.questionIDs.count,
            answered: answered.count,
            correct: answered.filter(\.isCorrect).count,
            duration: max(0, duration),
            averageResponseTime: averageResponse,
            incorrect: incorrect
        )
    }
}
