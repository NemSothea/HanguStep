import DesignSystem
import Domain
import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    let dependencies: AppDependencies
    @State private var launch: QuizLaunch?

    init(viewModel: DashboardViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        AsyncStateView(viewModel.state, retry: { Task { await viewModel.load() } }) { content in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    if let unfinished = content.unfinished {
                        ContinueSessionCard(snapshot: unfinished) {
                            launch = QuizLaunch(resume: unfinished)
                        } discard: {
                            Task { await viewModel.discardUnfinished() }
                        }
                    }
                    statGrid(content.summary)
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
                NavigationLink { SettingsView(dependencies: dependencies) } label: { Label("Settings", systemImage: "gearshape") }
            }
        }
        .quizSheet(launch: $launch, dependencies: dependencies) { Task { await viewModel.load() } }
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack {
            Text("Today").font(Typography.title)
            Spacer()
            StreakBadge(days: 0)
        }
    }

    private func statGrid(_ summary: DashboardSummary) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)], spacing: Spacing.md) {
            StatTile(title: "Vocabulary", value: summary.vocabularyCount.formatted(), caption: "words", systemImage: "character.book.closed")
            StatTile(title: "Grammar", value: summary.grammarCount.formatted(), caption: "patterns", systemImage: "text.book.closed")
            StatTile(title: "Answered", value: summary.attempts.total.formatted(), caption: "all time", systemImage: "checkmark.circle")
            StatTile(title: "Accuracy", value: summary.attempts.accuracy.formatted(.percent.precision(.fractionLength(0))), caption: "all time", systemImage: "target", tint: HSColor.success)
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.sm) {
            HSButton("Start review", systemImage: "play.fill") {}
                .disabled(true)
            HSButton("Quick quiz", systemImage: "bolt.fill", variant: .secondary) {
                launch = QuizLaunch(configuration: QuizConfiguration(pool: .mixed, count: 10))
            }
            Text("Spaced review arrives in Phase 5.").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
        }
    }
}
