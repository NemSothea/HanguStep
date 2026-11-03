import Foundation

public protocol SubmitAnswerUseCase: Sendable {
    func execute(session: StudySession, question: Question, selectedOptionID: OptionID, responseTime: TimeInterval) async throws -> AnswerFeedback
}

public struct SubmitAnswer: SubmitAnswerUseCase {
    private let sessions: any StudySessionRepository
    private let attempts: any AttemptRepository
    private let ids: any IDGenerator
    private let dates: any DateProvider

    public init(
        sessions: any StudySessionRepository,
        attempts: any AttemptRepository,
        ids: any IDGenerator = UUIDGenerator(),
        dates: any DateProvider = SystemDateProvider()
    ) {
        self.sessions = sessions
        self.attempts = attempts
        self.ids = ids
        self.dates = dates
    }

    public func execute(session: StudySession, question: Question, selectedOptionID: OptionID, responseTime: TimeInterval) async throws -> AnswerFeedback {
        guard question.options.contains(where: { $0.id == selectedOptionID }) else {
            throw DomainError.notFound(entity: "QuestionOption", id: selectedOptionID.rawValue)
        }
        guard let index = session.questionIDs.firstIndex(of: question.id) else {
            throw DomainError.notFound(entity: "Question in session", id: question.id.rawValue)
        }
        let isCorrect = selectedOptionID == question.correctOptionID
        let attempt = Attempt(
            id: AttemptID(ids.next()),
            sessionID: session.id,
            questionID: question.id,
            selectedOptionID: selectedOptionID,
            isCorrect: isCorrect,
            answeredAt: dates.now(),
            responseTime: max(0, responseTime),
            target: question.learningTarget
        )
        // Repository rejects a second answer for the same question (PRD FR-Q3).
        try await attempts.record(attempt)

        var updated = session
        updated.currentIndex = max(session.currentIndex, index + 1)
        try await sessions.save(updated)

        return AnswerFeedback(
            attempt: attempt,
            isCorrect: isCorrect,
            correctOptionID: question.correctOptionID,
            explanation: question.explanation,
            nextIndex: updated.currentIndex,
            isLastQuestion: updated.currentIndex >= session.questionIDs.count
        )
    }
}
