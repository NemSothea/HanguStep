import Foundation

public struct VocabularyFilter: Hashable, Sendable {
    public var levels: Set<TOPIKLevel>
    public var partsOfSpeech: Set<PartOfSpeech>
    public var category: String?

    public init(levels: Set<TOPIKLevel> = [], partsOfSpeech: Set<PartOfSpeech> = [], category: String? = nil) {
        self.levels = levels
        self.partsOfSpeech = partsOfSpeech
        self.category = category
    }

    public static let all = VocabularyFilter()

    public func matches(_ item: VocabularyItem) -> Bool {
        if !levels.isEmpty, !levels.contains(item.level) { return false }
        if !partsOfSpeech.isEmpty, !partsOfSpeech.contains(item.partOfSpeech) { return false }
        if let category, item.category != category { return false }
        return true
    }
}

/// Read-only access to bundled vocabulary content (PRD FR-V1 to FR-V3).
public protocol VocabularyRepository: Sendable {
    func item(id: VocabularyID) async throws -> VocabularyItem?
    func items(matching filter: VocabularyFilter) async throws -> [VocabularyItem]
    /// Matches hangul, romanization, English or Khmer. Case-insensitive, Unicode-normalized.
    func search(_ query: String, filter: VocabularyFilter) async throws -> [VocabularyItem]
    func count() async throws -> Int
}
