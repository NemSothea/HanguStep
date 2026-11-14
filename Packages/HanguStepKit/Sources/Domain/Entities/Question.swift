import Foundation

public enum QuestionKind: String, Sendable, Codable, CaseIterable {
    case vocabularyMeaning
    case meaningToWord
    case grammarFillIn
    case sentenceCompletion
    case readingComprehension
}

public struct QuestionOption: Identifiable, Hashable, Sendable, Codable {
    public let id: OptionID
    public var text: String

    public init(id: OptionID, text: String) {
        self.id = id
        self.text = text
    }
}

public enum ContentValidationIssue: Sendable, Equatable, CustomStringConvertible {
    case emptyPrompt
    case tooFewOptions(count: Int)
    case tooManyOptions(count: Int)
    case duplicateOptionText
    case duplicateOptionID
    case correctOptionMissing
    case emptyExplanation(GlossLanguage)

    public var description: String {
        switch self {
        case .emptyPrompt: return "empty prompt"
        case let .tooFewOptions(count): return "only \(count) options"
        case let .tooManyOptions(count): return "\(count) options exceeds 4"
        case .duplicateOptionText: return "duplicate option text"
        case .duplicateOptionID: return "duplicate option id"
        case .correctOptionMissing: return "correct option not among options"
        case let .emptyExplanation(language): return "empty \(language.rawValue) explanation"
        }
    }
}

/// A multiple-choice question. Exactly one option is correct (PRD FR-Q1).
public struct Question: Identifiable, Hashable, Sendable, Codable {
    public static let minimumOptions = 2
    public static let maximumOptions = 4

    public let id: QuestionID
    public var kind: QuestionKind
    public var level: TOPIKLevel
    public var prompt: String
    public var passage: String?
    public var options: [QuestionOption]
    public var correctOptionID: OptionID
    public var explanation: Gloss
    public var relatedVocabularyID: VocabularyID?
    public var relatedGrammarID: GrammarID?
    public var source: ContentSource
    public var contentVersion: Int

    public init(
        id: QuestionID,
        kind: QuestionKind,
        level: TOPIKLevel,
        prompt: String,
        passage: String? = nil,
        options: [QuestionOption],
        correctOptionID: OptionID,
        explanation: Gloss,
        relatedVocabularyID: VocabularyID? = nil,
        relatedGrammarID: GrammarID? = nil,
        source: ContentSource,
        contentVersion: Int
    ) {
        self.id = id
        self.kind = kind
        self.level = level
        self.prompt = prompt
        self.passage = passage
        self.options = options
        self.correctOptionID = correctOptionID
        self.explanation = explanation
        self.relatedVocabularyID = relatedVocabularyID
        self.relatedGrammarID = relatedGrammarID
        self.source = source
        self.contentVersion = contentVersion
    }

    /// Structural validation. Invalid questions are excluded from quiz
    /// generation and reported (PRD FR-Q8, AC-10).
    public func validate() -> [ContentValidationIssue] {
        var issues: [ContentValidationIssue] = []
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.emptyPrompt)
        }
        if options.count < Self.minimumOptions {
            issues.append(.tooFewOptions(count: options.count))
        }
        if options.count > Self.maximumOptions {
            issues.append(.tooManyOptions(count: options.count))
        }
        if Set(options.map(\.id)).count != options.count {
            issues.append(.duplicateOptionID)
        }
        let normalizedTexts = options.map {
            $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        if Set(normalizedTexts).count != normalizedTexts.count {
            issues.append(.duplicateOptionText)
        }
        if !options.contains(where: { $0.id == correctOptionID }) {
            issues.append(.correctOptionMissing)
        }
        if explanation.english.isEmpty { issues.append(.emptyExplanation(.english)) }
        if explanation.khmer.isEmpty { issues.append(.emptyExplanation(.khmer)) }
        return issues
    }

    public var isValid: Bool { validate().isEmpty }

    /// The learning target this question practises, if any. Vocabulary wins when both are set.
    public var learningTarget: LearningTarget? {
        if let relatedVocabularyID { return .vocabulary(relatedVocabularyID) }
        if let relatedGrammarID { return .grammar(relatedGrammarID) }
        return nil
    }
}
