@preconcurrency import CoreData
import Domain
import Foundation

/// Writing answers in the learner store (synced with CloudKit when enabled).
/// Feedback is kept as JSON: it is shown, never queried.
public struct CoreDataWritingAttemptRepository: WritingAttemptRepository {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func save(_ attempt: WritingAttempt) async throws {
        let feedbackJSON = try attempt.feedback.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) }
        try await context.perform {
            let request = NSFetchRequest<CDWritingAttempt>(entityName: "CDWritingAttempt")
            request.predicate = NSPredicate(format: "id == %@", attempt.id.uuidString)
            request.fetchLimit = 1
            let row = try context.fetch(request).first ?? {
                let new = CDWritingAttempt(context: context)
                new.id = attempt.id.uuidString
                new.taskID = attempt.taskID.rawValue
                new.createdAt = attempt.createdAt
                return new
            }()
            row.text = attempt.text
            row.feedbackJSON = feedbackJSON
            try context.save()
        }
    }

    public func attempts(for taskID: WritingTaskID) async throws -> [WritingAttempt] {
        try await fetch(NSPredicate(format: "taskID == %@", taskID.rawValue))
    }

    public func allAttempts() async throws -> [WritingAttempt] {
        try await fetch(nil)
    }

    /// Newest first.
    private func fetch(_ predicate: NSPredicate?) async throws -> [WritingAttempt] {
        try await context.perform {
            let request = NSFetchRequest<CDWritingAttempt>(entityName: "CDWritingAttempt")
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try context.fetch(request).compactMap(Self.attempt(from:))
        }
    }

    private static func attempt(from row: CDWritingAttempt) -> WritingAttempt? {
        guard let id = UUID(uuidString: row.id), !row.taskID.isEmpty else { return nil }
        let feedback = row.feedbackJSON.flatMap { try? JSONDecoder().decode(WritingFeedback.self, from: Data($0.utf8)) }
        return WritingAttempt(id: id, taskID: WritingTaskID(row.taskID), text: row.text, createdAt: row.createdAt ?? .distantPast, feedback: feedback)
    }
}
