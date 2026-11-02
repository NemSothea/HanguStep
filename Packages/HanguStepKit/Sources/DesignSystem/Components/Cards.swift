import SwiftUI

public struct HSCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(HSColor.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

public struct SectionHeader<Trailing: View>: View {
    private let title: LocalizedStringKey
    private let trailing: Trailing

    public init(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.title)
                .foregroundStyle(HSColor.textPrimary)
            Spacer()
            trailing
        }
        .accessibilityAddTraits(.isHeader)
    }
}

public struct StatTile: View {
    private let title: LocalizedStringKey
    private let value: String
    private let caption: LocalizedStringKey?
    private let systemImage: String
    private let tint: Color

    public init(
        title: LocalizedStringKey,
        value: String,
        caption: LocalizedStringKey? = nil,
        systemImage: String,
        tint: Color = HSColor.accent
    ) {
        self.title = title
        self.value = value
        self.caption = caption
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HSCard {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label {
                    Text(title)
                        .foregroundStyle(HSColor.textSecondary)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                        .symbolRenderingMode(.hierarchical)
                }
                .font(Typography.caption)
                Text(value)
                    .font(Typography.statValue)
                    .foregroundStyle(HSColor.textPrimary)
                    .contentTransition(.numericText())
                if let caption {
                    Text(caption)
                        .font(Typography.caption)
                        .foregroundStyle(HSColor.textSecondary)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Cards") {
    ScrollView {
        VStack(spacing: Spacing.md) {
            SectionHeader("Today") { Text("Mon").font(Typography.caption) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: Spacing.md) {
                StatTile(title: "Due today", value: "14", systemImage: "clock", tint: HSColor.warning)
                StatTile(title: "Accuracy", value: "82%", caption: "last 7 days", systemImage: "target")
                StatTile(title: "Streak", value: "12", caption: "days", systemImage: "flame.fill", tint: HSColor.danger)
            }
            HSCard {
                Text("Continue session").font(Typography.headline)
                Text("Question 7 of 20").font(Typography.caption).foregroundStyle(HSColor.textSecondary)
            }
        }
        .padding()
    }
    .background(HSColor.background)
}
