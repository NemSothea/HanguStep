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

    /// Whether the Learner store is mirrored to the private CloudKit database (ADR-003).
    public enum SyncOption: Sendable, Equatable {
        case off
        case cloudKit(containerIdentifier: String)
    }

    public enum Failure: Error, Sendable {
        case modelNotFound
        case storeFailed(configuration: String, description: String)
    }

    static let contentConfiguration = "Content"
    static let learnerConfiguration = "Learner"

    let container: NSPersistentContainer

    public let mode: Mode
    /// The sync option actually in effect. Differs from the requested one when the
    /// CloudKit-backed store failed to open and the controller fell back to local only.
    public let sync: SyncOption
    /// Why CloudKit was requested but not enabled, if that happened.
    public let syncFallbackError: String?

    /// Loads the model and opens both stores synchronously. The content store is
    /// rebuilt from scratch if it cannot be opened, because it holds no user data.
    /// A Learner store that cannot open in CloudKit mode is reopened without sync so
    /// the app always starts with the learner's local data (PRD FR-S3).
    public convenience init(mode: Mode, sync requested: SyncOption = .off) throws {
        try self.init(mode: mode, sync: requested, failLearnerStoreOnce: false)
    }

    /// `failLearnerStoreOnce` lets tests exercise the fallback path without a broken disk.
    convenience init(mode: Mode, sync requested: SyncOption, failLearnerStoreOnce: Bool) throws {
        do {
            try self.init(mode: mode, sync: requested, fallbackError: nil, failLearnerStore: failLearnerStoreOnce)
        } catch let error as Failure {
            guard case .cloudKit = requested, case let .storeFailed(configuration, description) = error, configuration == Self.learnerConfiguration else { throw error }
            try self.init(mode: mode, sync: .off, fallbackError: description, failLearnerStore: false)
        }
    }

    private init(mode: Mode, sync: SyncOption, fallbackError: String?, failLearnerStore: Bool) throws {
        self.mode = mode
        self.sync = sync
        self.syncFallbackError = fallbackError
        if failLearnerStore {
            throw Failure.storeFailed(configuration: Self.learnerConfiguration, description: "simulated CloudKit store failure")
        }
        let model = try Self.loadModel()
        switch mode {
        case .inMemory:
            container = NSPersistentContainer(name: "HanguStep", managedObjectModel: model)
        case .onDisk:
            // The CloudKit subclass behaves like a plain container until a store
            // description carries CloudKit options, so one type serves both settings.
            container = NSPersistentCloudKitContainer(name: "HanguStep", managedObjectModel: model)
        }
        container.persistentStoreDescriptions = [
            Self.description(for: Self.contentConfiguration, mode: mode),
            Self.learnerDescription(mode: mode, sync: sync),
        ]
        try loadStores(rebuildContentOnFailure: true)
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        container.viewContext.transactionAuthor = Self.transactionAuthor
    }

    public var isCloudKitEnabled: Bool {
        if case .cloudKit = sync { return true }
        return false
    }

    /// The CloudKit container, when sync is on. Used by `SyncMonitor` for account status.
    var cloudKitContainerIdentifier: String? {
        if case let .cloudKit(identifier) = sync { return identifier }
        return nil
    }

    /// Persistent-history author for every context this app writes with. `SyncMonitor`
    /// treats transactions by any other author (CloudKit import, another process) as remote.
    public static let transactionAuthor = "app"

    /// A background context for one repository. Each repository owns its own.
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        context.automaticallyMergesChangesFromParent = true
        context.transactionAuthor = Self.transactionAuthor
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

    /// Learner store: history tracking and remote-change notifications are always on
    /// for SQLite so sync can be enabled later without a store rebuild, and so other
    /// contexts' saves refresh the UI even without iCloud (PRD FR-S4).
    static func learnerDescription(mode: Mode, sync: SyncOption) -> NSPersistentStoreDescription {
        let description = description(for: learnerConfiguration, mode: mode)
        guard case .onDisk = mode else { return description }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        if case let .cloudKit(identifier) = sync {
            let options = NSPersistentCloudKitContainerOptions(containerIdentifier: identifier)
            options.databaseScope = .private
            description.cloudKitContainerOptions = options
        }
        return description
    }

    /// Adds every store. A failed content store is destroyed and re-added alone, so
    /// the learner store is never added twice. On any other failure every store that
    /// did load is removed again, so a fallback container starts from a clean coordinator.
    private func loadStores(rebuildContentOnFailure: Bool) throws {
        var failures: [(String, Error)] = []
        container.loadPersistentStores { description, error in
            if let error { failures.append((description.configuration ?? "?", error)) }
        }
        guard let failure = failures.first else { return }
        if rebuildContentOnFailure,
           failure.0 == Self.contentConfiguration,
           case .onDisk = mode,
           let description = container.persistentStoreDescriptions.first(where: { $0.configuration == Self.contentConfiguration }),
           let url = description.url
        {
            try container.persistentStoreCoordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
            var retryError: Error?
            container.persistentStoreCoordinator.addPersistentStore(with: description) { _, error in retryError = error }
            if let retryError {
                removeLoadedStores()
                throw Failure.storeFailed(configuration: Self.contentConfiguration, description: String(describing: retryError))
            }
            return
        }
        removeLoadedStores()
        throw Failure.storeFailed(configuration: failure.0, description: String(describing: failure.1))
    }

    private func removeLoadedStores() {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }
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
