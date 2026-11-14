import DesignSystem
import Domain
import SwiftUI

/// TOPIK II 쓰기 practice (ADR-012): task list grouped by exam question.
struct WritingListView: View {
    let dependencies: AppDependencies
    @State private var viewModel: WritingListViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: WritingListViewModel(list: dependencies.listWritingTasks))
    }

    var body: some View {
        AsyncStateView(viewModel.state, emptyTitle: "No writing tasks", emptySystemImage: "pencil.and.list.clipboard", retry: { Task { await viewModel.load() } }) { _ in
            List {
                ForEach(WritingTaskType.allCases, id: \.self) { type in
                    Section(type.title) {
                        ForEach(viewModel.tasks(of: type)) { summary in
                            NavigationLink {
                                WritingTaskView(task: summary.task, dependencies: dependencies)
                            } label: {
                                WritingTaskRow(summary: summary)
                            }
                        }
                    }
                }
            }
        }
        .background(HSColor.background)
        .navigationTitle("Writing")
        .task { await viewModel.load() }
    }
}

struct WritingTaskRow: View {
    let summary: WritingTaskSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HangulText(summary.task.shortTitle, style: .body)
                .lineLimit(2)
            HStack(spacing: Spacing.sm) {
                LevelBadge(level: summary.task.level.rawValue)
                if let range = summary.task.lengthRange {
                    Text("\(range.lowerBound)-\(range.upperBound) characters")
                }
                if summary.attemptCount > 0 {
                    Label("\(summary.attemptCount)", systemImage: "checkmark.circle")
                        .accessibilityLabel("\(summary.attemptCount) attempts")
                }
                if let best = summary.bestScore {
                    Text("Best \(best)/\(summary.task.type.maxScore)")
                }
            }
            .font(Typography.caption)
            .foregroundStyle(HSColor.textSecondary)
        }
        .padding(.vertical, Spacing.xs)
    }
}

extension WritingTask {
    /// Topic for 53 (the quoted subject of the prompt), otherwise the material's first line.
    var shortTitle: String {
        if type == .describeData, let start = prompt.firstIndex(of: "'"), let end = prompt[prompt.index(after: start)...].firstIndex(of: "'") {
            return String(prompt[prompt.index(after: start)..<end])
        }
        let first = material.split(whereSeparator: \.isNewline).first.map(String.init) ?? prompt
        return first.count > 60 ? String(first.prefix(60)) + "…" : first
    }
}

struct WritingTaskView: View {
    @State private var viewModel: WritingTaskViewModel
    @Environment(LearnerPreferences.self) private var preferences
    @Environment(AssistantModel.self) private var assistant
    @State private var showModelAnswer = false
    @FocusState private var editorFocused: Bool

