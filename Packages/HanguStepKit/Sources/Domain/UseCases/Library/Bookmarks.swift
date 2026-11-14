import Foundation

public protocol ToggleBookmarkUseCase: Sendable {
    /// Returns the new state.
    func execute(target: LearningTarget) async throws -> Bool
}

public struct ToggleBookmark: ToggleBookmarkUseCase {
    private let bookmarks: any BookmarkRepository
    private let ids: any IDGenerator
    private let dates: any DateProvider

    public init(bookmarks: any BookmarkRepository, ids: any IDGenerator = UUIDGenerator(), dates: any DateProvider = SystemDateProvider()) {
        self.bookmarks = bookmarks
        self.ids = ids
        self.dates = dates
    }

    public func execute(target: LearningTarget) async throws -> Bool {
        if try await bookmarks.contains(target: target) {
            try await bookmarks.remove(target: target)
            return false
        }
        try await bookmarks.add(Bookmark(id: BookmarkID(ids.next()), target: target, createdAt: dates.now()))
        return true
    }
}

public struct BookmarkEntry: Hashable, Sendable, Identifiable {
    public var id: LearningTarget { bookmark.target }
    public let bookmark: Bookmark
    public let title: String
    public let gloss: Gloss
    public let level: TOPIKLevel

    public init(bookmark: Bookmark, title: String, gloss: Gloss, level: TOPIKLevel) {
        self.bookmark = bookmark
        self.title = title
        self.gloss = gloss
        self.level = level
    }
}

public protocol ListBookmarksUseCase: Sendable {
    func execute() async throws -> [BookmarkEntry]
}

public struct ListBookmarks: ListBookmarksUseCase {
    private let bookmarks: any BookmarkRepository
    private let vocabulary: any VocabularyRepository
    private let grammar: any GrammarRepository

    public init(bookmarks: any BookmarkRepository, vocabulary: any VocabularyRepository, grammar: any GrammarRepository) {
        self.bookmarks = bookmarks
        self.vocabulary = vocabulary
        self.grammar = grammar
    }

    public func execute() async throws -> [BookmarkEntry] {
        var entries: [BookmarkEntry] = []
        for bookmark in try await bookmarks.all() {
            switch bookmark.target {
            case let .vocabulary(id):
                if let item = try await vocabulary.item(id: id) {
                    entries.append(BookmarkEntry(bookmark: bookmark, title: item.hangul, gloss: item.meaning, level: item.level))
                }
            case let .grammar(id):
                if let pattern = try await grammar.pattern(id: id) {
                    entries.append(BookmarkEntry(bookmark: bookmark, title: pattern.pattern, gloss: pattern.explanation, level: pattern.level))
                }
            }
        }
        return entries
    }
}

public protocol SaveNoteUseCase: Sendable {
    func execute(target: LearningTarget, text: String) async throws -> LearnerNote?
}

public struct SaveNote: SaveNoteUseCase {
    private let notes: any LearnerNoteRepository
    private let ids: any IDGenerator
    private let dates: any DateProvider

    public init(notes: any LearnerNoteRepository, ids: any IDGenerator = UUIDGenerator(), dates: any DateProvider = SystemDateProvider()) {
        self.notes = notes
        self.ids = ids
        self.dates = dates
    }

    /// Returns the stored note, or nil when the text was empty and the note removed.
    public func execute(target: LearningTarget, text: String) async throws -> LearnerNote? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = try await notes.note(for: target)
        let note = LearnerNote(id: existing?.id ?? LearnerNoteID(ids.next()), target: target, text: trimmed, modifiedAt: dates.now())
        try await notes.upsert(note)
        return try await notes.note(for: target)
    }
}
