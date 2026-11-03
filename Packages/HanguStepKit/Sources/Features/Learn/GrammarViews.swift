import DesignSystem
import Domain
import SwiftUI

@MainActor
@Observable
public final class GrammarListViewModel {
    public private(set) var state: ViewState<[GrammarPattern]> = .idle
    private let browse: any BrowseGrammarUseCase

    public init(browse: any BrowseGrammarUseCase) {
        self.browse = browse
    }

    public var byLevel: [(TOPIKLevel, [GrammarPattern])] {
        let grouped = Dictionary(grouping: state.value ?? [], by: \.level)
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    public func load() async {
        state = .loading
        do {
            let patterns = try await browse.execute(level: nil)
            state = patterns.isEmpty ? .empty : .loaded(patterns)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }
}

struct GrammarListView: View {
    @State private var viewModel: GrammarListViewModel
    @Environment(LearnerPreferences.self) private var preferences

    init(viewModel: GrammarListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        AsyncStateView(viewModel.state, emptyTitle: "No grammar yet", emptySystemImage: "text.book.closed", retry: { Task { await viewModel.load() } }) { _ in
            List {
                ForEach(viewModel.byLevel, id: \.0) { level, patterns in
                    Section {
                        ForEach(patterns) { pattern in
                            NavigationLink(value: LearnRoute.grammar(pattern.id)) {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    HangulText(pattern.pattern, style: .title)
                                    Text(pattern.explanation.text(in: preferences.glossLanguage))
                                        .font(Typography.caption)
                                        .foregroundStyle(HSColor.textSecondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, Spacing.xs)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    } header: {
                        HStack { LevelBadge(level: level.rawValue); Text(level.exam == .topikI ? "TOPIK I" : "TOPIK II") }
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
        }
        .task { await viewModel.load() }
    }
}

@MainActor
@Observable
public final class GrammarDetailViewModel {
    public private(set) var state: ViewState<GrammarDetail> = .idle
    public var noteDraft = ""

    private let id: GrammarID
    private let getDetail: any GetGrammarDetailUseCase
    private let toggleBookmark: any ToggleBookmarkUseCase
    private let saveNote: any SaveNoteUseCase

    public init(id: GrammarID, dependencies: AppDependencies) {
        self.id = id
        getDetail = dependencies.getGrammarDetail
        toggleBookmark = dependencies.toggleBookmark
        saveNote = dependencies.saveNote
    }

    public func load() async {
        state = .loading
        do {
            let detail = try await getDetail.execute(id: id)
            noteDraft = detail.note?.text ?? ""
            state = .loaded(detail)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func toggleBookmarkTapped() async {
        guard var detail = state.value else { return }
        do {
            detail.isBookmarked = try await toggleBookmark.execute(target: .grammar(id))
            state = .loaded(detail)
        } catch { state = .failed(message: error.localizedDescription) }
    }

    public func commitNote() async {
        guard var detail = state.value else { return }
        do {
            detail.note = try await saveNote.execute(target: .grammar(id), text: noteDraft)
            noteDraft = detail.note?.text ?? ""
            state = .loaded(detail)
        } catch { state = .failed(message: error.localizedDescription) }
    }
}

struct GrammarDetailView: View {
    @State private var viewModel: GrammarDetailViewModel
    let dependencies: AppDependencies
    @State private var practice: QuizLaunch?

    init(viewModel: GrammarDetailViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        AsyncStateView(viewModel.state, retry: { Task { await viewModel.load() } }) { detail in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(spacing: Spacing.sm) {
                        HangulText(detail.pattern.pattern, style: .display)
                        HStack { LevelBadge(level: detail.pattern.level.rawValue); Text(detail.pattern.category).font(Typography.caption).foregroundStyle(HSColor.textSecondary) }
                    }
                    .frame(maxWidth: .infinity)

                    HSCard {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Meaning").font(Typography.headline)
                            PreferredGlossText(gloss: detail.pattern.explanation)
                        }
                    }
                    if let formation = detail.pattern.formation {
                        HSCard {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("How to form it").font(Typography.headline)
                                PreferredGlossText(gloss: formation)
                            }
                        }
                    }
                    if !detail.pattern.examples.isEmpty { ExamplesCard(examples: detail.pattern.examples) }
                    if !detail.related.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Related").font(Typography.headline)
                            ForEach(detail.related) { related in
                                NavigationLink(value: LearnRoute.grammar(related.id)) {
                                    HStack { HangulText(related.pattern, style: .body); Spacer(); Image(systemName: "chevron.right").foregroundStyle(HSColor.textSecondary) }
                                        .padding(Spacing.md)
                                        .background(HSColor.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    NoteCard(draft: Binding(get: { viewModel.noteDraft }, set: { viewModel.noteDraft = $0 }), isSaving: false) {
                        Task { await viewModel.commitNote() }
                    }
                    if !detail.practiceQuestions.isEmpty {
                        HSButton("Practice (\(detail.practiceQuestions.count))", systemImage: "play.fill") {
                            practice = QuizLaunch(configuration: QuizConfiguration(pool: .questions(detail.practiceQuestions.map(\.id)), count: detail.practiceQuestions.count))
                        }
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: Layout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { Task { await viewModel.toggleBookmarkTapped() } } label: {
                        Label(detail.isBookmarked ? "Remove bookmark" : "Bookmark", systemImage: detail.isBookmarked ? "bookmark.fill" : "bookmark")
                    }
                }
            }
        }
        .background(HSColor.background)
        .navigationTitle(viewModel.state.value?.pattern.pattern ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .quizSheet(launch: $practice, dependencies: dependencies)
        .task { await viewModel.load() }
    }
}
