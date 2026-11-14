import Foundation

/// Append-only store of learner answers (PRD FR-Q4, FR-P6). Synced via CloudKit in Phase 6.
public protocol AttemptRepository: Sendable {
    /// Throws `DomainError.duplicateSubmission` if an attempt for the same
    /// session and question already exists (PRD FR-Q3).
    func record(_ attempt: Attempt) async throws
    func attempts(inSession sessionID: StudySessionID) async throws -> [Attempt]
    func attempts(forQuestion questionID: QuestionID) async throws -> [Attempt]
    func summary() async throws -> AttemptSummary
    /// Every attempt, oldest first. Statistics and mistakes derive from this.
    func allAttempts() async throws -> [Attempt]
}
