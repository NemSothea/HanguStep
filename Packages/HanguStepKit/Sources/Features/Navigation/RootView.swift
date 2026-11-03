import DesignSystem
import Domain
import SwiftUI

/// Adaptive navigation shell. One `NavigationStack` per section so each tab
/// keeps its own back stack; sidebar on regular widths.
public struct RootView: View {
    private let dependencies: AppDependencies
    private let preferences: LearnerPreferences
    private let syncStatus: SyncStatusModel
    @State private var selection: AppSection? = .home

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    public init(dependencies: AppDependencies, preferences: LearnerPreferences, syncStatus: SyncStatusModel? = nil) {
        self.dependencies = dependencies
        self.preferences = preferences
        self.syncStatus = syncStatus ?? SyncStatusModel(state: .disabled, isSyncPreferred: false) { _ in }
    }

    public var body: some View {
        shell
            .tint(HSColor.accent)
            .environment(preferences)
            .environment(syncStatus)
    }

    @ViewBuilder
    private var shell: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            tabLayout
        } else {
            splitLayout
        }
        #else
        splitLayout
        #endif
    }

    private var tabLayout: some View {
        TabView(selection: Binding(get: { selection ?? .home }, set: { selection = $0 })) {
            ForEach(AppSection.allCases) { section in
                destination(for: section)
                    .tabItem { Label(section.title, systemImage: section.systemImage) }
                    .tag(section)
            }
        }
    }

    private var splitLayout: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage).tag(section)
            }
            .navigationTitle("HanguStep")
        } detail: {
            destination(for: selection ?? .home)
        }
    }

    @ViewBuilder
    private func destination(for section: AppSection) -> some View {
        switch section {
        case .home:
            NavigationStack {
                DashboardView(viewModel: DashboardViewModel(loadSummary: dependencies.loadDashboardSummary, resume: dependencies.resumeQuiz), dependencies: dependencies)
            }
        case .learn:
            LearnView(dependencies: dependencies)
        case .quiz:
            QuizSetupView(dependencies: dependencies)
        case .review:
            MistakesView(dependencies: dependencies)
        case .progress:
            ProgressScreen(dependencies: dependencies)
        }
    }
}
