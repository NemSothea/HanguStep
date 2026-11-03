import CloudKit
import CoreData
import Domain
import Foundation

/// Watches the container for CloudKit events and remote changes, deduplicates
/// after imports, and publishes `SyncState` plus a change stream for the UI.
/// One instance per container; the composition root starts and stops it.
public final class SyncMonitor: LearnerChangeSource, @unchecked Sendable {
    private let controller: PersistenceController
    private let deduplicator: LearnerDeduplicator
    private let lock = NSLock()
    private var state: SyncState
    private var stateContinuations: [UUID: AsyncStream<SyncState>.Continuation] = [:]
    private var changeContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var observers: [NSObjectProtocol] = []
    private var processing: Task<Void, Never>?
    private var maintenance: Task<Void, Never>?
    private var dirty = false
    private var historyCursor: Date

    /// Remote changes arrive in bursts; one reload per burst is enough.
    static let changeDebounce: Duration = .milliseconds(400)
    /// Persistent history older than this is purged on start.
    static let historyRetention: TimeInterval = 7 * 86_400

    public init(controller: PersistenceController) {
        self.controller = controller
        deduplicator = LearnerDeduplicator(controller: controller)
        state = SyncState(isEnabled: controller.isCloudKitEnabled, lastError: controller.syncFallbackError)
        historyCursor = Date()
    }

    deinit { stop() }

    // MARK: Public surface

    public var currentState: SyncState { lock.withLock { state } }

