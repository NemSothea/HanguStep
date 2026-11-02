import Domain
import Features
import XCTest

@MainActor
final class DashboardViewModelTests: XCTestCase {
    private struct StubLoad: LoadDashboardSummaryUseCase {
        let result: Result<DashboardSummary, DomainError>
        func execute() async throws -> DashboardSummary { try result.get() }
    }

    func testLoadTransitionsToLoaded() async {
        let summary = DashboardSummary(vocabularyCount: 3, grammarCount: 1, attempts: AttemptSummary(total: 0, correct: 0))
        let viewModel = DashboardViewModel(loadSummary: StubLoad(result: .success(summary)))
        XCTAssertEqual(viewModel.state, .idle)
        await viewModel.load()
        XCTAssertEqual(viewModel.state, .loaded(summary))
    }

    func testLoadFailureExposesMessage() async {
        let viewModel = DashboardViewModel(loadSummary: StubLoad(result: .failure(.storage(description: "disk"))))
        await viewModel.load()
        XCTAssertEqual(viewModel.state, .failed(message: "Storage error: disk"))
    }
}
