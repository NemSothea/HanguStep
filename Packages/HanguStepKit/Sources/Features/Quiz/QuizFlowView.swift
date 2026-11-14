import DesignSystem
import Domain
import SwiftUI

struct QuizFlowView: View {
    @State private var viewModel: QuizSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(LearnerPreferences.self) private var preferences
    @Environment(AssistantModel.self) private var assistant
    @State private var showCloseConfirmation = false
    @State private var showSecondaryGloss = false

    init(viewModel: QuizSessionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .background(HSColor.background)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
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
                .accessibilityHidden(true)   // "1 of 10" in the toolbar already says it
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    if viewModel.shortfallNoticeShown, let snapshot = viewModel.snapshot {
                        Label("Only \(snapshot.questions.count) questions matched your filters.", systemImage: "info.circle")
                            .font(Typography.caption)
                            .foregroundStyle(HSColor.textSecondary)
                    }
                    if let question = viewModel.currentQuestion {
                        if viewModel.isListening {
                            ListeningCard(script: viewModel.revealedScript) { viewModel.playListening() }
                        } else if let passage = question.passage {
                            HSCard { HangulText(passage, style: .body) }
                        }
                        HangulText(question.prompt, style: Self.promptStyle(for: question))
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

    /// Hero size only for short word prompts; sentences and reading questions
    /// use the title size so they wrap into a few readable lines.
    static func promptStyle(for question: Question) -> HangulText.Style {
        switch question.kind {
        case .vocabularyMeaning where question.prompt.count <= 24: return .display
        case .meaningToWord, .vocabularyMeaning, .grammarFillIn, .sentenceCompletion, .readingComprehension, .listening: return .title
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
                if let schedule = feedback.schedule {
                    Label("Next review \(schedule.nextReviewDate.formatted(.relative(presentation: .named)))", systemImage: "calendar")
                        .font(Typography.caption)
                        .foregroundStyle(HSColor.textSecondary)
                }
                if assistant.isEnabled {
                    assistantPanel
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var assistantPanel: some View {
        switch viewModel.assistantExplanation {
        case .idle, .empty:
            Button {
                Task { await viewModel.explainCurrentAnswer(language: preferences.glossLanguage) }
            } label: {
                Label("Explain more", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            .font(Typography.caption)
            .accessibilityIdentifier("assistant.explain")
        case .loading:
            HStack(spacing: Spacing.sm) {
                ProgressView().controlSize(.small)
                Text("Asking the assistant…").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
            }
        case let .loaded(explanation):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label(explanation.providerName, systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HSColor.accent)
                Text(explanation.text)
                    .font(Typography.body)
                    .scriptSpacing(explanation.language == .khmer ? .khmer : .latin)
                    .textSelection(.enabled)
            }
            .padding(Spacing.sm)
            .background(HSColor.background, in: RoundedRectangle(cornerRadius: Radius.md))
            .accessibilityIdentifier("assistant.explanation")
        case let .failed(message):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(message).font(Typography.caption).foregroundStyle(HSColor.danger)
                Button("Try again") { Task { await viewModel.explainCurrentAnswer(language: preferences.glossLanguage) } }
                    .font(Typography.caption)
            }
        }
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

/// Play/replay control for a listening question. The script appears after answering.
struct ListeningCard: View {
    let script: ListeningScript?
    let play: () -> Void

    var body: some View {
        HSCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "headphones").foregroundStyle(HSColor.accent).accessibilityHidden(true)
                    Text(script == nil ? "Listen, then choose the answer." : "Script")
                        .font(Typography.headline)
                }
                HSButton("Play audio", systemImage: "play.fill", variant: .secondary, action: play)
                    .accessibilityIdentifier("listening.play")
                    .accessibilityHint("Speaks the Korean audio for this question")
                if let script {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        ForEach(Array(script.lines.enumerated()), id: \.offset) { _, line in
                            HangulText(Self.label(for: line), style: .body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .accessibilityIdentifier("listening.script")
                }
            }
        }
    }

    static func label(for line: ListeningScript.Line) -> String {
        switch line.speaker {
        case .man, .woman: return "\(line.speaker.rawValue): \(line.text)"
        case .narrator: return line.text
        }
    }
}
