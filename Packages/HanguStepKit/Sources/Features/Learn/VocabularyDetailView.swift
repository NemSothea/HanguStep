import DesignSystem
import Domain
import SwiftUI

struct VocabularyDetailView: View {
    @State private var viewModel: VocabularyDetailViewModel
    let dependencies: AppDependencies
    @Environment(LearnerPreferences.self) private var preferences

    init(viewModel: VocabularyDetailViewModel, dependencies: AppDependencies) {
        _viewModel = State(initialValue: viewModel)
        self.dependencies = dependencies
    }

    var body: some View {
        AsyncStateView(viewModel.state, retry: { Task { await viewModel.load() } }) { detail in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    hero(detail.item)
                    HSCard { PreferredGlossText(gloss: detail.item.meaning) }
                    if !detail.item.examples.isEmpty {
                        ExamplesCard(examples: detail.item.examples)
                    }
                    NoteCard(draft: Binding(get: { viewModel.noteDraft }, set: { viewModel.noteDraft = $0 }), isSaving: viewModel.isSavingNote) {
                        Task { await viewModel.commitNote() }
                    }
                }
                .padding(Spacing.md)
                .frame(maxWidth: Layout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.toggleBookmarkTapped() }
                    } label: {
                        Label(detail.isBookmarked ? "Remove bookmark" : "Bookmark", systemImage: detail.isBookmarked ? "bookmark.fill" : "bookmark")
                    }
                }
            }
        }
        .background(HSColor.background)
        .navigationTitle(viewModel.state.value?.item.hangul ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await viewModel.load() }
    }

    private func hero(_ item: VocabularyItem) -> some View {
        VStack(spacing: Spacing.sm) {
            HangulText(item.hangul, style: .display)
            HStack(spacing: Spacing.sm) {
                Text(item.romanization).font(Typography.body).foregroundStyle(HSColor.textSecondary)
                if let hanja = item.hanja {
                    Text(hanja).font(Typography.caption).foregroundStyle(HSColor.textSecondary)
                }
            }
            HStack(spacing: Spacing.sm) {
                LevelBadge(level: item.level.rawValue)
                Text(item.partOfSpeech.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(HSColor.surface, in: Capsule())
                Button {
                    viewModel.pronounce()
                } label: {
                    Label("Pronounce", systemImage: "speaker.wave.2.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .disabled(!preferences.settings.pronunciationEnabled)
                .accessibilityLabel("Pronounce \(item.hangul)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.md)
    }
}

struct ExamplesCard: View {
    let examples: [ExampleSentence]

    var body: some View {
        HSCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Examples").font(Typography.headline)
                ForEach(Array(examples.enumerated()), id: \.offset) { _, example in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HangulText(example.korean, style: .body)
                        PreferredGlossText(gloss: example.translation)
                    }
                }
            }
        }
    }
}

struct NoteCard: View {
    @Binding var draft: String
    let isSaving: Bool
    let commit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        HSCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("My note").font(Typography.headline)
                    Spacer()
                    if isSaving { ProgressView().controlSize(.small) }
                }
                TextField("Mnemonic, usage, anything", text: $draft, axis: .vertical)
                    .lineLimit(2...6)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit(commit)
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused { commit() }
                    }
            }
        }
    }
}
