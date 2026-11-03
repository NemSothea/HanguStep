import DesignSystem
import Domain
import SwiftUI

@MainActor
@Observable
public final class HistoryViewModel {
    public private(set) var state: ViewState<[SessionSummary]> = .idle
    private let list: any ListQuizHistoryUseCase

    public init(list: any ListQuizHistoryUseCase) { self.list = list }

    public func load() async {
        if state.value == nil { state = .loading }
        do {
            let sessions = try await list.execute(limit: 50)
            state = sessions.isEmpty ? .empty : .loaded(sessions)
        } catch { state = .failed(message: error.localizedDescription) }
    }
}

/// Phase 4 shows quiz history only. Statistics and charts arrive in Phase 5.
struct HistoryView: View {
    @State private var viewModel: HistoryViewModel

    init(viewModel: HistoryViewModel) { _viewModel = State(initialValue: viewModel) }

    var body: some View {
        NavigationStack {
            AsyncStateView(viewModel.state, emptyTitle: "No sessions yet", emptyMessage: "Finish a quiz and it will show up here.", emptySystemImage: "chart.bar", retry: { Task { await viewModel.load() } }) { sessions in
                List(sessions) { summary in
                    HStack(spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(summary.session.mode == .mistakes ? "Mistake practice" : "Quiz")
                                .font(Typography.headline)
                            Text(summary.session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(Typography.caption)
                                .foregroundStyle(HSColor.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: Spacing.xxs) {
                            Text(summary.accuracy.formatted(.percent.precision(.fractionLength(0))))
                                .font(Typography.statValue)
                                .foregroundStyle(summary.accuracy >= 0.8 ? HSColor.success : HSColor.textPrimary)
                            Text("\(summary.correct) of \(summary.answered)")
                                .font(Typography.caption)
                                .foregroundStyle(HSColor.textSecondary)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                    .accessibilityElement(children: .combine)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Progress")
            .task { await viewModel.load() }
        }
    }
}
