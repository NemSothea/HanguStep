import Foundation

public protocol SubmitAnswerUseCase: Sendable {
    func execute(session: StudySession, question: Question, selectedOptionID: OptionID, responseTime: TimeInterval) async throws -> AnswerFeedback
}

public struct SubmitAnswer: SubmitAnswerUseCase {
    private let sessions: any StudySessionRepository
    private let attempts: any AttemptRepository
    private let schedules: any ReviewScheduleRepository
    private let ids: any IDGenerator
    private let dates: any DateProvider
    private let calendar: Calendar

    public init(
        sessions: any StudySessionRepository,
        attempts: any AttemptRepository,
        schedules: any ReviewScheduleRepository,
        ids: any IDGenerator = UUIDGenerator(),
        dates: any DateProvider = SystemDateProvider(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.sessions = sessions
        self.attempts = attempts
        self.schedules = schedules
        self.ids = ids
        self.dates = dates
        self.calendar = calendar
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

        // Every answer, in any mode, moves the target's SM-2 schedule (PRD FR-R3).
        // Written before the session advances: if this write fails the session
        // stays on the question, the retry hits the duplicate guard and moves on,
        // and the next answer on the target recomputes from the stored state.
        var schedule: ReviewSchedule?
        if let target = question.learningTarget {
            let next = SM2.review(
                try await schedules.schedule(for: target),
                target: target,
                id: ReviewScheduleID(ids.next()),
                quality: ReviewQuality.forAnswer(isCorrect: isCorrect, responseTime: attempt.responseTime),
                on: attempt.answeredAt,
                calendar: calendar
            )
            try await schedules.upsert(next)
            schedule = next
        }

        var updated = session
        updated.currentIndex = max(session.currentIndex, index + 1)
        try await sessions.save(updated)

        return AnswerFeedback(
            attempt: attempt,
            isCorrect: isCorrect,
            correctOptionID: question.correctOptionID,
            explanation: question.explanation,
            nextIndex: updated.currentIndex,
            isLastQuestion: updated.currentIndex >= session.questionIDs.count,
            schedule: schedule
        )
    }
}
