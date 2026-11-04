import Foundation

/// On-disk JSON content format, version 1 (PRD FR-C1). Authoring-friendly shapes
/// that decode into domain entities. See Documentation/CONTENT_FORMAT.md.
///
/// A package is one `package.json` plus any number of part files. Parts are merged;
/// ids must stay unique across all parts.
public enum ContentFile {
    public static let supportedFormatVersion = 1

    public struct Package: Codable, Sendable, Hashable {
        public var formatVersion: Int
        /// Must increase for the app to re-import (FR-C2).
        public var version: Int
        public var source: Source
        public var vocabulary: [Vocabulary]
        public var grammar: [Grammar]
        public var questions: [Question]

        public init(formatVersion: Int = ContentFile.supportedFormatVersion, version: Int, source: Source, vocabulary: [Vocabulary] = [], grammar: [Grammar] = [], questions: [Question] = []) {
            self.formatVersion = formatVersion
            self.version = version
            self.source = source
            self.vocabulary = vocabulary
            self.grammar = grammar
            self.questions = questions
        }

        enum CodingKeys: String, CodingKey { case formatVersion, version, source, vocabulary, grammar, questions }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            formatVersion = try container.decode(Int.self, forKey: .formatVersion)
            version = try container.decode(Int.self, forKey: .version)
            source = try container.decode(Source.self, forKey: .source)
            vocabulary = try container.decodeIfPresent([Vocabulary].self, forKey: .vocabulary) ?? []
            grammar = try container.decodeIfPresent([Grammar].self, forKey: .grammar) ?? []
            questions = try container.decodeIfPresent([Question].self, forKey: .questions) ?? []
        }
    }

    /// A part file: only the lists. Source may be overridden per item.
    public struct Part: Codable, Sendable, Hashable {
        public var vocabulary: [Vocabulary]
        public var grammar: [Grammar]
        public var questions: [Question]

        public init(vocabulary: [Vocabulary] = [], grammar: [Grammar] = [], questions: [Question] = []) {
            self.vocabulary = vocabulary
            self.grammar = grammar
            self.questions = questions
        }

        enum CodingKeys: String, CodingKey { case vocabulary, grammar, questions }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            vocabulary = try container.decodeIfPresent([Vocabulary].self, forKey: .vocabulary) ?? []
            grammar = try container.decodeIfPresent([Grammar].self, forKey: .grammar) ?? []
            questions = try container.decodeIfPresent([Question].self, forKey: .questions) ?? []
        }
    }

    public struct Source: Codable, Sendable, Hashable {
        public var origin: ContentSource.Origin
        public var name: String
        public var license: String
        public var url: String?

        public init(origin: ContentSource.Origin, name: String, license: String, url: String? = nil) {
            self.origin = origin
            self.name = name
            self.license = license
            self.url = url
        }

        var domain: ContentSource { ContentSource(origin: origin, name: name, license: license, url: url) }
    }

    /// Khmer review state. Authoring metadata, never stored in the app database.
    public enum ReviewStatus: String, Codable, Sendable, CaseIterable {
        case pending
        case reviewed
    }

    public struct Text: Codable, Sendable, Hashable {
        public var en: String
        public var km: String
        public init(en: String, km: String) { self.en = en; self.km = km }
        var gloss: Gloss { Gloss(english: en, khmer: km) }
    }

    public struct Example: Codable, Sendable, Hashable {
        public var ko: String
        public var en: String
        public var km: String
        public init(ko: String, en: String, km: String) { self.ko = ko; self.en = en; self.km = km }
        var domain: ExampleSentence { ExampleSentence(korean: ko, translation: Gloss(english: en, khmer: km)) }
    }

    public struct Vocabulary: Codable, Sendable, Hashable {
        public var id: String
        public var hangul: String
        public var romanization: String
        public var hanja: String?
        public var pos: PartOfSpeech
        public var level: Int
        public var category: String
        public var meaning: Text
        public var examples: [Example]
        public var source: Source?
        public var review: ReviewStatus?

        public init(id: String, hangul: String, romanization: String, hanja: String? = nil, pos: PartOfSpeech, level: Int, category: String, meaning: Text, examples: [Example] = [], source: Source? = nil, review: ReviewStatus? = nil) {
            self.id = id; self.hangul = hangul; self.romanization = romanization; self.hanja = hanja; self.pos = pos
            self.level = level; self.category = category; self.meaning = meaning; self.examples = examples; self.source = source; self.review = review
        }

        enum CodingKeys: String, CodingKey { case id, hangul, romanization, hanja, pos, level, category, meaning, examples, source, review }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            hangul = try c.decode(String.self, forKey: .hangul)
            romanization = try c.decode(String.self, forKey: .romanization)
            hanja = try c.decodeIfPresent(String.self, forKey: .hanja)
            pos = try c.decode(PartOfSpeech.self, forKey: .pos)
            level = try c.decode(Int.self, forKey: .level)
            category = try c.decode(String.self, forKey: .category)
            meaning = try c.decode(Text.self, forKey: .meaning)
            examples = try c.decodeIfPresent([Example].self, forKey: .examples) ?? []
            source = try c.decodeIfPresent(Source.self, forKey: .source)
            review = try c.decodeIfPresent(ReviewStatus.self, forKey: .review)
        }
    }

    public struct Grammar: Codable, Sendable, Hashable {
        public var id: String
        public var pattern: String
        public var level: Int
        public var category: String
        public var explanation: Text
        public var formation: Text?
        public var examples: [Example]
        public var related: [String]
        public var source: Source?
        public var review: ReviewStatus?

        public init(id: String, pattern: String, level: Int, category: String, explanation: Text, formation: Text? = nil, examples: [Example] = [], related: [String] = [], source: Source? = nil, review: ReviewStatus? = nil) {
            self.id = id; self.pattern = pattern; self.level = level; self.category = category; self.explanation = explanation
            self.formation = formation; self.examples = examples; self.related = related; self.source = source; self.review = review
        }

        enum CodingKeys: String, CodingKey { case id, pattern, level, category, explanation, formation, examples, related, source, review }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            pattern = try c.decode(String.self, forKey: .pattern)
            level = try c.decode(Int.self, forKey: .level)
            category = try c.decode(String.self, forKey: .category)
            explanation = try c.decode(Text.self, forKey: .explanation)
            formation = try c.decodeIfPresent(Text.self, forKey: .formation)
            examples = try c.decodeIfPresent([Example].self, forKey: .examples) ?? []
            related = try c.decodeIfPresent([String].self, forKey: .related) ?? []
            source = try c.decodeIfPresent(Source.self, forKey: .source)
            review = try c.decodeIfPresent(ReviewStatus.self, forKey: .review)
        }
    }

    /// Options are plain strings; ids `o1`, `o2`, ... are derived from position so
    /// learner attempts stay valid as long as option order is not changed.
    public struct Question: Codable, Sendable, Hashable {
        public var id: String
        public var kind: QuestionKind
        public var level: Int
        public var prompt: String
        public var passage: String?
        public var options: [String]
        /// Zero-based index into `options`.
        public var answer: Int
        public var explanation: Text
        public var vocabulary: String?
        public var grammar: String?
        public var source: Source?
        public var review: ReviewStatus?

        public init(id: String, kind: QuestionKind, level: Int, prompt: String, passage: String? = nil, options: [String], answer: Int, explanation: Text, vocabulary: String? = nil, grammar: String? = nil, source: Source? = nil, review: ReviewStatus? = nil) {
            self.id = id; self.kind = kind; self.level = level; self.prompt = prompt; self.passage = passage; self.options = options
            self.answer = answer; self.explanation = explanation; self.vocabulary = vocabulary; self.grammar = grammar; self.source = source; self.review = review
        }

        enum CodingKeys: String, CodingKey { case id, kind, level, prompt, passage, options, answer, explanation, vocabulary, grammar, source, review }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            kind = try c.decode(QuestionKind.self, forKey: .kind)
            level = try c.decode(Int.self, forKey: .level)
            prompt = try c.decode(String.self, forKey: .prompt)
            passage = try c.decodeIfPresent(String.self, forKey: .passage)
            options = try c.decode([String].self, forKey: .options)
            answer = try c.decode(Int.self, forKey: .answer)
            explanation = try c.decode(Text.self, forKey: .explanation)
            vocabulary = try c.decodeIfPresent(String.self, forKey: .vocabulary)
            grammar = try c.decodeIfPresent(String.self, forKey: .grammar)
            source = try c.decodeIfPresent(Source.self, forKey: .source)
            review = try c.decodeIfPresent(ReviewStatus.self, forKey: .review)
        }
    }

    // MARK: Decoding

    public enum Error: Swift.Error, CustomStringConvertible, Sendable {
        case unsupportedFormat(found: Int, supported: Int)
        case malformed(file: String, detail: String)
        case invalid([ContentPackageIssue])

        public var description: String {
            switch self {
            case let .unsupportedFormat(found, supported): return "content format \(found) is not supported (app supports \(supported))"
            case let .malformed(file, detail): return "\(file): \(detail)"
            case let .invalid(issues): return "content has \(issues.count) issue(s):\n" + issues.map { "  - \($0.description)" }.joined(separator: "\n")
            }
        }
    }

    public static func decoder() -> JSONDecoder { JSONDecoder() }

    /// Decodes `package.json` and merges any part files, then validates everything.
    /// Throws before returning a package that would be rejected by the store (AC-10).
    public static func load(package data: Data, parts: [(name: String, data: Data)] = []) throws -> LoadResult {
        let decoder = decoder()
        let package: Package
        do { package = try decoder.decode(Package.self, from: data) } catch { throw Error.malformed(file: "package.json", detail: String(describing: error)) }
        guard package.formatVersion == supportedFormatVersion else {
            throw Error.unsupportedFormat(found: package.formatVersion, supported: supportedFormatVersion)
        }
        var vocabulary = package.vocabulary
        var grammar = package.grammar
        var questions = package.questions
        for part in parts.sorted(by: { $0.name < $1.name }) {
            let decoded: Part
            do { decoded = try decoder.decode(Part.self, from: part.data) } catch { throw Error.malformed(file: part.name, detail: String(describing: error)) }
            vocabulary += decoded.vocabulary
            grammar += decoded.grammar
            questions += decoded.questions
        }
        return try build(version: package.version, source: package.source, vocabulary: vocabulary, grammar: grammar, questions: questions)
    }

    public struct LoadResult: Sendable {
        public let package: ContentPackage
        public let pendingReview: Int
        public let source: ContentSource
    }

    static func build(version: Int, source: Source, vocabulary: [Vocabulary], grammar: [Grammar], questions: [Question]) throws -> LoadResult {
        var issues: [ContentPackageIssue] = []
        var pending = 0

        func level(_ raw: Int, kind: String, id: String) -> TOPIKLevel {
            if let level = TOPIKLevel(rawValue: raw) { return level }
            issues.append(.invalidField(kind: kind, id: id, field: "level \(raw) must be 1...6"))
            return .level1
        }
        func checkID(_ id: String, kind: String) {
            if !id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_") }) || id.isEmpty {
                issues.append(.invalidField(kind: kind, id: id, field: "id must be ASCII letters, digits, '.', '-' or '_'"))
            }
        }
        func checkExamples(_ examples: [Example], kind: String, id: String) {
            for example in examples where example.ko.isEmpty || example.en.isEmpty || example.km.isEmpty {
                issues.append(.invalidField(kind: kind, id: id, field: "example needs ko, en and km"))
            }
        }

        let items: [VocabularyItem] = vocabulary.map { entry in
            checkID(entry.id, kind: "vocabulary")
            if entry.romanization.isEmpty { issues.append(.invalidField(kind: "vocabulary", id: entry.id, field: "romanization")) }
            checkExamples(entry.examples, kind: "vocabulary", id: entry.id)
            if entry.review == .pending { pending += 1 }
            return VocabularyItem(
                id: VocabularyID(entry.id), hangul: entry.hangul, romanization: entry.romanization, hanja: entry.hanja,
                partOfSpeech: entry.pos, level: level(entry.level, kind: "vocabulary", id: entry.id), category: entry.category,
                meaning: entry.meaning.gloss, examples: entry.examples.map(\.domain),
                source: (entry.source ?? source).domain, contentVersion: version
            )
        }
        let grammarIDs = Set(grammar.map(\.id))
        let patterns: [GrammarPattern] = grammar.map { entry in
            checkID(entry.id, kind: "grammar")
            checkExamples(entry.examples, kind: "grammar", id: entry.id)
            for related in entry.related where !grammarIDs.contains(related) {
                issues.append(.danglingReference(questionID: entry.id, target: related))
            }
            if entry.review == .pending { pending += 1 }
            return GrammarPattern(
                id: GrammarID(entry.id), pattern: entry.pattern, level: level(entry.level, kind: "grammar", id: entry.id), category: entry.category,
                explanation: entry.explanation.gloss, formation: entry.formation?.gloss, examples: entry.examples.map(\.domain),
                relatedPatternIDs: entry.related.map { GrammarID($0) }, source: (entry.source ?? source).domain, contentVersion: version
            )
        }
        let decodedQuestions: [Domain.Question] = questions.map { entry in
            checkID(entry.id, kind: "question")
            if !entry.options.indices.contains(entry.answer) {
                issues.append(.invalidField(kind: "question", id: entry.id, field: "answer \(entry.answer) is outside options"))
            }
            if entry.review == .pending { pending += 1 }
            let options = entry.options.enumerated().map { QuestionOption(id: OptionID("o\($0.offset + 1)"), text: $0.element) }
            return Domain.Question(
                id: QuestionID(entry.id), kind: entry.kind, level: level(entry.level, kind: "question", id: entry.id),
                prompt: entry.prompt, passage: entry.passage, options: options,
                correctOptionID: OptionID("o\(entry.answer + 1)"), explanation: entry.explanation.gloss,
                relatedVocabularyID: entry.vocabulary.map { VocabularyID($0) }, relatedGrammarID: entry.grammar.map { GrammarID($0) },
                source: (entry.source ?? source).domain, contentVersion: version
            )
        }
        let package = ContentPackage(version: version, vocabulary: items, grammar: patterns, questions: decodedQuestions)
        issues += package.validate()
        guard issues.isEmpty else { throw Error.invalid(issues) }
        return LoadResult(package: package, pendingReview: pending, source: source.domain)
    }
}
