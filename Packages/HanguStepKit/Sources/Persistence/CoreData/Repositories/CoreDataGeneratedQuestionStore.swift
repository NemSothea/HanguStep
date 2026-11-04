import CoreData
import Domain
import Foundation

/// Stores assistant-generated questions in the content store beside the bundled
/// library. Rows carry `sourceOrigin == aiGenerated`, so `CoreDataContentStore`
/// leaves them alone on import and the ordinary question repository serves them.
public struct CoreDataGeneratedQuestionStore: GeneratedQuestionStore {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func save(_ questions: [Question]) async throws {
        let issues = questions.flatMap { $0.validate() }
        guard issues.isEmpty else { throw DomainError.invalidContent(issues: issues) }
        guard questions.allSatisfy({ $0.source.origin == .aiGenerated }) else {
            throw DomainError.invalidPackage(issues: ["only aiGenerated questions may be stored here"])
        }
        try await context.perform {
            for question in questions {
                let request = NSFetchRequest<CDQuestion>(entityName: "CDQuestion")
                request.predicate = NSPredicate(format: "id == %@", question.id.rawValue)
                request.fetchLimit = 1
                let row = try context.fetch(request).first ?? {
                    let new = CDQuestion(context: context)
                    new.id = question.id.rawValue
                    return new
                }()
                CoreDataContentStore.fill(row, from: question, context: context)
            }
            try context.save()
        }
    }

    public func generated(for target: LearningTarget) async throws -> [Question] {
        try await context.perform {
            let request = NSFetchRequest<CDQuestion>(entityName: "CDQuestion")
            let targetPredicate: NSPredicate
            switch target {
            case let .vocabulary(id): targetPredicate = NSPredicate(format: "relatedVocabularyID == %@", id.rawValue)
            case let .grammar(id): targetPredicate = NSPredicate(format: "relatedGrammarID == %@", id.rawValue)
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [Self.generatedPredicate, targetPredicate])
            request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
            return try context.fetch(request).map(ContentMapping.question)
        }
    }

    public func generatedCount() async throws -> Int {
        try await context.perform {
            let request = NSFetchRequest<CDQuestion>(entityName: "CDQuestion")
            request.predicate = Self.generatedPredicate
            return try context.count(for: request)
        }
    }

    /// Hard delete. Attempts keep their copied target, so history stays readable
    /// even though the question text is gone.
    public func deleteAllGenerated() async throws -> Int {
        try await context.perform {
            let request = NSFetchRequest<CDQuestion>(entityName: "CDQuestion")
            request.predicate = Self.generatedPredicate
            let rows = try context.fetch(request)
            for row in rows { context.delete(row) }
            try context.save()
            return rows.count
        }
    }

    private static var generatedPredicate: NSPredicate {
        NSPredicate(format: "sourceOrigin == %@ AND isRetired == NO", ContentSource.Origin.aiGenerated.rawValue)
    }
}
