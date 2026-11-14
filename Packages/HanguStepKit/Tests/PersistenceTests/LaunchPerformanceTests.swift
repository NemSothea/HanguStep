import Domain
@testable import Persistence
import XCTest

/// Phase 10, AC-13 proxy on the Mac test host: the work `AppContainer.bootstrap()`
/// does before the first screen. Device numbers come from Instruments (signposts
/// in the `Launch` category); these tests guard against regressions in CI.
final class LaunchPerformanceTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("launch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }

    /// Opens the on-disk stores and brings the bundled library up to date, the
    /// way the app does at launch. Returns elapsed seconds.
    private func bootstrapOnce() async throws -> Double {
        let start = ContinuousClock.now
        let controller = try PersistenceController(mode: .onDisk(directory: directory))
        _ = try await BundledContentInstaller.installIfNeeded(controller: controller)
        return Self.seconds(ContinuousClock.now - start)
    }

    func testFirstLaunchImportStaysUnderBudget() async throws {
        let first = try await bootstrapOnce()
        print("PERF first launch (open stores + import bundle): \(Int(first * 1000)) ms")
        XCTAssertLessThan(first, 1.5, "first launch import")
    }

    func testWarmLaunchStaysUnderBudget() async throws {
        _ = try await bootstrapOnce()
        var worst = 0.0
        for _ in 0..<3 { worst = max(worst, try await bootstrapOnce()) }
        print("PERF warm launch (open stores, content current): \(Int(worst * 1000)) ms")
        XCTAssertLessThan(worst, 0.25, "AC-13 budget share for store work on a warm launch")
    }
}
