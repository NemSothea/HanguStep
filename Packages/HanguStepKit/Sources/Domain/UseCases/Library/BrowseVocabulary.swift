import Foundation

public protocol BrowseVocabularyUseCase: Sendable {
    func execute(query: String, filter: VocabularyFilter) async throws -> [VocabularyItem]
}

public struct BrowseVocabulary: BrowseVocabularyUseCase {
    private let vocabulary: any VocabularyRepository

    public init(vocabulary: any VocabularyRepository) {
        self.vocabulary = vocabulary
    }

    public func execute(query: String, filter: VocabularyFilter) async throws -> [VocabularyItem] {
        try await vocabulary.search(query, filter: filter)
    }
}

public struct VocabularyDetail: Hashable, Sendable {
    public let item: VocabularyItem
    public var isBookmarked: Bool
    public var note: LearnerNote?

    public init(item: VocabularyItem, isBookmarked: Bool, note: LearnerNote?) {
        self.item = item
        self.isBookmarked = isBookmarked
        self.note = note
    }
}

public protocol GetVocabularyDetailUseCase: Sendable {
    func execute(id: VocabularyID) async throws -> VocabularyDetail
}

public struct GetVocabularyDetail: GetVocabularyDetailUseCase {
    private let vocabulary: any VocabularyRepository
    private let bookmarks: any BookmarkRepository
    private let notes: any LearnerNoteRepository

    public init(vocabulary: any VocabularyRepository, bookmarks: any BookmarkRepository, notes: any LearnerNoteRepository) {
        self.vocabulary = vocabulary
        self.bookmarks = bookmarks
        self.notes = notes
    }

    public func execute(id: VocabularyID) async throws -> VocabularyDetail {
        guard let item = try await vocabulary.item(id: id) else {
            throw DomainError.notFound(entity: "VocabularyItem", id: id.rawValue)
        }
        let target = LearningTarget.vocabulary(id)
        async let bookmarked = bookmarks.contains(target: target)
        async let note = notes.note(for: target)
        return try await VocabularyDetail(item: item, isBookmarked: bookmarked, note: note)
    }
}
