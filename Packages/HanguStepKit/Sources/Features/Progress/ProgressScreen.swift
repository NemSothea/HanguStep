import Charts
import DesignSystem
import Domain
import SwiftUI

@MainActor
@Observable
public final class ProgressViewModel {
    public private(set) var state: ViewState<ProgressReport> = .idle
    private let load: any LoadProgressReportUseCase

    public init(load: any LoadProgressReportUseCase) { self.load = load }

    public func refresh() async {
        if state.value == nil { state = .loading }
        do {
            let report = try await load.execute()
            state = report.summary.hasActivity ? .loaded(report) : .empty
        } catch { state = .failed(message: error.localizedDescription) }
    }
}

/// S8 Learning progress: evidence the routine works.
struct ProgressScreen: View {
    let dependencies: AppDependencies
    @State private var viewModel: ProgressViewModel
    @Environment(LearnerPreferences.self) private var preferences

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: ProgressViewModel(load: dependencies.loadProgressReport))
    }

    var body: some View {
        NavigationStack {
            AsyncStateView(viewModel.state, emptyTitle: "No progress yet", emptyMessage: "Finish one quiz and your statistics appear here.", emptySystemImage: "chart.bar", retry: { Task { await viewModel.refresh() } }) { report in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        statGrid(report)
                        ActivityChartCard(days: report.summary.last30Days)
                        GoalCard(report: report)
                        weakSection("Weak words", entries: report.weakWords, empty: "No weak words. Keep it up.")
                        weakSection("Weak grammar", entries: report.weakGrammar, empty: "No weak grammar patterns.")
                        NavigationLink(value: ProgressRoute.history) {
                            HSCard {
                                HStack {
                                    Label("Session history", systemImage: "list.bullet.rectangle")
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(HSColor.textSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(Spacing.md)
                    .frame(maxWidth: Layout.readableWidth)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(HSColor.background)
            .navigationTitle("Progress")
            .navigationDestination(for: ProgressRoute.self) { route in
                switch route {
                case .history: HistoryView(viewModel: HistoryViewModel(list: dependencies.listHistory))
                }
            }
            .navigationDestination(for: LearnRoute.self) { route in
                switch route {
                case let .vocabulary(id):
                    VocabularyDetailView(viewModel: VocabularyDetailViewModel(id: id, dependencies: dependencies), dependencies: dependencies)
                case let .grammar(id):
                    GrammarDetailView(viewModel: GrammarDetailViewModel(id: id, dependencies: dependencies), dependencies: dependencies)
                }
            }
            .task { await viewModel.refresh() }
            .refreshable { await viewModel.refresh() }
        }
    }

    private func statGrid(_ report: ProgressReport) -> some View {
        let summary = report.summary
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.md)], spacing: Spacing.md) {
            StatTile(title: "Answered", value: summary.totals.total.formatted(), caption: "\(summary.totals.correct) correct", systemImage: "checkmark.circle")
            StatTile(title: "Accuracy", value: summary.totals.accuracy.formatted(.percent.precision(.fractionLength(0))), caption: "all time", systemImage: "target", tint: HSColor.success)
            StatTile(title: "Streak", value: summary.currentStreak.formatted(), caption: "best \(summary.longestStreak)", systemImage: "flame", tint: HSColor.danger)
            StatTile(title: "Mastered", value: report.masteredCount.formatted(), caption: "of \(report.scheduledCount) scheduled", systemImage: "star.circle", tint: HSColor.success)
        }
    }

    private func weakSection(_ title: LocalizedStringKey, entries: [WeakEntry], empty: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(title)
            if entries.isEmpty {
                Text(empty).font(Typography.caption).foregroundStyle(HSColor.textSecondary)
            } else {
                HSCard {
                    VStack(spacing: 0) {
                        ForEach(entries) { entry in
                            NavigationLink(value: route(for: entry.item.target)) {
                                ContentRow(title: entry.title, gloss: entry.gloss, level: entry.level, glossLanguage: preferences.glossLanguage, trailing: AnyView(accuracyBadge(entry.item)))
                            }
                            .buttonStyle(.plain)
                            if entry.id != entries.last?.id { Divider() }
                        }
                    }
                }
            }
        }
    }

    private func accuracyBadge(_ item: WeakItem) -> some View {
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            Text(item.accuracy.formatted(.percent.precision(.fractionLength(0))))
                .font(.caption.weight(.bold))
                .foregroundStyle(HSColor.danger)
            Text("\(item.correct) of \(item.answered)")
                .font(.caption2)
                .foregroundStyle(HSColor.textSecondary)
        }
    }

    private func route(for target: LearningTarget) -> LearnRoute {
        switch target {
        case let .vocabulary(id): return .vocabulary(id)
        case let .grammar(id): return .grammar(id)
        }
    }
}

