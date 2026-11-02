import DesignSystem
import Domain
import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    init(viewModel: DashboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        AsyncStateView(viewModel.state, retry: { Task { await viewModel.load() } }) { summary in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    statGrid(summary)
                    actions
                }
                .padding(Spacing.md)
                .frame(maxWidth: Layout.readableWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .background(HSColor.background)
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack {
            Text("Today")
                .font(Typography.title)
            Spacer()
            StreakBadge(days: 0)
        }
    }

    private func statGrid(_ summary: DashboardSummary) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)], spacing: Spacing.md) {
            StatTile(title: "Vocabulary", value: summary.vocabularyCount.formatted(), caption: "words", systemImage: "character.book.closed")
            StatTile(title: "Grammar", value: summary.grammarCount.formatted(), caption: "patterns", systemImage: "text.book.closed")
            StatTile(title: "Answered", value: summary.attempts.total.formatted(), caption: "all time", systemImage: "checkmark.circle")
            StatTile(
                title: "Accuracy",
                value: summary.attempts.accuracy.formatted(.percent.precision(.fractionLength(0))),
                caption: "all time",
                systemImage: "target",
                tint: HSColor.success
            )
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            HSButton("Start review", systemImage: "play.fill") {}
                .disabled(true)
            HSButton("Quick quiz", systemImage: "bolt.fill", variant: .secondary) {}
                .disabled(true)
            Text("Review and quizzes arrive in Phase 4.")
                .font(Typography.caption)
                .foregroundStyle(HSColor.textSecondary)
        }
    }
}
