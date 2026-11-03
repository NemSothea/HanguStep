import Foundation

/// iCloud account state as the app understands it. Mirrors `CKAccountStatus`
/// without importing CloudKit into the domain.
public enum SyncAccountStatus: String, Sendable, Codable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine
}

/// What the Settings screen shows (PRD FR-S5). A value, published by the
/// persistence layer, never assumed to be up to date on another device.
public struct SyncState: Hashable, Sendable {
    /// Learner wants sync and the store opened in CloudKit mode.
    public var isEnabled: Bool
    public var accountStatus: SyncAccountStatus
    public var isSyncing: Bool
    public var lastImportAt: Date?
    public var lastExportAt: Date?
    public var lastError: String?

    public init(
        isEnabled: Bool = false,
        accountStatus: SyncAccountStatus = .couldNotDetermine,
        isSyncing: Bool = false,
        lastImportAt: Date? = nil,
        lastExportAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.accountStatus = accountStatus
        self.isSyncing = isSyncing
        self.lastImportAt = lastImportAt
        self.lastExportAt = lastExportAt
        self.lastError = lastError
    }

    public static let disabled = SyncState()

    /// Most recent successful import or export.
    public var lastSuccessAt: Date? {
        switch (lastImportAt, lastExportAt) {
        case let (i?, e?): return max(i, e)
        case let (i?, nil): return i
        case let (nil, e?): return e
        case (nil, nil): return nil
        }
    }
}

/// Emits once whenever learner data changed outside the caller's own writes:
/// a CloudKit import or a save from another context (PRD FR-S4).
public protocol LearnerChangeSource: Sendable {
    func changes() -> AsyncStream<Void>
}

/// Source that never emits. Tests, previews and the in-memory configuration.
public struct NoLearnerChanges: LearnerChangeSource {
    public init() {}
    public func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}
