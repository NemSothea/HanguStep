import CoreData
import Domain
import Foundation

/// Removes rows that two devices created independently before they synced
/// (DATABASE_SCHEMA.md §4, PRD FR-S6, risk R3). CloudKit has no uniqueness
/// constraints, so a bookmark added on iPhone and Mac for the same word arrives
/// as two rows. Policy per entity:
///
/// | Entity | Key | Survivor |
/// |---|---|---|
/// | CDBookmark, CDLearnerNote | target | latest `modifiedAt` |
/// | CDReviewSchedule | target | latest `lastReviewedAt`, then `modifiedAt` |
/// | CDLearnerSettings | `id` | latest `modifiedAt` |
/// | CDStudySession | `id` | latest `modifiedAt` |
/// | CDAttempt | `sessionID` + `questionID` | earliest `answeredAt` (first answer counts, FR-Q3) |
public struct LearnerDeduplicator: Sendable {
    public struct Report: Hashable, Sendable {
        public var removed: [String: Int] = [:]
        public var total: Int { removed.values.reduce(0, +) }
        public var isEmpty: Bool { total == 0 }
    }

    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    @discardableResult
    public func run() async throws -> Report {
        try await context.perform {
            var report = Report()
            report.removed["CDBookmark"] = try dedupe("CDBookmark", key: Self.targetKey, keep: Self.latestModified)
            report.removed["CDLearnerNote"] = try dedupe("CDLearnerNote", key: Self.targetKey, keep: Self.latestModified)
            report.removed["CDReviewSchedule"] = try dedupe("CDReviewSchedule", key: Self.targetKey) { rows in
                rows.max { lhs, rhs in
                    (Self.date(lhs, "lastReviewedAt", or: .distantPast), Self.date(lhs, "modifiedAt", or: .distantPast), Self.idKey(lhs))
                        < (Self.date(rhs, "lastReviewedAt", or: .distantPast), Self.date(rhs, "modifiedAt", or: .distantPast), Self.idKey(rhs))
                }
            }
            report.removed["CDLearnerSettings"] = try dedupe("CDLearnerSettings", key: Self.idKey, keep: Self.latestModified)
            report.removed["CDStudySession"] = try dedupe("CDStudySession", key: Self.idKey, keep: Self.latestModified)
            report.removed["CDAttempt"] = try dedupe("CDAttempt", key: { row in
                "\(row.value(forKey: "sessionID") as? String ?? "")|\(row.value(forKey: "questionID") as? String ?? "")"
            }) { rows in
                rows.min { (Self.date($0, "answeredAt", or: .distantFuture), Self.idKey($0)) < (Self.date($1, "answeredAt", or: .distantFuture), Self.idKey($1)) }
            }
            if context.hasChanges { try context.save() }
            return report
        }
    }

    private func dedupe(_ entity: String, key: (NSManagedObject) -> String, keep: ([NSManagedObject]) -> NSManagedObject?) throws -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        let groups = Dictionary(grouping: try context.fetch(request), by: key)
        var removed = 0
        for rows in groups.values where rows.count > 1 {
            guard let survivor = keep(rows) else { continue }
            for row in rows where row !== survivor {
                context.delete(row)
                removed += 1
            }
        }
        return removed
    }

    private static func targetKey(_ row: NSManagedObject) -> String {
        "\(row.value(forKey: "targetKind") as? String ?? "")|\(row.value(forKey: "targetID") as? String ?? "")"
    }

    private static func idKey(_ row: NSManagedObject) -> String {
        row.value(forKey: "id") as? String ?? ""
    }

    /// Ties on the policy date fall back to the row id so every device picks the same
    /// survivor; otherwise two devices could each delete the other's row.
    private static func latestModified(_ rows: [NSManagedObject]) -> NSManagedObject? {
        rows.max { (date($0, "modifiedAt", or: .distantPast), idKey($0)) < (date($1, "modifiedAt", or: .distantPast), idKey($1)) }
    }

    private static func date(_ row: NSManagedObject, _ key: String, or fallback: Date) -> Date {
        row.value(forKey: key) as? Date ?? fallback
    }
}
