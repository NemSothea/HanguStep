import DesignSystem
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class DashboardViewModel {
    public private(set) var state: ViewState<DashboardSummary> = .idle

    private let loadSummary: any LoadDashboardSummaryUseCase

    public init(loadSummary: any LoadDashboardSummaryUseCase) {
        self.loadSummary = loadSummary
    }

    public func load() async {
        state = .loading
        do {
            state = .loaded(try await loadSummary.execute())
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }
}
