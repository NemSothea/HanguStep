import DesignSystem
import Domain
import SwiftUI

enum LearnRoute: Hashable {
    case vocabulary(VocabularyID)
    case grammar(GrammarID)
}

enum LearnSegment: String, CaseIterable, Identifiable {
    case vocabulary, grammar, bookmarks
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .vocabulary: return "Vocabulary"
        case .grammar: return "Grammar"
        case .bookmarks: return "Bookmarks"
        }
    }
}

struct LearnView: View {
    let dependencies: AppDependencies
    @State private var segment: LearnSegment = .vocabulary
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch segment {
                case .vocabulary:
                    VocabularyListView(viewModel: VocabularyListViewModel(browse: dependencies.browseVocabulary))
                case .grammar:
                    GrammarListView(viewModel: GrammarListViewModel(browse: dependencies.browseGrammar))
                case .bookmarks:
                    BookmarksView(viewModel: BookmarksViewModel(list: dependencies.listBookmarks))
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Section", selection: $segment) {
                    ForEach(LearnSegment.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.sm)
                .background(HSColor.background)
            }
            .navigationTitle("Learn")
            .navigationDestination(for: LearnRoute.self) { route in
                switch route {
                case let .vocabulary(id):
                    VocabularyDetailView(viewModel: VocabularyDetailViewModel(id: id, dependencies: dependencies), dependencies: dependencies)
                case let .grammar(id):
                    GrammarDetailView(viewModel: GrammarDetailViewModel(id: id, dependencies: dependencies), dependencies: dependencies)
                }
            }
        }
    }
}
