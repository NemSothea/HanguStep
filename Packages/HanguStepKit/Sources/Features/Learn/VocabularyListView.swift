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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes three columns leave a few characters per line, so the
        // row stacks: word, romanization, meaning, then the level badge.
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.md))
        layout {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HangulText(item.hangul, style: .title)
                Text(item.romanization)
                    .font(Typography.caption)
                    .foregroundStyle(HSColor.textSecondary)
            }
            if !stacked { Spacer() }
            Text(item.meaning.text(in: glossLanguage))
                .font(Typography.body)
                .foregroundStyle(HSColor.textSecondary)
                .multilineTextAlignment(stacked ? .leading : .trailing)
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
            .foregroundStyle(isOn ? HSColor.onTint : tint)
            // Off state: tint text on the plain surface with a tint border. A tinted
            // fill pulled the amber and orange levels under 4.5:1 (Phase 9 audit).
            .background(isOn ? tint : HSColor.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(tint, lineWidth: isOn ? 0 : 1) }
    }
}
