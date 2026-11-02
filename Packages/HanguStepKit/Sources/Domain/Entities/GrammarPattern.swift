import Foundation

public struct GrammarPattern: Identifiable, Hashable, Sendable, Codable {
    public let id: GrammarID
    public var pattern: String
    public var level: TOPIKLevel
    public var category: String
    public var explanation: Gloss
    public var formation: Gloss?
    public var examples: [ExampleSentence]
    public var relatedPatternIDs: [GrammarID]
    public var source: ContentSource
    public var contentVersion: Int

    public init(
        id: GrammarID,
        pattern: String,
        level: TOPIKLevel,
        category: String,
        explanation: Gloss,
        formation: Gloss? = nil,
        examples: [ExampleSentence] = [],
        relatedPatternIDs: [GrammarID] = [],
        source: ContentSource,
        contentVersion: Int
    ) {
        self.id = id
        self.pattern = pattern
        self.level = level
        self.category = category
        self.explanation = explanation
        self.formation = formation
        self.examples = examples
        self.relatedPatternIDs = relatedPatternIDs
        self.source = source
        self.contentVersion = contentVersion
    }
}
