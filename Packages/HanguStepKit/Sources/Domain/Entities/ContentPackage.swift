import Foundation

/// A versioned bundle of content. Produced by the JSON importer (Phase 7) and
/// consumed by the persistence layer. Version must increase for changes to apply.
public struct ContentPackage: Hashable, Sendable, Codable {
    public let version: Int
    public let vocabulary: [VocabularyItem]
    public let grammar: [GrammarPattern]
    public let questions: [Question]

    public init(version: Int, vocabulary: [VocabularyItem], grammar: [GrammarPattern], questions: [Question]) {
        self.version = version
        self.vocabulary = vocabulary
        self.grammar = grammar
        self.questions = questions
    }

    /// Structural problems across the whole package. Empty means importable.
    public func validate() -> [ContentPackageIssue] {
        var issues: [ContentPackageIssue] = []
        func checkDuplicates(_ ids: [String], kind: String) {
            var seen = Set<String>()
            for id in ids where !seen.insert(id).inserted {
                issues.append(.duplicateID(kind: kind, id: id))
            }
        }
        checkDuplicates(vocabulary.map(\.id.rawValue), kind: "vocabulary")
        checkDuplicates(grammar.map(\.id.rawValue), kind: "grammar")
        checkDuplicates(questions.map(\.id.rawValue), kind: "question")

        for item in vocabulary where item.hangul.isEmpty || item.meaning.english.isEmpty || item.meaning.khmer.isEmpty {
            issues.append(.missingRequiredText(kind: "vocabulary", id: item.id.rawValue))
        }
        for pattern in grammar where pattern.pattern.isEmpty || pattern.explanation.english.isEmpty || pattern.explanation.khmer.isEmpty {
            issues.append(.missingRequiredText(kind: "grammar", id: pattern.id.rawValue))
        }
        for question in questions {
            let questionIssues = question.validate()
            if !questionIssues.isEmpty {
                issues.append(.invalidQuestion(id: question.id.rawValue, issues: questionIssues))
            }
        }
        let vocabularyIDs = Set(vocabulary.map(\.id))
        let grammarIDs = Set(grammar.map(\.id))
        for question in questions {
            if let related = question.relatedVocabularyID, !vocabularyIDs.contains(related) {
                issues.append(.danglingReference(questionID: question.id.rawValue, target: related.rawValue))
            }
            if let related = question.relatedGrammarID, !grammarIDs.contains(related) {
                issues.append(.danglingReference(questionID: question.id.rawValue, target: related.rawValue))
            }
        }
        return issues
    }
}

public enum ContentPackageIssue: Sendable, Equatable, CustomStringConvertible {
    case duplicateID(kind: String, id: String)
    case missingRequiredText(kind: String, id: String)
    case invalidQuestion(id: String, issues: [ContentValidationIssue])
    case danglingReference(questionID: String, target: String)

    public var description: String {
        switch self {
        case let .duplicateID(kind, id): return "duplicate \(kind) id \(id)"
        case let .missingRequiredText(kind, id): return "\(kind) \(id) is missing required text"
        case let .invalidQuestion(id, issues): return "question \(id): \(issues.map(\.description).joined(separator: ", "))"
        case let .danglingReference(questionID, target): return "question \(questionID) references missing \(target)"
        }
    }
}
