import DesignSystem
import Domain
import SwiftUI

struct QuizFlowView: View {
    @State private var viewModel: QuizSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(LearnerPreferences.self) private var preferences
    @State private var showCloseConfirmation = false
    @State private var showSecondaryGloss = false

    init(viewModel: QuizSessionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .background(HSColor.background)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            if viewModel.hasUnansweredQuestions { showCloseConfirmation = true } else { dismiss() }
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text(viewModel.progressText).font(Typography.caption).monospacedDigit()
                    }
                }
                .confirmationDialog("End this quiz?", isPresented: $showCloseConfirmation, titleVisibility: .visible) {
                    Button("End quiz", role: .destructive) { Task { await viewModel.close() } }
                    Button("Keep going", role: .cancel) {}
                } message: {
                    Text("Answered questions are saved. Unanswered ones are skipped.")
                }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .answering, .feedback:
            questionScreen
        case let .finished(result):
            QuizResultsView(result: result) { dismiss() }
        case let .failed(message):
            ErrorStateView(message: message, retry: { Task { await viewModel.load() } })
        }
    }

    private var questionScreen: some View {
        VStack(spacing: 0) {
            ProgressView(value: viewModel.progress)
                .tint(HSColor.accent)
                .padding(.horizontal, Spacing.md)
                .accessibilityLabel("Quiz progress")
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if viewModel.shortfallNoticeShown, let snapshot = viewModel.snapshot {
                        Label("Only \(snapshot.questions.count) questions matched your filters.", systemImage: "info.circle")
                            .font(Typography.caption)
                            .foregroundStyle(HSColor.textSecondary)
                    }
                    if let question = viewModel.currentQuestion {
                        if let passage = question.passage {
                            HSCard { HangulText(passage, style: .body) }
                        }
                        HangulText(question.prompt, style: question.kind == .readingComprehension ? .title : .display)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(spacing: Spacing.sm) {
                            ForEach(Array(question.options.enumerated()), id: \.element.id) { index, option in
                                OptionRow(index: index, text: option.text, state: viewModel.optionState(for: option)) {
                                    viewModel.select(option.id)
                                }
                                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
                            }
                        }
                        if case let .feedback(_, feedback) = viewModel.phase {
                            feedbackPanel(feedback)
                        }
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: Layout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            bottomBar
        }
    }

    private func feedbackPanel(_ feedback: AnswerFeedback) -> some View {
        let lines = preferences.lines(for: feedback.explanation)
        return HSCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(feedback.isCorrect ? "Correct" : "Incorrect", systemImage: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(Typography.headline)
                    .foregroundStyle(feedback.isCorrect ? HSColor.success : HSColor.danger)
                Text(showSecondaryGloss ? lines.secondary.text : lines.primary.text)
                    .font(Typography.body)
                    .scriptSpacing(showSecondaryGloss ? lines.secondary.script : lines.primary.script)
                Button(showSecondaryGloss ? "Show \(lines.primary.languageCode == "en" ? "English" : "Khmer")" : "Show \(lines.secondary.languageCode == "en" ? "English" : "Khmer")") {
                    showSecondaryGloss.toggle()
                }
                .font(Typography.caption)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }

    private var bottomBar: some View {
        VStack {
            switch viewModel.phase {
            case .answering:
                HSButton("Check", systemImage: "checkmark", isLoading: viewModel.isSubmitting) { Task { await viewModel.check() } }
                    .disabled(viewModel.selectedOptionID == nil)
                    .keyboardShortcut(.return, modifiers: [])
            case let .feedback(_, feedback):
                HSButton(feedback.isLastQuestion ? "See results" : "Next", systemImage: "arrow.right") { Task { await viewModel.next() } }
                    .keyboardShortcut(.return, modifiers: [])
            default:
                EmptyView()
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: Layout.readableWidth)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
