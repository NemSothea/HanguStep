import DesignSystem
import Domain
import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    init(viewModel: DashboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Loading")
            case let .loaded(summary):
                summaryList(summary)
            case let .failed(message):
                ContentUnavailableView("Could not load", systemImage: "exclamationmark.triangle", description: Text(message))
            }
        }
        .navigationTitle("Home")
        .task { await viewModel.load() }
    }

    private func summaryList(_ summary: DashboardSummary) -> some View {
        List {
            Section("Library") {
                LabeledContent("Vocabulary", value: summary.vocabularyCount.formatted())
                LabeledContent("Grammar patterns", value: summary.grammarCount.formatted())
            }
            Section("Practice") {
                LabeledContent("Questions answered", value: summary.attempts.total.formatted())
                LabeledContent("Accuracy", value: summary.attempts.accuracy.formatted(.percent.precision(.fractionLength(0))))
            }
        }
    }
}
