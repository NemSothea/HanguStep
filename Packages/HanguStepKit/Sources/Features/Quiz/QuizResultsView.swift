import DesignSystem
import Domain
import SwiftUI

struct QuizResultsView: View {
    let result: QuizResult
    let done: () -> Void
    @Environment(LearnerPreferences.self) private var preferences

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                ProgressRing(progress: result.accuracy, lineWidth: 14, tint: result.isPerfect ? HSColor.success : HSColor.accent) {
                    VStack {
                        Text(result.accuracy.formatted(.percent.precision(.fractionLength(0)))).font(Typography.statValue)
                        Text("\(result.correct) of \(result.answered)").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
                    }
                }
                .frame(width: 160, height: 160)
                .padding(.top, Spacing.lg)

                if result.isPerfect {
                    Label("Perfect round", systemImage: "star.fill").foregroundStyle(HSColor.success).font(Typography.headline)
                }
                if result.answered < result.total {
                    Text("\(result.total - result.answered) questions skipped").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Spacing.md)], spacing: Spacing.md) {
                    StatTile(title: "Correct", value: result.correct.formatted(), systemImage: "checkmark.circle", tint: HSColor.success)
                    StatTile(title: "Incorrect", value: (result.answered - result.correct).formatted(), systemImage: "xmark.circle", tint: HSColor.danger)
                    StatTile(title: "Avg. time", value: result.averageResponseTime.formatted(.number.precision(.fractionLength(1))) + "s", systemImage: "timer")
                }

                if !result.incorrect.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader("Review these")
                        ForEach(result.incorrect) { answer in
                            IncorrectAnswerRow(answer: answer, glossLanguage: preferences.glossLanguage)
                        }
                    }
                }

                HSButton("Done", systemImage: "checkmark", action: done)
            }
            .padding(Spacing.md)
            .frame(maxWidth: Layout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Results")
    }
}

struct IncorrectAnswerRow: View {
    let answer: IncorrectAnswer
    let glossLanguage: GlossLanguage

    private var selectedText: String { answer.question.options.first { $0.id == answer.selectedOptionID }?.text ?? "" }
    private var correctText: String { answer.question.options.first { $0.id == answer.question.correctOptionID }?.text ?? "" }

    var body: some View {
        HSCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HangulText(answer.question.prompt, style: .body)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(HSColor.danger)
                    Text(selectedText).strikethrough().foregroundStyle(HSColor.textSecondary)
                }
                .font(Typography.caption)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(HSColor.success)
                    Text(correctText)
                }
                .font(Typography.caption)
                Text(answer.question.explanation.text(in: glossLanguage))
                    .font(Typography.caption)
                    .foregroundStyle(HSColor.textSecondary)
                    .scriptSpacing(glossLanguage == .khmer ? .khmer : .latin)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
