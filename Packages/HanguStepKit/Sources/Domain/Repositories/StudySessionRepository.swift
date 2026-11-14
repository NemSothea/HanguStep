import Foundation

/// Learner sessions (PRD FR-P1, FR-Q6). Synced via CloudKit in Phase 6.
public protocol StudySessionRepository: Sendable {
    /// Insert or replace by id.
    func save(_ session: StudySession) async throws
    func session(id: StudySessionID) async throws -> StudySession?
    /// Most recently started session without an end date, if any.
    func unfinishedSession() async throws -> StudySession?
    func sessions(limit: Int) async throws -> [StudySession]
}
