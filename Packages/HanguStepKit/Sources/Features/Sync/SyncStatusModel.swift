import DesignSystem
import Domain
import Foundation
import Observation

/// Main-actor mirror of the persistence layer's `SyncState` for SwiftUI, plus the
/// learner's device-local choice to sync at all. Fed by the composition root.
@MainActor
@Observable
public final class SyncStatusModel {
    public private(set) var state: SyncState
    /// The learner's preference. The container is rebuilt when it changes.
    public private(set) var isSyncPreferred: Bool
    public private(set) var isApplyingPreference = false
    private let applyPreference: @MainActor (Bool) async -> Void

    public init(state: SyncState, isSyncPreferred: Bool, applyPreference: @escaping @MainActor (Bool) async -> Void) {
        self.state = state
        self.isSyncPreferred = isSyncPreferred
        self.applyPreference = applyPreference
    }

    /// Consumes state updates until the stream ends or the task is cancelled.
    public func observe(_ states: AsyncStream<SyncState>) async {
        for await next in states { state = next }
    }

    public func setSyncPreferred(_ enabled: Bool) async {
        guard enabled != isSyncPreferred, !isApplyingPreference else { return }
        isApplyingPreference = true
        isSyncPreferred = enabled
        await applyPreference(enabled)
        isApplyingPreference = false
    }

    /// What the badge shows (PRD FR-S5).
    public var badgeStatus: SyncStatus {
        guard isSyncPreferred, state.isEnabled else {
            if isSyncPreferred, let error = state.lastError { return .error(error) }
            return .disabled
        }
        switch state.accountStatus {
        case .noAccount: return .signedOut
        case .restricted: return .error("iCloud is restricted on this device.")
        case .temporarilyUnavailable: return .offline
        case .available, .couldNotDetermine: break
        }
        if state.isSyncing { return .syncing }
        if let error = state.lastError { return .error(error) }
        if let date = state.lastSuccessAt { return .synced(date) }
        return state.accountStatus == .available ? .syncing : .offline
    }
}

extension View {
    /// Reloads when learner data changes outside this screen: a CloudKit import or a
    /// save from another context (PRD FR-S4).
    func reloadOnLearnerChange(_ source: any LearnerChangeSource, perform: @escaping @MainActor () async -> Void) -> some View {
        task {
            for await _ in source.changes() {
                guard !Task.isCancelled else { return }
                await perform()
            }
        }
    }
}

import SwiftUI
