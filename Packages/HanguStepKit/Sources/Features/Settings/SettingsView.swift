import DesignSystem
import Domain
import SwiftUI

struct SettingsView: View {
    let dependencies: AppDependencies
    @Environment(LearnerPreferences.self) private var preferences
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Learning") {
                Picker("Show meanings first in", selection: binding(\.glossLanguage)) {
                    Text("English").tag(GlossLanguage.english)
                    Text("Khmer · ខ្មែរ").tag(GlossLanguage.khmer)
                }
                Stepper("Daily goal: \(preferences.settings.dailyGoal) questions", value: binding(\.dailyGoal), in: 5...200, step: 5)
                Stepper("Review limit: \(preferences.settings.reviewLimit)", value: binding(\.reviewLimit), in: 10...200, step: 10)
                Toggle("Pronunciation", isOn: binding(\.pronunciationEnabled))
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
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(HSColor.danger) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    /// Writes through `LearnerPreferences`, which persists via the save use case.
    private func binding<Value>(_ keyPath: WritableKeyPath<LearnerSettings, Value>) -> Binding<Value> {
        Binding(
            get: { preferences.settings[keyPath: keyPath] },
            set: { newValue in
                Task {
                    do { try await preferences.update { $0[keyPath: keyPath] = newValue } }
                    catch { errorMessage = error.localizedDescription }
                }
            }
        )
    }
}
