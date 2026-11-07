import DesignSystem
import Domain
import SwiftUI

struct SettingsView: View {
    let dependencies: AppDependencies
    @Environment(LearnerPreferences.self) private var preferences
    @Environment(SyncStatusModel.self) private var syncStatus
    @Environment(AssistantModel.self) private var assistant
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var errorMessage: String?
    @State private var claudeKeyDraft = ""
    @State private var generatedCount: Int?

    var body: some View {
        Form {
            if dynamicTypeSize.isAccessibilitySize {
                // The menu picker clips its value at accessibility sizes, and the inline
                // picker's own label row does not scale, so the label is a section header.
                Section {
                    Picker("Show meanings first in", selection: binding(\.glossLanguage)) {
                        Text("English").tag(GlossLanguage.english)
                        Text("Khmer · ខ្មែរ").tag(GlossLanguage.khmer)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    // The default header grey is about 3:1 on the grouped background.
                    Text("Show meanings first in")
                        .foregroundStyle(HSColor.textSecondary)
                }
            }
            Section("Learning") {
                if !dynamicTypeSize.isAccessibilitySize {
                    Picker("Show meanings first in", selection: binding(\.glossLanguage)) {
                        Text("English").tag(GlossLanguage.english)
                        Text("Khmer · ខ្មែរ").tag(GlossLanguage.khmer)
                    }
                }
                Stepper("Daily goal: \(preferences.settings.dailyGoal) questions", value: binding(\.dailyGoal), in: 5...200, step: 5)
                Stepper("Review limit: \(preferences.settings.reviewLimit)", value: binding(\.reviewLimit), in: 10...200, step: 10)
                Toggle("Pronunciation", isOn: binding(\.pronunciationEnabled))
            }
            Section("iCloud") {
                SyncStatusBadge(status: syncStatus.badgeStatus)
                Toggle("Sync with iCloud", isOn: Binding(
                    get: { syncStatus.isSyncPreferred },
                    set: { enabled in Task { await syncStatus.setSyncPreferred(enabled) } }
                ))
                .disabled(syncStatus.isApplyingPreference)
                if syncStatus.isSyncPreferred, syncStatus.state.isEnabled {
                    if let imported = syncStatus.state.lastImportAt {
                        LabeledContent("Last import", value: imported.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let exported = syncStatus.state.lastExportAt {
                        LabeledContent("Last export", value: exported.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                DisclosureGroup("What syncs") {
                    Text("Your answers, bookmarks, notes, review schedule and settings. The vocabulary library ships with the app and is never uploaded.")
                        .font(Typography.caption)
                        .foregroundStyle(HSColor.textSecondary)
                }
            }
            assistantSection
            Section("Content") {
                LabeledContent("Content version", value: dependencies.contentInfo.version.formatted())
                LabeledContent("Library", value: "\(dependencies.contentInfo.vocabularyCount) words · \(dependencies.contentInfo.grammarCount) patterns · \(dependencies.contentInfo.questionCount) questions")
                LabeledContent("Source", value: dependencies.contentInfo.sourceName)
                LabeledContent("License", value: dependencies.contentInfo.license)
                if dependencies.contentInfo.pendingReview > 0 {
                    Text("\(dependencies.contentInfo.pendingReview) items await Khmer review.")
                        .font(Typography.caption)
                        .foregroundStyle(HSColor.textSecondary)
                }
            }
            #if DEBUG
            Section("Developer") {
                NavigationLink("Component gallery") { ComponentGalleryView() }
            }
            #endif
            Section("About") {
                LabeledContent("Version", value: Self.appVersion)
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(HSColor.danger) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { generatedCount = try? await dependencies.generatedQuestions.generatedCount() }
    }

    @ViewBuilder
    private var assistantSection: some View {
        Section {
            Toggle("Use the assistant", isOn: Binding(get: { assistant.isEnabled }, set: { assistant.setEnabled($0) }))
                .accessibilityIdentifier("assistant.enabled")
            if assistant.isEnabled {
                Picker("Provider", selection: Binding(get: { assistant.settings.provider }, set: { assistant.setProvider($0) })) {
                    ForEach(AssistantProviderKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                if assistant.settings.provider == .claude {
                    if assistant.hasClaudeKey {
                        LabeledContent("API key", value: "Saved on this device")
                        Button("Remove key", role: .destructive) { assistant.removeClaudeKey() }
                    } else {
                        SecureField("Anthropic API key", text: $claudeKeyDraft)
                            .textContentType(.password)
                            .accessibilityIdentifier("assistant.claudeKey")
                        Button("Save key") {
                            assistant.saveClaudeKey(claudeKeyDraft)
                            claudeKeyDraft = ""
                        }
                        .disabled(claudeKeyDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let message = assistant.errorMessage {
                        Text(message).font(Typography.caption).foregroundStyle(HSColor.danger)
                    }
                }
            }
            if let count = generatedCount, count > 0 {
                LabeledContent("Generated questions", value: count.formatted())
                Button("Delete generated questions", role: .destructive) {
                    Task {
                        _ = try? await dependencies.generatedQuestions.deleteAllGenerated()
                        generatedCount = try? await dependencies.generatedQuestions.generatedCount()
                    }
                }
            }
        } header: {
            Text("Assistant")
        } footer: {
            Text(assistant.settings.provider == .claude && assistant.isEnabled
                 ? "Explanations and practice questions are requested from Anthropic using your key, which stays in this device's Keychain and is never synced. Question text and your answer are sent; your progress is not."
                 : "Explains answers and writes extra practice questions. The built-in assistant works offline using the bundled examples.")
                .font(Typography.caption)
        }
    }

    /// Marketing version and build from the app bundle; "dev" in previews and tests.
    static var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let version = info["CFBundleShortVersionString"] as? String else { return "dev" }
        let build = info["CFBundleVersion"] as? String
        return build.map { "\(version) (\($0))" } ?? version
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
