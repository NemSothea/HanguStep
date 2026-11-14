import DesignSystem
import Domain
import Foundation
import Observation

public struct DashboardContent: Equatable, Sendable {
    public let summary: DashboardSummary
    public let unfinished: QuizSessionSnapshot?
}

@MainActor
@Observable
public final class DashboardViewModel {
    public private(set) var state: ViewState<DashboardContent> = .idle

    private let loadSummary: any LoadDashboardSummaryUseCase
    private let resume: any ResumeQuizSessionUseCase

    public init(loadSummary: any LoadDashboardSummaryUseCase, resume: any ResumeQuizSessionUseCase) {
        self.loadSummary = loadSummary
        self.resume = resume
    }

    public func load() async {
        if state.value == nil { state = .loading }
        do {
            async let summary = loadSummary.execute()
            async let unfinished = resume.execute()
            state = .loaded(DashboardContent(summary: try await summary, unfinished: try await unfinished))
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func discardUnfinished() async {
        do { try await resume.discardUnfinished(); await load() } catch { state = .failed(message: error.localizedDescription) }
    }
}
