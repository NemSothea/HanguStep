import DesignSystem
import Domain
import SwiftUI

@MainActor
@Observable
public final class MistakesViewModel {
    public private(set) var state: ViewState<[MistakeEntry]> = .idle
    public var sort: MistakeSort = .recent { didSet { Task { await load() } } }
    private let list: any ListMistakesUseCase

    public init(list: any ListMistakesUseCase) { self.list = list }

    public func load() async {
        if state.value == nil { state = .loading }
        do {
            let entries = try await list.execute(sort: sort)
            state = entries.isEmpty ? .empty : .loaded(entries)
        } catch { state = .failed(message: error.localizedDescription) }
    }
}

struct MistakesView: View {
    let dependencies: AppDependencies
    @State private var viewModel: MistakesViewModel
    @State private var launch: QuizLaunch?
    @Environment(LearnerPreferences.self) private var preferences

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: MistakesViewModel(list: dependencies.listMistakes))
    }

    var body: some View {
        NavigationStack {
            AsyncStateView(viewModel.state, emptyTitle: "No mistakes yet", emptyMessage: "Wrong answers collect here until you get them right twice in a row.", emptySystemImage: "checkmark.seal", retry: { Task { await viewModel.load() } }) { entries in
                List {
                    Section {
                        HSButton("Practice mistakes (\(entries.count))", systemImage: "arrow.counterclockwise") {
                            launch = QuizLaunch(configuration: QuizConfiguration(pool: .mistakes, count: 40))
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    Section {
                        ForEach(entries) { entry in
                            NavigationLink(value: route(for: entry.mistake.target)) {
                                ContentRow(title: entry.title, gloss: entry.gloss, level: entry.level, glossLanguage: preferences.glossLanguage, trailing: AnyView(missBadge(entry.mistake)))
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Review")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Picker("Sort", selection: Binding(get: { viewModel.sort }, set: { viewModel.sort = $0 })) {
                        Text("Recent").tag(MistakeSort.recent)
                        Text("Frequent").tag(MistakeSort.frequent)
                    }
                    .pickerStyle(.menu)
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
            .quizSheet(launch: $launch, dependencies: dependencies) { Task { await viewModel.load() } }
            .task { await viewModel.load() }
            .reloadOnLearnerChange(dependencies.learnerChanges) { await viewModel.load() }
        }
    }

    private func missBadge(_ mistake: MistakeItem) -> some View {
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            Text("×\(mistake.timesMissed)")
                .font(.caption.weight(.bold))
                .foregroundStyle(HSColor.danger)
            Text(mistake.lastMissedAt.formatted(.relative(presentation: .named)))
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
