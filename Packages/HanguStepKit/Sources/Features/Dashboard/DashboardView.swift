import Charts
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
                    header(content.summary)
                    if let unfinished = content.unfinished {
                        ContinueSessionCard(snapshot: unfinished) {
                            launch = QuizLaunch(resume: unfinished)
                        } discard: {
                            Task { await viewModel.discardUnfinished() }
                        }
                    }
                    todayTiles(content.summary)
                    actions(content.summary)
                    WeeklyActivityCard(days: content.summary.progress.last7Days)
                    libraryTiles(content.summary)
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
        .navigationDestination(for: DashboardRoute.self) { route in
            switch route {
            case .reviewQueue: ReviewQueueView(dependencies: dependencies)
            }
        }
        .quizSheet(launch: $launch, dependencies: dependencies) { Task { await viewModel.load() } }
        .task { await viewModel.load() }
    }

    private func header(_ summary: DashboardSummary) -> some View {
        HStack {
            Text("Today").font(Typography.title)
            Spacer()
            StreakBadge(days: summary.progress.currentStreak)
        }
    }

    private func todayTiles(_ summary: DashboardSummary) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)], spacing: Spacing.md) {
            NavigationLink(value: DashboardRoute.reviewQueue) {
                StatTile(title: "Due today", value: summary.dueCount.formatted(), caption: summary.dueCount == 1 ? "item to review" : "items to review", systemImage: "clock.arrow.circlepath", tint: summary.dueCount > 0 ? HSColor.warning : HSColor.accent)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the review queue")
            GoalTile(answered: summary.progress.answeredToday, goal: summary.dailyGoal, reached: summary.isGoalReached)
            StatTile(title: "Accuracy", value: summary.progress.accuracyLast7Days.formatted(.percent.precision(.fractionLength(0))), caption: "last 7 days", systemImage: "target", tint: HSColor.success)
        }
    }

    private func actions(_ summary: DashboardSummary) -> some View {
        VStack(spacing: Spacing.sm) {
            HSButton("Start review", systemImage: "play.fill") {
                launch = QuizLaunch(configuration: QuizConfiguration(pool: .review))
            }
            .disabled(summary.dueCount == 0)
            HSButton("Quick quiz", systemImage: "bolt.fill", variant: .secondary) {
                launch = QuizLaunch(configuration: QuizConfiguration(pool: .mixed, count: 10))
            }
            if summary.dueCount == 0 {
                Text(summary.progress.hasActivity ? "Nothing due right now. A quick quiz adds new words to your review schedule." : "Take a quick quiz to start your review schedule.")
                    .font(Typography.caption)
                    .foregroundStyle(HSColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func libraryTiles(_ summary: DashboardSummary) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)], spacing: Spacing.md) {
            StatTile(title: "Vocabulary", value: summary.vocabularyCount.formatted(), caption: "words", systemImage: "character.book.closed")
            StatTile(title: "Grammar", value: summary.grammarCount.formatted(), caption: "patterns", systemImage: "text.book.closed")
            StatTile(title: "Answered", value: summary.attempts.total.formatted(), caption: "all time", systemImage: "checkmark.circle")
            StatTile(title: "Mastered", value: summary.masteredCount.formatted(), caption: "items", systemImage: "star.circle", tint: HSColor.success)
        }
    }
}

enum DashboardRoute: Hashable {
    case reviewQueue
}

/// Progress toward today's question goal (PRD FR-P5).
struct GoalTile: View {
    let answered: Int
    let goal: Int
    let reached: Bool

    var body: some View {
        HSCard {
            HStack(spacing: Spacing.md) {
                ProgressRing(progress: goal == 0 ? 0 : Double(answered) / Double(goal), lineWidth: 6, tint: reached ? HSColor.success : HSColor.accent) {
                    Image(systemName: reached ? "checkmark" : "flag")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(reached ? HSColor.success : HSColor.accent)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Goal").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
                    Text("\(answered)/\(goal)").font(Typography.statValue).foregroundStyle(HSColor.textPrimary).monospacedDigit()
                    Text(reached ? "reached" : "questions today").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reached ? "Daily goal reached, \(answered) of \(goal) questions" : "Daily goal, \(answered) of \(goal) questions")
    }
}

/// Seven bars, one per day, ending today (S1 "This week").
struct WeeklyActivityCard: View {
    let days: [DailyActivity]

    var body: some View {
        HSCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("This week")
                Chart(days) { day in
                    BarMark(x: .value("Day", day.day, unit: .day), y: .value("Answered", day.answered))
                        .foregroundStyle(day.answered > 0 ? HSColor.accent : HSColor.accent.opacity(0.2))
                        .cornerRadius(Radius.sm)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 96)
                .accessibilityLabel("Questions answered per day this week")
                .accessibilityValue(summaryText)
            }
        }
    }

    private var summaryText: String {
        let total = days.reduce(0) { $0 + $1.answered }
        let active = days.filter { $0.answered > 0 }.count
        return "\(total) questions on \(active) of 7 days"
    }
}
