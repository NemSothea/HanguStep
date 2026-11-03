import DesignSystem
import Domain
import SwiftUI

struct VocabularyListView: View {
    @State private var viewModel: VocabularyListViewModel
    @Environment(LearnerPreferences.self) private var preferences

    init(viewModel: VocabularyListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        AsyncStateView(
            viewModel.state,
            emptyTitle: "No words match",
            emptyMessage: "Try another search or clear the filters.",
            emptySystemImage: "magnifyingglass",
            retry: { Task { await viewModel.load() } }
        ) { items in
            List(items) { item in
                NavigationLink(value: LearnRoute.vocabulary(item.id)) {
                    VocabularyRow(item: item, glossLanguage: preferences.glossLanguage)
                }
            }
            .listStyle(.plain)
        }
        .searchable(text: $viewModel.query, prompt: "Hangul, English or Khmer")
        .safeAreaInset(edge: .top, spacing: 0) { filterBar }
        .task { await viewModel.load() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(TOPIKLevel.allCases, id: \.self) { level in
                    FilterChip(title: "L\(level.rawValue)", isOn: viewModel.levels.contains(level), tint: HSColor.level(level.rawValue)) {
                        viewModel.toggle(level: level)
                    }
                }
                Menu {
                    Button("Any part of speech") { viewModel.partOfSpeech = nil }
                    ForEach(PartOfSpeech.allCases, id: \.self) { pos in
                        Button(pos.rawValue.capitalized) { viewModel.partOfSpeech = pos }
                    }
                } label: {
                    FilterChipLabel(title: viewModel.partOfSpeech.map { LocalizedStringKey($0.rawValue.capitalized) } ?? "Part of speech", isOn: viewModel.partOfSpeech != nil, tint: HSColor.accent)
                }
                if viewModel.hasActiveFilters {
                    Button("Clear") { viewModel.clearFilters() }
                        .font(Typography.caption)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .background(HSColor.background)
    }
}

struct VocabularyRow: View {
    let item: VocabularyItem
    let glossLanguage: GlossLanguage

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HangulText(item.hangul, style: .title)
                Text(item.romanization)
                    .font(Typography.caption)
                    .foregroundStyle(HSColor.textSecondary)
            }
            Spacer()
            Text(item.meaning.text(in: glossLanguage))
                .font(Typography.body)
                .foregroundStyle(HSColor.textSecondary)
                .multilineTextAlignment(.trailing)
                .scriptSpacing(glossLanguage == .khmer ? .khmer : .latin)
            LevelBadge(level: item.level.rawValue)
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

struct FilterChip: View {
    let title: LocalizedStringKey
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FilterChipLabel(title: title, isOn: isOn, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct FilterChipLabel: View {
    let title: LocalizedStringKey
    let isOn: Bool
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, Spacing.sm + Spacing.xs)
            .padding(.vertical, Spacing.xs + Spacing.xxs)
            .foregroundStyle(isOn ? Color.white : tint)
            .background(isOn ? tint : tint.opacity(0.12), in: Capsule())
    }
}
