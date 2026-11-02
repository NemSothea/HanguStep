import Foundation

public enum PartOfSpeech: String, Sendable, Codable, CaseIterable {
    case noun, verb, adjective, adverb, particle, pronoun, numeral
    case determiner, interjection, suffix, expression, other
}

public struct VocabularyItem: Identifiable, Hashable, Sendable, Codable {
    public let id: VocabularyID
    public var hangul: String
    public var romanization: String
    public var hanja: String?
    public var partOfSpeech: PartOfSpeech
    public var level: TOPIKLevel
    public var category: String
    public var meaning: Gloss
    public var examples: [ExampleSentence]
    public var source: ContentSource
    public var contentVersion: Int

    public init(
        id: VocabularyID,
        hangul: String,
        romanization: String,
        hanja: String? = nil,
        partOfSpeech: PartOfSpeech,
        level: TOPIKLevel,
        category: String,
        meaning: Gloss,
        examples: [ExampleSentence] = [],
        source: ContentSource,
        contentVersion: Int
    ) {
        self.id = id
        self.hangul = hangul
        self.romanization = romanization
        self.hanja = hanja
        self.partOfSpeech = partOfSpeech
        self.level = level
        self.category = category
        self.meaning = meaning
        self.examples = examples
        self.source = source
        self.contentVersion = contentVersion
    }
}
