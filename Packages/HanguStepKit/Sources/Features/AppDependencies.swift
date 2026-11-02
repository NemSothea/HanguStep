import Domain

/// Use cases the feature layer needs. Built once by the app's composition root
/// and passed down. Features never construct repositories themselves.
public struct AppDependencies: Sendable {
    public let loadDashboardSummary: any LoadDashboardSummaryUseCase

    public init(loadDashboardSummary: any LoadDashboardSummaryUseCase) {
        self.loadDashboardSummary = loadDashboardSummary
    }
}
