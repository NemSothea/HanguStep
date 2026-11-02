import SwiftUI

public struct LevelBadge: View {
    private let level: Int

    public init(level: Int) {
        self.level = min(max(level, 1), 6)
    }

    public var body: some View {
        Text("L\(level)")
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .foregroundStyle(.white)
            .background(HSColor.level(level), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .accessibilityLabel("TOPIK level \(level)")
    }
}

public struct StreakBadge: View {
    private let days: Int

    public init(days: Int) {
        self.days = max(days, 0)
    }

    public var body: some View {
        Label {
            Text("\(days)")
                .font(.headline.weight(.bold))
                .monospacedDigit()
        } icon: {
            Image(systemName: days > 0 ? "flame.fill" : "flame")
        }
        .foregroundStyle(days > 0 ? HSColor.danger : HSColor.textSecondary)
        .padding(.horizontal, Spacing.sm + Spacing.xs)
        .padding(.vertical, Spacing.xs)
        .background(HSColor.surface, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days == 1 ? "1 day streak" : "\(days) day streak")
    }
}

public enum SyncStatus: Equatable, Sendable {
    case synced(Date)
    case syncing
    case offline
    case disabled
    case signedOut
    case error(String)
}

public struct SyncStatusBadge: View {
    private let status: SyncStatus

    public init(status: SyncStatus) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            if case .syncing = status {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(Typography.headline)
                if let detail {
                    Text(detail).font(Typography.caption).foregroundStyle(HSColor.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch status {
        case .synced: return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .offline: return "icloud.slash"
        case .disabled: return "icloud"
        case .signedOut: return "person.crop.circle.badge.exclamationmark"
        case .error: return "exclamationmark.icloud"
        }
    }

    private var tint: Color {
        switch status {
        case .synced: return HSColor.success
        case .syncing, .disabled: return HSColor.textSecondary
        case .offline, .signedOut: return HSColor.warning
        case .error: return HSColor.danger
        }
    }

    private var title: LocalizedStringKey {
        switch status {
        case .synced: return "iCloud up to date"
        case .syncing: return "Syncing"
        case .offline: return "Offline"
        case .disabled: return "iCloud sync off"
        case .signedOut: return "Not signed in to iCloud"
        case .error: return "Sync problem"
        }
    }

    private var detail: String? {
        switch status {
        case let .synced(date):
            return "Last sync \(date.formatted(.relative(presentation: .named)))"
        case .offline:
            return "Changes are saved on this device and will sync later."
        case .disabled:
            return "Your progress stays on this device."
        case .signedOut:
            return "Sign in to iCloud in Settings to sync across devices."
        case let .error(message):
            return message
        case .syncing:
            return nil
        }
    }
}

#Preview("Badges") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        HStack { ForEach(1...6, id: \.self) { LevelBadge(level: $0) } }
        HStack { StreakBadge(days: 0); StreakBadge(days: 12) }
        SyncStatusBadge(status: .synced(.now.addingTimeInterval(-300)))
        SyncStatusBadge(status: .syncing)
        SyncStatusBadge(status: .offline)
        SyncStatusBadge(status: .disabled)
        SyncStatusBadge(status: .signedOut)
        SyncStatusBadge(status: .error("Quota exceeded"))
    }
    .padding()
}
