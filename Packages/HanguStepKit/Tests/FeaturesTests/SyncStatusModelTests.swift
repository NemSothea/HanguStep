import DesignSystem
import Domain
@testable import Features
import XCTest

@MainActor
final class SyncStatusModelTests: XCTestCase {
    private func model(_ state: SyncState, preferred: Bool = true) -> SyncStatusModel {
        SyncStatusModel(state: state, isSyncPreferred: preferred) { _ in }
    }

    func testBadgeFollowsPreferenceAccountAndEvents() {
        XCTAssertEqual(model(.disabled, preferred: false).badgeStatus, .disabled)
        XCTAssertEqual(model(SyncState(isEnabled: false, lastError: "boom")).badgeStatus, .error("boom"))
        XCTAssertEqual(model(SyncState(isEnabled: true, accountStatus: .noAccount)).badgeStatus, .signedOut)
        XCTAssertEqual(model(SyncState(isEnabled: true, accountStatus: .temporarilyUnavailable)).badgeStatus, .offline)
        XCTAssertEqual(model(SyncState(isEnabled: true, accountStatus: .available, isSyncing: true)).badgeStatus, .syncing)
        let date = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(model(SyncState(isEnabled: true, accountStatus: .available, lastImportAt: date)).badgeStatus, .synced(date))
        XCTAssertEqual(model(SyncState(isEnabled: true, accountStatus: .available, lastExportAt: date, lastError: "quota")).badgeStatus, .error("quota"))
        XCTAssertEqual(model(SyncState(isEnabled: true, accountStatus: .available)).badgeStatus, .syncing, "enabled but nothing happened yet")
    }

    func testObserveAppliesStreamedStates() async {
        let model = model(.disabled)
        let (stream, continuation) = AsyncStream<SyncState>.makeStream()
        let task = Task { await model.observe(stream) }
        continuation.yield(SyncState(isEnabled: true, accountStatus: .available))
        continuation.finish()
        await task.value
        XCTAssertTrue(model.state.isEnabled)
        XCTAssertEqual(model.state.accountStatus, .available)
    }

    func testSetPreferenceCallsBackOnceAndIgnoresNoOps() async {
        let calls = Calls()
        let model = SyncStatusModel(state: .disabled, isSyncPreferred: true) { enabled in calls.record(enabled) }
        await model.setSyncPreferred(true)
        await model.setSyncPreferred(false)
        XCTAssertEqual(calls.values, [false])
        XCTAssertFalse(model.isSyncPreferred)
        XCTAssertFalse(model.isApplyingPreference)
    }

    private final class Calls: @unchecked Sendable {
        private(set) var values: [Bool] = []
        func record(_ value: Bool) { values.append(value) }
    }
}
