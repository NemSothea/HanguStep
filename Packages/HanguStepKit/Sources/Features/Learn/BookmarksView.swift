import DesignSystem
import Domain
import SwiftUI

@MainActor
@Observable
public final class BookmarksViewModel {
    public private(set) var state: ViewState<[BookmarkEntry]> = .idle
    private let list: any ListBookmarksUseCase

    public init(list: any ListBookmarksUseCase) { self.list = list }

    public func load() async {
        state = .loading
        do {
            let entries = try await list.execute()
            state = entries.isEmpty ? .empty : .loaded(entries)
        } catch { state = .failed(message: error.localizedDescription) }
    }
}

struct BookmarksView: View {
    @State private var viewModel: BookmarksViewModel
    @Environment(LearnerPreferences.self) private var preferences

    var changes: any LearnerChangeSource = NoLearnerChanges()

    init(viewModel: BookmarksViewModel, changes: any LearnerChangeSource = NoLearnerChanges()) {
        _viewModel = State(initialValue: viewModel)
        self.changes = changes
    }

    var body: some View {
        AsyncStateView(viewModel.state, emptyTitle: "No bookmarks", emptyMessage: "Tap the bookmark icon on any word or pattern.", emptySystemImage: "bookmark", retry: { Task { await viewModel.load() } }) { entries in
            List(entries) { entry in
                NavigationLink(value: route(for: entry.bookmark.target)) {
                    ContentRow(title: entry.title, gloss: entry.gloss, level: entry.level, glossLanguage: preferences.glossLanguage)
                }
            }
            .listStyle(.plain)
        }
        .task { await viewModel.load() }
        .reloadOnLearnerChange(changes) { await viewModel.load() }
    }

    private func route(for target: LearningTarget) -> LearnRoute {
        switch target {
        case let .vocabulary(id): return .vocabulary(id)
        case let .grammar(id): return .grammar(id)
        }
    }
}

/// Shared row for bookmark and mistake lists.
struct ContentRow: View {
    let title: String
    let gloss: Gloss
    let level: TOPIKLevel
    let glossLanguage: GlossLanguage
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HangulText(title, style: .title)
                Text(gloss.text(in: glossLanguage))
                    .font(Typography.caption)
                    .foregroundStyle(HSColor.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            trailing
            LevelBadge(level: level.rawValue)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}
