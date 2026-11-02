#if DEBUG
import SwiftUI

/// Debug-only catalogue of every component for visual verification on all platforms.
public struct ComponentGalleryView: View {
    @State private var selected = 1

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionHeader("Text")
                HangulText("학교", style: .display)
                GlossText(primary: .khmer("សាលារៀន"), secondary: .english("school"))

                SectionHeader("Badges")
                HStack { ForEach(1...6, id: \.self) { LevelBadge(level: $0) } }
                HStack { StreakBadge(days: 0); StreakBadge(days: 12) }

                SectionHeader("Stats")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: Spacing.md) {
                    StatTile(title: "Due today", value: "14", systemImage: "clock", tint: HSColor.warning)
                    StatTile(title: "Accuracy", value: "82%", caption: "last 7 days", systemImage: "target")
                    StatTile(title: "Streak", value: "12", caption: "days", systemImage: "flame.fill", tint: HSColor.danger)
                }
                ProgressRing(progress: 0.72) { Text("72%").font(Typography.statValue) }
                    .frame(width: 120, height: 120)

                SectionHeader("Options")
                ForEach(0..<4, id: \.self) { index in
                    OptionRow(index: index, text: ["school", "friend", "water", "book"][index], state: optionState(index)) {
                        selected = index
                    }
                }

                SectionHeader("Buttons")
                HSButton("Primary", systemImage: "play.fill") {}
                HSButton("Secondary", variant: .secondary) {}
                HSButton("Destructive", variant: .destructive) {}
                HSButton("Loading", isLoading: true) {}

                SectionHeader("Sync")
                SyncStatusBadge(status: .synced(.now))
                SyncStatusBadge(status: .offline)
                SyncStatusBadge(status: .error("Quota exceeded"))

                SectionHeader("States")
                EmptyStateView(title: "No mistakes yet", systemImage: "checkmark.seal", message: "Keep going.")
                ErrorStateView(message: "Storage error: disk", retry: {})
            }
            .padding(Spacing.md)
            .frame(maxWidth: Layout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(HSColor.background)
        .navigationTitle("Components")
    }

    private func optionState(_ index: Int) -> OptionState {
        index == selected ? .selected : .idle
    }
}

#Preview("Gallery") {
    NavigationStack { ComponentGalleryView() }
}
#endif
