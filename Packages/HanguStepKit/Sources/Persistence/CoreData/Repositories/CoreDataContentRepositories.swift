import CoreData
import Domain
import Foundation

/// Read side of the content store. Thread safety comes from `context.perform`;
/// the struct itself only holds the (Sendable) context.
public struct CoreDataVocabularyRepository: VocabularyRepository {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func item(id: VocabularyID) async throws -> VocabularyItem? {
        try await context.perform {
            let request = CDVocabulary.fetchRequest(id: id.rawValue)
            return try context.fetch(request).first.map(ContentMapping.vocabulary)
        }
    }

    public func items(matching filter: VocabularyFilter) async throws -> [VocabularyItem] {
        try await context.perform {
            let request = NSFetchRequest<CDVocabulary>(entityName: "CDVocabulary")
            request.predicate = Self.predicate(filter: filter, query: nil)
            request.sortDescriptors = [NSSortDescriptor(key: "hangul", ascending: true)]
            return try context.fetch(request).map(ContentMapping.vocabulary)
        }
    }

    public func search(_ query: String, filter: VocabularyFilter) async throws -> [VocabularyItem] {
        let needle = TextNormalizer.normalize(query)
        guard !needle.isEmpty else { return try await items(matching: filter) }
        return try await context.perform {
            let request = NSFetchRequest<CDVocabulary>(entityName: "CDVocabulary")
            request.predicate = Self.predicate(filter: filter, query: needle)
            request.sortDescriptors = [NSSortDescriptor(key: "hangul", ascending: true)]
            return try context.fetch(request).map(ContentMapping.vocabulary)
        }
    }

    public func count() async throws -> Int {
        try await context.perform {
            let request = NSFetchRequest<CDVocabulary>(entityName: "CDVocabulary")
            request.predicate = NSPredicate(format: "isRetired == NO")
            return try context.count(for: request)
        }
    }

    static func predicate(filter: VocabularyFilter, query: String?) -> NSPredicate {
        var predicates = [NSPredicate(format: "isRetired == NO")]
        if !filter.levels.isEmpty {
            predicates.append(NSPredicate(format: "level IN %@", filter.levels.map { $0.rawValue }))
        }
        if !filter.partsOfSpeech.isEmpty {
            predicates.append(NSPredicate(format: "partOfSpeech IN %@", filter.partsOfSpeech.map(\.rawValue)))
        }
        if let category = filter.category {
            predicates.append(NSPredicate(format: "category == %@", category))
        }
        if let query {
            predicates.append(NSPredicate(format: "searchText CONTAINS %@", query))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

public struct CoreDataGrammarRepository: GrammarRepository {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func pattern(id: GrammarID) async throws -> GrammarPattern? {
        try await context.perform {
            let request = NSFetchRequest<CDGrammar>(entityName: "CDGrammar")
            request.predicate = NSPredicate(format: "id == %@", id.rawValue)
            request.fetchLimit = 1
            return try context.fetch(request).first.map(ContentMapping.grammar)
        }
    }

    public func patterns(level: TOPIKLevel?) async throws -> [GrammarPattern] {
        try await context.perform {
            let request = NSFetchRequest<CDGrammar>(entityName: "CDGrammar")
            var predicates = [NSPredicate(format: "isRetired == NO")]
            if let level { predicates.append(NSPredicate(format: "level == %d", level.rawValue)) }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "level", ascending: true), NSSortDescriptor(key: "pattern", ascending: true)]
            return try context.fetch(request).map(ContentMapping.grammar)
        }
    }

    public func count() async throws -> Int {
        try await context.perform {
            let request = NSFetchRequest<CDGrammar>(entityName: "CDGrammar")
            request.predicate = NSPredicate(format: "isRetired == NO")
            return try context.count(for: request)
        }
    }
}

public struct CoreDataQuestionRepository: QuestionRepository {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func question(id: QuestionID) async throws -> Question? {
        try await questions(ids: [id]).first
    }

    public func questions(ids: [QuestionID]) async throws -> [Question] {
        guard !ids.isEmpty else { return [] }
        return try await context.perform {
            let request = NSFetchRequest<CDQuestion>(entityName: "CDQuestion")
            request.predicate = NSPredicate(format: "id IN %@", ids.map(\.rawValue))
            let byID = Dictionary(uniqueKeysWithValues: try context.fetch(request).map { ($0.id, ContentMapping.question($0)) })
            // Preserve the caller's order; sessions depend on it.
            return ids.compactMap { byID[$0.rawValue] }
        }
    }

    public func questions(matching filter: QuestionFilter) async throws -> [Question] {
        try await context.perform {
            let request = NSFetchRequest<CDQuestion>(entityName: "CDQuestion")
            var predicates = [NSPredicate(format: "isRetired == NO")]
            if !filter.levels.isEmpty { predicates.append(NSPredicate(format: "level IN %@", filter.levels.map { $0.rawValue })) }
            if !filter.kinds.isEmpty { predicates.append(NSPredicate(format: "kind IN %@", filter.kinds.map(\.rawValue))) }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
            return try context.fetch(request).map(ContentMapping.question)
        }
    }

    public func count() async throws -> Int {
        try await context.perform {
            let request = NSFetchRequest<CDQuestion>(entityName: "CDQuestion")
            request.predicate = NSPredicate(format: "isRetired == NO")
            return try context.count(for: request)
        }
    }
}

extension CDVocabulary {
    static func fetchRequest(id: String) -> NSFetchRequest<CDVocabulary> {
        let request = NSFetchRequest<CDVocabulary>(entityName: "CDVocabulary")
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return request
    }
}
