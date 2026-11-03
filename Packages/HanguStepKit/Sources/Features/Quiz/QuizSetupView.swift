import DesignSystem
import Domain
import SwiftUI

@MainActor
@Observable
public final class QuizSetupViewModel {
    public var pool: QuizPool = .mixed
    public var levels: Set<TOPIKLevel> = []
    public var count = 10
    public private(set) var unfinished: QuizSessionSnapshot?
    public private(set) var errorMessage: String?

    private let resume: any ResumeQuizSessionUseCase

    public init(resume: any ResumeQuizSessionUseCase) { self.resume = resume }

    public var configuration: QuizConfiguration { QuizConfiguration(pool: pool, levels: levels, count: count) }

    public func refresh() async {
        do { unfinished = try await resume.execute() } catch { errorMessage = error.localizedDescription }
    }

    public func discardUnfinished() async {
        do { try await resume.discardUnfinished(); unfinished = nil } catch { errorMessage = error.localizedDescription }
    }
}

struct QuizSetupView: View {
    let dependencies: AppDependencies
    @State private var viewModel: QuizSetupViewModel
    @State private var launch: QuizLaunch?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: QuizSetupViewModel(resume: dependencies.resumeQuiz))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if let unfinished = viewModel.unfinished {
                        ContinueSessionCard(snapshot: unfinished) {
                            launch = QuizLaunch(resume: unfinished)
                        } discard: {
                            Task { await viewModel.discardUnfinished() }
                        }
                    }
                    SectionHeader("Pool")
                    Picker("Pool", selection: Binding(get: { viewModel.pool }, set: { viewModel.pool = $0 })) {
                        Text("Mixed").tag(QuizPool.mixed)
                        Text("Vocabulary").tag(QuizPool.vocabulary)
                        Text("Grammar").tag(QuizPool.grammar)
                        Text("Mistakes").tag(QuizPool.mistakes)
                    }
                    .pickerStyle(.segmented)

                    SectionHeader("Levels")
                    HStack(spacing: Spacing.sm) {
                        ForEach(TOPIKLevel.allCases, id: \.self) { level in
                            FilterChip(title: "L\(level.rawValue)", isOn: viewModel.levels.contains(level), tint: HSColor.level(level.rawValue)) {
                                if viewModel.levels.contains(level) { viewModel.levels.remove(level) } else { viewModel.levels.insert(level) }
                            }
                        }
                    }
                    Text(viewModel.levels.isEmpty ? "All levels" : "Selected levels only").font(Typography.caption).foregroundStyle(HSColor.textSecondary)

                    SectionHeader("Questions")
                    Picker("Count", selection: Binding(get: { viewModel.count }, set: { viewModel.count = $0 })) {
                        ForEach(QuizConfiguration.allowedCounts, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)

                    HSButton("Start quiz", systemImage: "play.fill") {
                        launch = QuizLaunch(configuration: viewModel.configuration)
                    }
                    .padding(.top, Spacing.md)
                }
                .padding(Spacing.md)
                .frame(maxWidth: Layout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .background(HSColor.background)
            .navigationTitle("Quiz")
            .quizSheet(launch: $launch, dependencies: dependencies) { Task { await viewModel.refresh() } }
            .task { await viewModel.refresh() }
        }
    }
}

struct ContinueSessionCard: View {
    let snapshot: QuizSessionSnapshot
    let resume: () -> Void
    let discard: () -> Void

    var body: some View {
        HSCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Unfinished session", systemImage: "clock.arrow.circlepath").font(Typography.headline)
                Text("Question \(min(snapshot.session.currentIndex + 1, snapshot.questions.count)) of \(snapshot.questions.count), started \(snapshot.session.startedAt.formatted(.relative(presentation: .named)))")
                    .font(Typography.caption)
                    .foregroundStyle(HSColor.textSecondary)
                HStack(spacing: Spacing.sm) {
                    HSButton("Continue", systemImage: "play.fill", action: resume)
                    HSButton("Discard", variant: .secondary, action: discard)
                }
            }
        }
    }
}