    init(task: WritingTask, dependencies: AppDependencies) {
        _viewModel = State(initialValue: WritingTaskViewModel(task: task, dependencies: dependencies))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HangulText(viewModel.task.prompt, style: .body)
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HSCard {
                    HangulText(viewModel.task.material, style: .body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                DisclosureGroup("Tips") {
                    PreferredGlossText(gloss: viewModel.task.tips)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                editor
                if let message = viewModel.errorMessage {
                    Text(message).font(Typography.caption).foregroundStyle(HSColor.danger)
                }
                HSButton("Save answer", systemImage: "square.and.arrow.down", isLoading: viewModel.isSaving) {
                    editorFocused = false
                    Task { await viewModel.submit() }
                }
                .disabled(!viewModel.canSave)
                .accessibilityIdentifier("writing.save")

                if let attempt = viewModel.current {
                    attemptPanel(attempt)
                }
                DisclosureGroup("Model answer", isExpanded: $showModelAnswer) {
                    HangulText(viewModel.task.modelAnswer, style: .body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("writing.modelAnswer")
                }
                if !viewModel.attempts.isEmpty {
                    history
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: Layout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(HSColor.background)
        .navigationTitle(viewModel.task.type.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if editorFocused { Button("Done") { editorFocused = false } }
            }
        }
        .task { await viewModel.load() }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextEditor(text: $viewModel.text)
                .accessibilityLabel("Your answer")
                .accessibilityIdentifier("writing.editor")
                .focused($editorFocused)
                .font(Typography.hangulBody)
                .frame(minHeight: viewModel.task.type == .essay ? 320 : 180)
                .padding(Spacing.xs)
                .scrollContentBackground(.hidden)
                .background(HSColor.surface, in: RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(HSColor.separator))
            Text(counterText)
                .font(Typography.caption.monospacedDigit())
                .foregroundStyle(counterColor)
                .accessibilityIdentifier("writing.counter")
        }
    }

    private var counterText: String {
        let count = viewModel.characterCount
        guard let range = viewModel.task.lengthRange else {
            return viewModel.task.type == .shortAnswer ? "\(count) characters · write ㉠ and ㉡ on separate lines" : "\(count) characters"
        }
        switch viewModel.lengthStatus {
        case .short: return "\(count) characters · \(range.lowerBound - count) more needed (\(range.lowerBound)-\(range.upperBound))"
        case .long: return "\(count) characters · \(count - range.upperBound) over the limit (\(range.lowerBound)-\(range.upperBound))"
        case .ok, .none: return "\(count) characters · within \(range.lowerBound)-\(range.upperBound)"
        }
    }

    private var counterColor: Color {
        switch viewModel.lengthStatus {
        case .ok: return HSColor.success
        case .long: return HSColor.danger
        case .short, .none: return HSColor.textSecondary
        }
    }

    private func attemptPanel(_ attempt: WritingAttempt) -> some View {
        HSCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Saved \(attempt.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(attempt.characterCount) characters", systemImage: "checkmark.circle.fill")
                    .font(Typography.caption)
                    .foregroundStyle(HSColor.textSecondary)
                HangulText(attempt.text, style: .body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                feedbackSection
                Button("Revise this answer") { viewModel.revise(attempt) }
                    .font(Typography.caption)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("writing.attempt")
    }

    @ViewBuilder
    private var feedbackSection: some View {
        switch viewModel.review {
        case .idle, .empty:
            if assistant.isEnabled {
                Button {
                    Task { await viewModel.requestFeedback(language: preferences.glossLanguage) }
                } label: {
                    Label("Get feedback", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("writing.feedback")
            } else {
                Text("Turn on the assistant in Settings for feedback. Compare with the model answer below.")
                    .font(Typography.caption)
                    .foregroundStyle(HSColor.textSecondary)
            }
        case .loading:
            HStack(spacing: Spacing.sm) {
                ProgressView().controlSize(.small)
                Text("Grading your answer…").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
            }
        case let .loaded(feedback):
            WritingFeedbackView(feedback: feedback)
        case let .failed(message):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(message).font(Typography.caption).foregroundStyle(HSColor.danger)
                Button("Try again") { Task { await viewModel.requestFeedback(language: preferences.glossLanguage) } }
                    .font(Typography.caption)
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Your answers")
            ForEach(viewModel.attempts) { attempt in
                Button {
                    viewModel.show(attempt)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attempt.createdAt.formatted(date: .abbreviated, time: .shortened))
                            Text("\(attempt.characterCount) characters").foregroundStyle(HSColor.textSecondary)
                        }
                        Spacer()
                        if let score = attempt.feedback?.estimatedScore {
                            Text("\(score)/\(attempt.feedback?.maxScore ?? viewModel.task.type.maxScore)").monospacedDigit()
                        }
                    }
                    .font(Typography.caption)
                    .padding(.vertical, Spacing.xs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct WritingFeedbackView: View {
    let feedback: WritingFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(feedback.providerName, systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HSColor.accent)
            if let score = feedback.estimatedScore {
                Text("Estimated \(score) / \(feedback.maxScore)")
                    .font(Typography.headline)
                    .accessibilityIdentifier("writing.score")
            }
            ForEach(Array(feedback.criteria.enumerated()), id: \.offset) { _, criterion in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(criterion.name).font(.caption.weight(.semibold))
                        Spacer()
                        if criterion.maxScore == 1 {
                            Image(systemName: criterion.score == 1 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(criterion.score == 1 ? HSColor.success : HSColor.warning)
                                .accessibilityLabel(criterion.score == 1 ? "Passed" : "Needs work")
                        } else {
                            Text("\(criterion.score)/\(criterion.maxScore)").font(Typography.caption.monospacedDigit())
                        }
                    }
                    Text(criterion.comment).font(Typography.caption).scriptSpacing(feedback.language == .khmer ? .khmer : .latin)
                }
            }
            if !feedback.corrections.isEmpty {
                Text("Corrections").font(.caption.weight(.semibold)).padding(.top, Spacing.xs)
                ForEach(Array(feedback.corrections.enumerated()), id: \.offset) { _, correction in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(correction.original).strikethrough().foregroundStyle(HSColor.danger)
                        Text(correction.suggestion).foregroundStyle(HSColor.success)
                        Text(correction.reason).font(Typography.caption).foregroundStyle(HSColor.textSecondary)
                    }
                    .font(Typography.hangulBody)
                    .accessibilityElement(children: .combine)
                }
            }
            Text(feedback.summary)
                .font(Typography.body)
                .scriptSpacing(feedback.language == .khmer ? .khmer : .latin)
                .textSelection(.enabled)
        }
        .padding(Spacing.sm)
        .background(HSColor.background, in: RoundedRectangle(cornerRadius: Radius.md))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("writing.feedbackPanel")
    }
}
