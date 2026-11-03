import Foundation

public enum QuizPool: Hashable, Sendable, Codable {
    case vocabulary
    case grammar
    case mixed
    /// Questions attached to the learner's current mistakes.
    case mistakes
    /// A fixed list, for example a grammar lesson's practice questions.
    case questions([QuestionID])

    var kinds: Set<QuestionKind> {
        switch self {
        case .vocabulary: return [.vocabularyMeaning, .meaningToWord]
        case .grammar: return [.grammarFillIn, .sentenceCompletion]
        case .mixed, .mistakes, .questions: return []
        }
    }

    var mode: StudyMode {
        switch self {
        case .mistakes: return .mistakes
        default: return .quiz
        }
    }
}

public struct QuizConfiguration: Hashable, Sendable, Codable {
    public static let allowedCounts = [5, 10, 20, 40]

    public var pool: QuizPool
    public var levels: Set<TOPIKLevel>
    public var count: Int

    public init(pool: QuizPool = .mixed, levels: Set<TOPIKLevel> = [], count: Int = 10) {
        self.pool = pool
        self.levels = levels
        self.count = count
    }
}

/// Everything a quiz screen needs to show one session.
public struct QuizSessionSnapshot: Hashable, Sendable {
    public let session: StudySession
    public let questions: [Question]
    public let attempts: [Attempt]
    /// Requested count was larger than the pool (PRD FR-Q9).
    public let requestedCount: Int

    public init(session: StudySession, questions: [Question], attempts: [Attempt], requestedCount: Int) {
        self.session = session
        self.questions = questions
        self.attempts = attempts
        self.requestedCount = requestedCount
    }

    public var isShortfall: Bool { questions.count < requestedCount }
    public var answeredQuestionIDs: Set<QuestionID> { Set(attempts.map(\.questionID)) }
    public var currentQuestion: Question? {
        session.currentIndex < questions.count ? questions[session.currentIndex] : nil
    }
    public var isComplete: Bool { session.currentIndex >= questions.count }
}

public struct AnswerFeedback: Hashable, Sendable {
    public let attempt: Attempt
    public let isCorrect: Bool
    public let correctOptionID: OptionID
    public let explanation: Gloss
    public let nextIndex: Int
    public let isLastQuestion: Bool

    public init(attempt: Attempt, isCorrect: Bool, correctOptionID: OptionID, explanation: Gloss, nextIndex: Int, isLastQuestion: Bool) {
        self.attempt = attempt
        self.isCorrect = isCorrect
        self.correctOptionID = correctOptionID
        self.explanation = explanation
        self.nextIndex = nextIndex
        self.isLastQuestion = isLastQuestion
    }
}

public struct IncorrectAnswer: Hashable, Sendable, Identifiable {
    public var id: QuestionID { question.id }
    public let question: Question
    public let selectedOptionID: OptionID

    public init(question: Question, selectedOptionID: OptionID) {
        self.question = question
        self.selectedOptionID = selectedOptionID
    }
}

public struct QuizResult: Hashable, Sendable {
    public let session: StudySession
    public let total: Int
    public let answered: Int
    public let correct: Int
    public let duration: TimeInterval
    public let averageResponseTime: TimeInterval
    public let incorrect: [IncorrectAnswer]

    public init(session: StudySession, total: Int, answered: Int, correct: Int, duration: TimeInterval, averageResponseTime: TimeInterval, incorrect: [IncorrectAnswer]) {
        self.session = session
        self.total = total
        self.answered = answered
        self.correct = correct
        self.duration = duration
        self.averageResponseTime = averageResponseTime
        self.incorrect = incorrect
    }

    public var accuracy: Double { answered == 0 ? 0 : Double(correct) / Double(answered) }
    public var isPerfect: Bool { answered > 0 && correct == answered }
}
