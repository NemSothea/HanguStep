import Foundation

/// TOPIK II 쓰기 task types (questions 51-54).
public enum WritingTaskType: String, Sendable, Codable, CaseIterable, Hashable {
    /// 51-52: fill ㉠ and ㉡ with one sentence each.
    case shortAnswer
    /// 53: describe survey or graph data in 200-300 characters.
    case describeData
    /// 54: argumentative essay in 600-700 characters.
    case essay

    public var title: String {
        switch self {
        case .shortAnswer: return "Sentence completion (51-52)"
        case .describeData: return "Describe data (53)"
        case .essay: return "Essay (54)"
        }
    }

    /// Points the exam awards for one task of this type.
    public var maxScore: Int {
        switch self {
        case .shortAnswer: return 10
        case .describeData: return 30
        case .essay: return 50
        }
    }
}

public struct WritingTaskID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

/// One writing prompt with a model answer. Read-only content.
public struct WritingTask: Identifiable, Hashable, Sendable {
    public let id: WritingTaskID
    public let type: WritingTaskType
    public let level: TOPIKLevel
    public let prompt: String
    /// The text, data or topic the learner works from.
    public let material: String
    /// Required length in characters (spaces count), when the task has one.
    public let lengthRange: ClosedRange<Int>?
    public let modelAnswer: String
    public let tips: Gloss

    public init(id: WritingTaskID, type: WritingTaskType, level: TOPIKLevel, prompt: String, material: String, lengthRange: ClosedRange<Int>?, modelAnswer: String, tips: Gloss) {
        self.id = id
        self.type = type
        self.level = level
        self.prompt = prompt
        self.material = material
        self.lengthRange = lengthRange
        self.modelAnswer = modelAnswer
        self.tips = tips
    }
}

public enum WritingText {
    /// Characters as TOPIK counts them on the answer sheet: spaces count, line breaks do not.
    public static func characterCount(_ text: String) -> Int {
        text.filter { !$0.isNewline }.count
    }
}

/// Graded feedback on one attempt, from an assistant provider.
public struct WritingFeedback: Hashable, Sendable, Codable {
    public struct Criterion: Hashable, Sendable, Codable {
        public let name: String
        public let score: Int
        public let maxScore: Int
        public let comment: String

        public init(name: String, score: Int, maxScore: Int, comment: String) {
            self.name = name
            self.score = score
            self.maxScore = maxScore
            self.comment = comment
        }
    }

    public struct Correction: Hashable, Sendable, Codable {
        public let original: String
        public let suggestion: String
        public let reason: String

        public init(original: String, suggestion: String, reason: String) {
            self.original = original
            self.suggestion = suggestion
            self.reason = reason
        }
    }

    public let providerName: String
    /// Estimated exam points; nil when the provider cannot grade (offline checks).
    public let estimatedScore: Int?
    public let maxScore: Int
    public let criteria: [Criterion]
    public let corrections: [Correction]
    public let summary: String
    public let language: GlossLanguage

    public init(providerName: String, estimatedScore: Int?, maxScore: Int, criteria: [Criterion], corrections: [Correction], summary: String, language: GlossLanguage) {
        self.providerName = providerName
        self.estimatedScore = estimatedScore
        self.maxScore = maxScore
        self.criteria = criteria
        self.corrections = corrections
        self.summary = summary
        self.language = language
    }
}

/// A saved answer. Learner data: synced with the rest of the learner store.
public struct WritingAttempt: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let taskID: WritingTaskID
    public var text: String
    public let createdAt: Date
    public var feedback: WritingFeedback?

    public init(id: UUID = UUID(), taskID: WritingTaskID, text: String, createdAt: Date, feedback: WritingFeedback? = nil) {
        self.id = id
        self.taskID = taskID
        self.text = text
        self.createdAt = createdAt
        self.feedback = feedback
    }

    public var characterCount: Int { WritingText.characterCount(text) }
}

/// What a provider needs to grade an answer.
public struct WritingReviewRequest: Hashable, Sendable {
    public let task: WritingTask
    public let answer: String
    public let language: GlossLanguage

    public init(task: WritingTask, answer: String, language: GlossLanguage) {
        self.task = task
        self.answer = answer
        self.language = language
    }
}

public protocol WritingTaskRepository: Sendable {
    func tasks() async throws -> [WritingTask]
}

public protocol WritingAttemptRepository: Sendable {
    func save(_ attempt: WritingAttempt) async throws
    func attempts(for taskID: WritingTaskID) async throws -> [WritingAttempt]
    func allAttempts() async throws -> [WritingAttempt]
}