enum ProgressRoute: Hashable {
    case history
}

/// 30-day answered bars with an accuracy line on days that had answers.
struct ActivityChartCard: View {
    let days: [DailyActivity]

    var body: some View {
        HSCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("Last 30 days")
                Text("Answered").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
                Chart(days) { day in
                    BarMark(x: .value("Day", day.day, unit: .day), y: .value("Answered", day.answered))
                        .foregroundStyle(HSColor.accent.opacity(0.75))
                }
                .chartXAxis { dayAxis }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 140)
                .accessibilityLabel("Questions answered per day, last 30 days")
                .accessibilityValue(summaryText)

                Text("Accuracy").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
                Chart(days.filter { $0.accuracy != nil }) { day in
                    LineMark(x: .value("Day", day.day, unit: .day), y: .value("Accuracy", day.accuracy ?? 0))
                        .foregroundStyle(HSColor.success)
                        .interpolationMethod(.monotone)
                        .symbol(.circle)
                        .symbolSize(20)
                }
                .chartXScale(domain: xDomain)
                .chartYScale(domain: 0...1)
                .chartXAxis { dayAxis }
                .chartYAxis { AxisMarks(position: .leading, values: [0, 0.5, 1]) { value in
                    AxisGridLine()
                    AxisValueLabel { if let v = value.as(Double.self) { Text(v.formatted(.percent.precision(.fractionLength(0)))) } }
                } }
                .frame(height: 110)
                .accessibilityLabel("Accuracy per day, last 30 days")
                .accessibilityValue(summaryText)

                Text(summaryText).font(Typography.caption).foregroundStyle(HSColor.textSecondary)
            }
        }
    }

    private var dayAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
            AxisGridLine()
            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
        }
    }

    private var xDomain: ClosedRange<Date> {
        let first = days.first?.day ?? .now
        let last = days.last?.day ?? .now
        return first...last.addingTimeInterval(86_400)
    }

    private var summaryText: String {
        let answered = days.reduce(0) { $0 + $1.answered }
        let correct = days.reduce(0) { $0 + $1.correct }
        let active = days.filter { $0.answered > 0 }.count
        let accuracy = answered == 0 ? 0 : Double(correct) / Double(answered)
        return "\(answered) questions on \(active) days, \(accuracy.formatted(.percent.precision(.fractionLength(0)))) correct"
    }

}

/// Daily goal with inline editing. The stepper edits a local draft immediately
/// and persists through `LearnerPreferences`, so rapid taps are not lost while
/// a save is in flight. Preferences are the single source for the goal value.
struct GoalCard: View {
    let report: ProgressReport
    @Environment(LearnerPreferences.self) private var preferences
    @State private var draft: Int?
    @State private var errorMessage: String?

    var body: some View {
        HSCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("Daily goal")
                HStack(spacing: Spacing.md) {
                    ProgressRing(progress: progress, lineWidth: 8, tint: reached ? HSColor.success : HSColor.accent) {
                        Text("\(report.summary.answeredToday)")
                            .font(Typography.statValue)
                            .monospacedDigit()
                    }
                    .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(reached ? "Goal reached today" : "\(max(0, goal - report.summary.answeredToday)) more to go")
                            .font(Typography.headline)
                        Text("\(report.summary.minutesToday) minutes today").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                Stepper("Target: \(goal) questions", value: goalBinding, in: 5...200, step: 5)
                    .font(Typography.body)
                if let errorMessage {
                    Text(errorMessage).font(Typography.caption).foregroundStyle(HSColor.danger)
                }
            }
        }
    }

    private var goal: Int { draft ?? preferences.settings.dailyGoal }
    private var reached: Bool { report.summary.answeredToday >= goal }
    private var progress: Double { goal == 0 ? 0 : Double(report.summary.answeredToday) / Double(goal) }

    private var goalBinding: Binding<Int> {
        Binding(
            get: { goal },
            set: { newValue in
                draft = newValue
                Task {
                    do {
                        try await preferences.update { $0.dailyGoal = newValue }
                        if draft == newValue { draft = nil }
                    } catch { errorMessage = error.localizedDescription }
                }
            }
        )
    }
}
