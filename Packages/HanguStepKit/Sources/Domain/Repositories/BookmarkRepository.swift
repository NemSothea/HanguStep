import Foundation

/// Learner bookmarks (PRD FR-V4, FR-G3). Synced via CloudKit in Phase 6.
public protocol BookmarkRepository: Sendable {
    func add(_ bookmark: Bookmark) async throws
    func remove(target: LearningTarget) async throws
    func contains(target: LearningTarget) async throws -> Bool
    func all() async throws -> [Bookmark]
}
