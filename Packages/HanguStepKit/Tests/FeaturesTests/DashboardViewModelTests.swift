import DesignSystem
import Domain
import Features
import XCTest

@MainActor
final class DashboardViewModelTests: XCTestCase {
    private struct StubLoad: LoadDashboardSummaryUseCase {
        let result: Result<DashboardSummary, DomainError>
        func execute() async throws -> DashboardSummary { try result.get() }
    }

    private struct StubResume: ResumeQuizSessionUseCase {
        func execute() async throws -> QuizSessionSnapshot? { nil }
        func discardUnfinished() async throws {}
    }

    func testLoadTransitionsToLoaded() async {
        let summary = DashboardSummary(vocabularyCount: 3, grammarCount: 1, progress: .empty, dueCount: 2, masteredCount: 0, dailyGoal: 20)
        let viewModel = DashboardViewModel(loadSummary: StubLoad(result: .success(summary)), resume: StubResume())
        XCTAssertEqual(viewModel.state, .idle)
        await viewModel.load()
        XCTAssertEqual(viewModel.state.value?.summary, summary)
        XCTAssertNil(viewModel.state.value?.unfinished)
    }

    func testLoadFailureExposesMessage() async {
        let viewModel = DashboardViewModel(loadSummary: StubLoad(result: .failure(.storage(description: "disk"))), resume: StubResume())
        await viewModel.load()
        XCTAssertEqual(viewModel.state, .failed(message: "Storage error: disk"))
    }
}
