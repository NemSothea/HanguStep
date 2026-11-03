import Foundation

/// SM-2 schedule per learning target (PRD FR-R3, FR-R4). Synced via CloudKit in Phase 6.
public protocol ReviewScheduleRepository: Sendable {
    func schedule(for target: LearningTarget) async throws -> ReviewSchedule?
    /// Insert or replace by target.
    func upsert(_ schedule: ReviewSchedule) async throws
    /// Due items, earliest review date first.
    func due(onOrBefore date: Date, limit: Int) async throws -> [ReviewSchedule]
    /// Every schedule. Counts (due, mastered) derive from this.
    func all() async throws -> [ReviewSchedule]
}
