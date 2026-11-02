import DesignSystem
import SwiftUI

/// Static shell. Preferences persist from Phase 5, sync status becomes live in Phase 6.
struct SettingsView: View {
    @State private var glossLanguage = "en"
    @State private var dailyGoal = 20
    @State private var pronunciationEnabled = true

    var body: some View {
        Form {
            Section("Learning") {
                Picker("Show meanings first in", selection: $glossLanguage) {
                    Text("English").tag("en")
                    Text("Khmer · ខ្មែរ").tag("km")
                }
                Stepper("Daily goal: \(dailyGoal) questions", value: $dailyGoal, in: 5...200, step: 5)
                Toggle("Pronunciation", isOn: $pronunciationEnabled)
            }
            Section("iCloud") {
                SyncStatusBadge(status: .disabled)
                DisclosureGroup("What syncs") {
                    Text("Your answers, bookmarks, notes, review schedule and settings. The vocabulary library ships with the app and is never uploaded.")
                        .font(Typography.caption)
                        .foregroundStyle(HSColor.textSecondary)
                }
            }
            Section("Content") {
                LabeledContent("Content version", value: "sample")
                LabeledContent("License", value: "CC BY 4.0")
            }
            #if DEBUG
            Section("Developer") {
                NavigationLink("Component gallery") { ComponentGalleryView() }
            }
            #endif
            Section("About") {
                LabeledContent("Version", value: "0.1.0")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
