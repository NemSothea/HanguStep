import Foundation

public protocol StartQuizSessionUseCase: Sendable {
    /// Builds and persists a new session. Throws `DomainError.emptyPool` when no valid question matches.
    func execute(_ configuration: QuizConfiguration) async throws -> QuizSessionSnapshot
}

public struct StartQuizSession: StartQuizSessionUseCase {
    private let questions: any QuestionRepository
    private let sessions: any StudySessionRepository
    private let attempts: any AttemptRepository
    private let shuffler: any Shuffler
    private let ids: any IDGenerator
    private let dates: any DateProvider
    private let deviceName: String

    public init(
        questions: any QuestionRepository,
        sessions: any StudySessionRepository,
        attempts: any AttemptRepository,
        shuffler: any Shuffler = SystemShuffler(),
        ids: any IDGenerator = UUIDGenerator(),
        dates: any DateProvider = SystemDateProvider(),
        deviceName: String
    ) {
        self.questions = questions
        self.sessions = sessions
        self.attempts = attempts
        self.shuffler = shuffler
        self.ids = ids
        self.dates = dates
        self.deviceName = deviceName
    }

    public func execute(_ configuration: QuizConfiguration) async throws -> QuizSessionSnapshot {
        let candidates = try await candidates(for: configuration)
        // Invalid content is excluded, never shown (PRD FR-Q8).
        let valid = candidates.filter(\.isValid)
        guard !valid.isEmpty else { throw DomainError.emptyPool }

        let chosen: [Question]
        if case .questions = configuration.pool {
            chosen = valid
        } else {
            chosen = Array(shuffler.shuffle(valid).prefix(configuration.count))
        }

        let session = StudySession(
            id: StudySessionID(ids.next()),
            mode: configuration.pool.mode,
            startedAt: dates.now(),
            questionIDs: chosen.map(\.id),
            deviceName: deviceName
        )
        try await sessions.save(session)
        let requested = configuration.pool.isFixedList ? chosen.count : configuration.count
        return QuizSessionSnapshot(session: session, questions: chosen, attempts: [], requestedCount: requested)
    }

    private func candidates(for configuration: QuizConfiguration) async throws -> [Question] {
        switch configuration.pool {
        case let .questions(ids):
            return try await questions.questions(ids: ids)
        case .mistakes:
            let targets = Set(MistakeDerivation.mistakes(from: try await attempts.allAttempts()).map(\.target))
            guard !targets.isEmpty else { return [] }
            let filter = QuestionFilter(levels: configuration.levels)
            return try await questions.questions(matching: filter).filter {
                guard let target = $0.learningTarget else { return false }
                return targets.contains(target)
            }
        case .vocabulary, .grammar, .mixed:
            let filter = QuestionFilter(levels: configuration.levels, kinds: configuration.pool.kinds)
            return try await questions.questions(matching: filter)
        }
    }
}

extension QuizPool {
    var isFixedList: Bool {
        if case .questions = self { return true }
        return false
    }
}