    /// Current state first, then every update.
    public func states() -> AsyncStream<SyncState> {
        AsyncStream { continuation in
            let id = UUID()
            let current = lock.withLock {
                stateContinuations[id] = continuation
                return state
            }
            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.stateContinuations.removeValue(forKey: id) }
            }
        }
    }

    /// Emits after learner data changed by someone other than this app's own
    /// contexts: a CloudKit import or another process (PRD FR-S4).
    public func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock { changeContinuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { _ = self?.changeContinuations.removeValue(forKey: id) }
            }
        }
    }

    /// Subscribes to container notifications and reads the account status. Idempotent.
    public func start() {
        let center = NotificationCenter.default
        let shouldStart = lock.withLock { observers.isEmpty }
        guard shouldStart else { return }
        let added: [NSObjectProtocol] = [
            center.addObserver(forName: .NSPersistentStoreRemoteChange, object: controller.container.persistentStoreCoordinator, queue: nil) { [weak self] _ in
                self?.scheduleChange()
            },
            center.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: controller.container, queue: nil) { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
                self?.handle(event)
            },
            center.addObserver(forName: .CKAccountChanged, object: nil, queue: nil) { [weak self] _ in
                self?.refreshAccountStatus()
            },
        ]
        lock.withLock { observers = added }
        refreshAccountStatus()
        purgeOldHistory()
    }

    /// Removes observers and cancels pending work. Safe to call twice.
    public func stop() {
        let (removed, tasks) = lock.withLock {
            defer { observers = []; processing = nil; maintenance = nil; dirty = false }
            return (observers, [processing, maintenance])
        }
        removed.forEach(NotificationCenter.default.removeObserver)
        tasks.forEach { $0?.cancel() }
    }

    /// History requests must target the Learner store only; the Content store has no history tracking.
    private var learnerStore: NSPersistentStore? {
        controller.container.persistentStoreCoordinator.persistentStores.first { $0.configurationName == PersistenceController.learnerConfiguration }
    }

    // MARK: Events

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        update { state in
            if event.endDate == nil {
                state.isSyncing = true
                return
            }
            state.isSyncing = false
            if event.succeeded {
                switch event.type {
                case .import: state.lastImportAt = event.endDate
                case .export: state.lastExportAt = event.endDate
                case .setup: break
                @unknown default: break
                }
                state.lastError = nil
            } else if let error = event.error {
                state.lastError = Self.describe(error)
            }
        }
    }

    private func refreshAccountStatus() {
        guard let identifier = controller.cloudKitContainerIdentifier else {
            update { $0.accountStatus = .couldNotDetermine }
            return
        }
        Task { [weak self] in
            let status: SyncAccountStatus
            do {
                status = Self.map(try await CKContainer(identifier: identifier).accountStatus())
            } catch {
                status = .couldNotDetermine
            }
            self?.update { $0.accountStatus = status }
        }
    }

    /// Leading-edge debounce with a trailing pass: the first event starts one
    /// processing task; events during the window set `dirty` and are folded into
    /// one more pass. Passes never overlap, so dedupe runs serially.
    private func scheduleChange() {
        lock.withLock {
            dirty = true
            guard processing == nil else { return }
            processing = Task { [weak self] in
                await self?.processChanges()
            }
        }
    }

    private func processChanges() async {
        while true {
            try? await Task.sleep(for: Self.changeDebounce)
            if Task.isCancelled { return }
            lock.withLock { dirty = false }
            if await hasForeignTransactions() {
                if controller.isCloudKitEnabled {
                    do { _ = try await deduplicator.run() } catch { update { $0.lastError = Self.describe(error) } }
                }
                if Task.isCancelled { return }
                let targets = lock.withLock { Array(changeContinuations.values) }
                targets.forEach { $0.yield(()) }
            }
            let again = lock.withLock {
                if dirty { return true }
                processing = nil
                return false
            }
            if !again { return }
        }
    }

    /// True when persistent history since the cursor contains a transaction not
    /// written by this app's contexts. Advances the cursor either way.
    private func hasForeignTransactions() async -> Bool {
        let since = lock.withLock { historyCursor }
        guard let store = learnerStore, case .onDisk = controller.mode else { return false }
        let context = controller.newBackgroundContext()
        let result: (foreign: Bool, latest: Date?) = await context.perform {
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: since)
            request.affectedStores = [store]
            guard let history = try? context.execute(request) as? NSPersistentHistoryResult,
                  let transactions = history.result as? [NSPersistentHistoryTransaction]
            else { return (false, nil) }
            let foreign = transactions.contains { $0.author != PersistenceController.transactionAuthor }
            return (foreign, transactions.map(\.timestamp).max())
        }
        if let latest = result.latest {
            lock.withLock { historyCursor = max(historyCursor, latest) }
        }
        return result.foreign
    }

    private func purgeOldHistory() {
        guard let store = learnerStore, case .onDisk = controller.mode else { return }
        let context = controller.newBackgroundContext()
        let before = Date().addingTimeInterval(-Self.historyRetention)
        let task = Task {
            // Best effort; skipped when the monitor was stopped before it ran.
            if Task.isCancelled { return }
            await context.perform {
                let request = NSPersistentHistoryChangeRequest.deleteHistory(before: before)
                request.affectedStores = [store]
                _ = try? context.execute(request)
            }
        }
        lock.withLock { maintenance = task }
    }

    private func update(_ change: (inout SyncState) -> Void) {
        let targets: [AsyncStream<SyncState>.Continuation]
        let next: SyncState
        do {
            lock.lock()
            defer { lock.unlock() }
            var candidate = state
            change(&candidate)
            guard candidate != state else { return }
            state = candidate
            next = candidate
            targets = Array(stateContinuations.values)
        }
        // Yield outside the lock: termination handlers take the same lock.
        targets.forEach { $0.yield(next) }
    }

    static func map(_ status: CKAccountStatus) -> SyncAccountStatus {
        switch status {
        case .available: return .available
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        case .temporarilyUnavailable: return .temporarilyUnavailable
        case .couldNotDetermine: return .couldNotDetermine
        @unknown default: return .couldNotDetermine
        }
    }

    static func describe(_ error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated: return "Not signed in to iCloud."
            case .quotaExceeded: return "iCloud storage is full."
            case .networkUnavailable, .networkFailure: return "No network. Changes will sync later."
            case .partialFailure: return "Some records failed to sync. They will be retried."
            default: return ckError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
