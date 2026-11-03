import DesignSystem
import Domain
import SwiftUI

@MainActor
@Observable
public final class ReviewQueueViewModel {
    public private(set) var state: ViewState<ReviewQueue> = .idle
    private let list: any ListReviewQueueUseCase

    public init(list: any ListReviewQueueUseCase) { self.list = list }

    public func load() async {
        if state.value == nil { state = .loading }
        do {
            let queue = try await list.execute()
            state = queue.entries.isEmpty ? .empty : .loaded(queue)
        } catch { state = .failed(message: error.localizedDescription) }
    }
}

/// S11 Review queue: what is due today and a way to start.
struct ReviewQueueView: View {
    let dependencies: AppDependencies
    @State private var viewModel: ReviewQueueViewModel
    @State private var launch: QuizLaunch?
    @Environment(LearnerPreferences.self) private var preferences

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: ReviewQueueViewModel(list: dependencies.listReviewQueue))
    }

    var body: some View {
        AsyncStateView(viewModel.state, emptyTitle: "Nothing due", emptyMessage: "Items you answer in quizzes come back here when it is time to review them.", emptySystemImage: "checkmark.circle", retry: { Task { await viewModel.load() } }) { queue in
            List {
                Section {
                    HSButton("Start review (\(queue.entries.count))", systemImage: "play.fill") {
                        launch = QuizLaunch(configuration: QuizConfiguration(pool: .review))
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    if queue.remaining > 0 {
                        Text("\(queue.remaining) more due beyond today's limit of \(queue.limit). Raise the limit in Settings or come back tomorrow.")
                            .font(Typography.caption)
                            .foregroundStyle(HSColor.textSecondary)
                            .listRowBackground(Color.clear)
                    }
                }
                Section {
                    ForEach(queue.entries) { entry in
                        NavigationLink(value: route(for: entry.schedule.target)) {
                            ContentRow(title: entry.title, gloss: entry.gloss, level: entry.level, glossLanguage: preferences.glossLanguage, trailing: AnyView(overdueBadge(entry)))
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Review queue")
        .navigationDestination(for: LearnRoute.self) { route in
            switch route {
            case let .vocabulary(id):
                VocabularyDetailView(viewModel: VocabularyDetailViewModel(id: id, dependencies: dependencies), dependencies: dependencies)
            case let .grammar(id):
                GrammarDetailView(viewModel: GrammarDetailViewModel(id: id, dependencies: dependencies), dependencies: dependencies)
            }
        }
        .quizSheet(launch: $launch, dependencies: dependencies) { Task { await viewModel.load() } }
        .task { await viewModel.load() }
    }

    private func overdueBadge(_ entry: ReviewQueueEntry) -> some View {
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            Text(entry.overdueDays == 0 ? "today" : (entry.overdueDays == 1 ? "1 day late" : "\(entry.overdueDays) days late"))
                .font(.caption.weight(.bold))
                .foregroundStyle(entry.overdueDays == 0 ? HSColor.accent : HSColor.warning)
            Text(entry.schedule.repetitions == 0 ? "new" : "seen \(entry.schedule.repetitions)×")
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
