import Foundation

public protocol LearnerNoteRepository: Sendable {
    func note(for target: LearningTarget) async throws -> LearnerNote?
    /// Insert or replace by target. Empty text removes the note.
    func upsert(_ note: LearnerNote) async throws
    func remove(target: LearningTarget) async throws
}
