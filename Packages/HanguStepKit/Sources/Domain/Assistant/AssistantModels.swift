import Foundation

/// Which assistant backs the feature (PRD FR-A1). Device-local choice.
public enum AssistantProviderKind: String, Sendable, Codable, CaseIterable {
    /// Deterministic, offline. Always available; used for tests and as the default.
    case mock
    /// Anthropic's Claude via the Messages API. Needs a learner-supplied key (FR-A3).
    case claude

    public var displayName: String {
        switch self {
        case .mock: return "Built-in (offline)"
        case .claude: return "Claude"
        }
    }
}

/// What the learner answered and the content it practised, for an explanation.
public struct ExplanationRequest: Hashable, Sendable {
    public let question: Question
    public let selectedOptionID: OptionID
    public let language: GlossLanguage
    public let vocabulary: VocabularyItem?
    public let grammar: GrammarPattern?

    public init(question: Question, selectedOptionID: OptionID, language: GlossLanguage, vocabulary: VocabularyItem? = nil, grammar: GrammarPattern? = nil) {
        self.question = question
        self.selectedOptionID = selectedOptionID
        self.language = language
        self.vocabulary = vocabulary
        self.grammar = grammar
    }

    public var isCorrect: Bool { selectedOptionID == question.correctOptionID }
    public var selectedText: String { question.options.first { $0.id == selectedOptionID }?.text ?? "" }
    public var correctText: String { question.options.first { $0.id == question.correctOptionID }?.text ?? "" }
}

public struct AssistantExplanation: Hashable, Sendable {
    public let text: String
    public let language: GlossLanguage
    public let providerName: String

    public init(text: String, language: GlossLanguage, providerName: String) {
        self.text = text
        self.language = language
        self.providerName = providerName
    }
}

/// The word or pattern to generate practice for, with sibling content the
/// provider may use as distractors so generated options stay plausible.
public enum PracticeSubject: Hashable, Sendable {
    case vocabulary(VocabularyItem, distractors: [VocabularyItem])
    case grammar(GrammarPattern, others: [GrammarPattern])

    public var target: LearningTarget {
        switch self {
        case let .vocabulary(item, _): return .vocabulary(item.id)
        case let .grammar(pattern, _): return .grammar(pattern.id)
        }
    }

    public var level: TOPIKLevel {
        switch self {
        case let .vocabulary(item, _): return item.level
        case let .grammar(pattern, _): return pattern.level
        }
    }
}

public struct PracticeRequest: Hashable, Sendable {
    public let subject: PracticeSubject
    public let count: Int
    /// Prompts already stored for this target, so the provider avoids repeats.
    public let existingPrompts: [String]

    public init(subject: PracticeSubject, count: Int, existingPrompts: [String] = []) {
        self.subject = subject
        self.count = count
        self.existingPrompts = existingPrompts
    }
}

/// A question as a provider proposes it. Validated and given an id and provenance
/// by `GeneratePracticeQuestions` before anything stores or shows it (FR-A2).
public struct DraftQuestion: Hashable, Sendable, Codable {
    public var kind: QuestionKind
    public var prompt: String
    public var passage: String?
    public var options: [String]
    /// Zero-based index into `options`.
    public var answer: Int
    public var explanation: Gloss

    public init(kind: QuestionKind, prompt: String, passage: String? = nil, options: [String], answer: Int, explanation: Gloss) {
        self.kind = kind
        self.prompt = prompt
        self.passage = passage
        self.options = options
        self.answer = answer
        self.explanation = explanation
    }
}

public enum AssistantError: Error, Sendable, Equatable {
    /// The learner has the assistant switched off.
    case disabled
    /// The chosen provider needs a credential that is not stored on this device.
    case notConfigured(AssistantProviderKind)
    case unauthorized
    case rateLimited
    case unavailable(String)
    /// The provider declined to answer.
    case refused
    case invalidResponse(String)
    /// The provider answered but nothing passed validation.
    case nothingUsable
}

extension AssistantError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .disabled: return "The assistant is turned off in Settings."
        case let .notConfigured(kind): return "\(kind.displayName) needs an API key. Add one in Settings."
        case .unauthorized: return "The API key was rejected. Check it in Settings."
        case .rateLimited: return "The assistant is busy. Try again in a moment."
        case let .unavailable(detail): return "The assistant could not be reached: \(detail)"
        case .refused: return "The assistant declined to answer this one."
        case let .invalidResponse(detail): return "The assistant sent an unexpected reply: \(detail)"
        case .nothingUsable: return "The assistant did not produce a usable question. Try again."
        }
    }
}
