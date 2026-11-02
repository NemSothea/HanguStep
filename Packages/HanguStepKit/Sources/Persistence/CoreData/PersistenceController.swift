import CoreData
import Domain
import Foundation

/// Owns the Core Data container with its two stores. See DATABASE_SCHEMA.md.
public final class PersistenceController: Sendable {
    public enum Mode: Sendable {
        /// Both stores in memory. Tests and previews.
        case inMemory
        /// SQLite files inside `directory`.
        case onDisk(directory: URL)
    }

    public enum Failure: Error, Sendable {
        case modelNotFound
        case storeFailed(configuration: String, description: String)
    }

    static let contentConfiguration = "Content"
    static let learnerConfiguration = "Learner"

    let container: NSPersistentContainer

    public let mode: Mode

    /// Loads the model and opens both stores synchronously. The content store is
    /// rebuilt from scratch if it cannot be opened, because it holds no user data.
    public init(mode: Mode) throws {
        self.mode = mode
        let model = try Self.loadModel()
        container = NSPersistentContainer(name: "HanguStep", managedObjectModel: model)
        container.persistentStoreDescriptions = [
            Self.description(for: Self.contentConfiguration, mode: mode),
            Self.description(for: Self.learnerConfiguration, mode: mode),
        ]
        try loadStores(rebuildContentOnFailure: true)
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    /// A background context for one repository. Each repository owns its own.
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    public var viewContext: NSManagedObjectContext { container.viewContext }

    // MARK: - Setup

    static func loadModel() throws -> NSManagedObjectModel {
        guard let url = Bundle.module.url(forResource: "HanguStep", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url)
        else { throw Failure.modelNotFound }
        return model
    }

    static func description(for configuration: String, mode: Mode) -> NSPersistentStoreDescription {
        let description: NSPersistentStoreDescription
        switch mode {
        case .inMemory:
            description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.url = URL(fileURLWithPath: "/dev/null/\(configuration)")
        case let .onDisk(directory):
            description = NSPersistentStoreDescription(url: directory.appendingPathComponent("\(configuration).sqlite"))
            description.type = NSSQLiteStoreType
        }
        description.configuration = configuration
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.shouldAddStoreAsynchronously = false
        return description
    }

    private func loadStores(rebuildContentOnFailure: Bool) throws {
        var failures: [(String, Error)] = []
        container.loadPersistentStores { description, error in
            if let error { failures.append((description.configuration ?? "?", error)) }
        }
        guard let failure = failures.first else { return }
        if rebuildContentOnFailure,
           failure.0 == Self.contentConfiguration,
           case .onDisk = mode,
           let url = container.persistentStoreDescriptions.first(where: { $0.configuration == Self.contentConfiguration })?.url
        {
            try container.persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
            try loadStores(rebuildContentOnFailure: false)
            return
        }
        throw Failure.storeFailed(configuration: failure.0, description: String(describing: failure.1))
    }

    // MARK: - Reset

    /// Deletes every learner row. Used by Settings → Reset local data. Content is untouched.
    public func resetLearnerData() async throws {
        let context = newBackgroundContext()
        try await context.perform {
            for name in ["CDStudySession", "CDAttempt", "CDBookmark", "CDReviewSchedule", "CDLearnerNote", "CDLearnerSettings"] {
                let request = NSFetchRequest<NSManagedObject>(entityName: name)
                request.includesPropertyValues = false
                for object in try context.fetch(request) { context.delete(object) }
            }
            try context.save()
        }
    }
}

/// Shared helpers for repositories.
enum CoreDataSupport {
    static func mapError(_ error: Error) -> DomainError {
        if let domainError = error as? DomainError { return domainError }
        return .storage(description: String(describing: error))
    }

    static func encodeIDs(_ ids: [String]) -> String {
        guard let data = try? JSONEncoder().encode(ids), let string = String(data: data, encoding: .utf8) else { return "[]" }
        return string
    }

    static func decodeIDs(_ string: String) -> [String] {
        guard let data = string.data(using: .utf8), let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return ids
    }
}
