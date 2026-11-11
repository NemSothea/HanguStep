import Assistant
import Domain
import Features
import Foundation
import Observation
import os
import Persistence
#if canImport(UIKit)
import UIKit
#endif

/// Composition root. The only place that knows concrete repository types.
@MainActor
@Observable
final class AppContainer {
    enum State {
        case starting
        case ready(AppDependencies, LearnerPreferences, SyncStatusModel, AssistantModel)
        case failed(String)
    }

    /// Private CloudKit database container (ADR-003). Must match App/HanguStep.entitlements.
    static let cloudKitContainerIdentifier = "iCloud.com.nemsothea.hangustep"
    private static let syncPreferenceKey = "sync.enabled"

    /// Launch intervals for Instruments (Points of Interest / os_signpost, category `Launch`).
    /// AC-13 is measured on a device from these; see PRODUCTION_READINESS.md.
    private static let signposter = OSSignposter(subsystem: "com.nemsothea.hangustep", category: "Launch")

    private(set) var state: State = .starting
    private var monitor: SyncMonitor?
    private var monitorTask: Task<Void, Never>?
    private var bootstrapTask: Task<Void, Never>?

    /// Device-local choice. Defaults to on; a learner without iCloud simply sees "not signed in".
    private static var isSyncPreferred: Bool {
        get { UserDefaults.standard.object(forKey: syncPreferenceKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: syncPreferenceKey) }
    }

    /// Whether this build can talk to CloudKit at all. Set at build time from
    /// `HSCloudKitAvailable` (Info.plist, project.yml): unsigned builds carry no
    /// entitlement, and creating a CloudKit container there kills the app at launch.
    private static var isCloudKitAvailable: Bool {
        guard !isUITesting else { return false }
        let value = Bundle.main.object(forInfoDictionaryKey: "HSCloudKitAvailable") as? String
        return value?.uppercased() != "NO"
    }

    /// Debug builds only: a Release build ignores `--ui-testing`, so a launch argument can
    /// never switch a learner's install to the in-memory secret store or disable sync.
    private static var isUITesting: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("--ui-testing")
        #else
        return false
        #endif
    }

    /// Opens the stores, imports bundled content if newer, loads settings and builds the
    /// dependency graph. Single-flight: concurrent callers await the same run.
    func bootstrap() async {
        if let running = bootstrapTask {
            await running.value
            return
        }
        let task = Task { await run() }
        bootstrapTask = task
        await task.value
        bootstrapTask = nil
    }

    private func run() async {
        // Tear the previous graph down before opening the same files again.
        monitorTask?.cancel()
        monitorTask = nil
        monitor?.stop()
        monitor = nil
        do {
            // UI tests and unsigned builds have no iCloud entitlement; keep them local.
            let sync: PersistenceController.SyncOption = (Self.isSyncPreferred && Self.isCloudKitAvailable)
                ? .cloudKit(containerIdentifier: Self.cloudKitContainerIdentifier)
                : .off
            let directory = try Self.storeDirectory()
            // Store opening and content import run off the main actor so the launch
            // screen stays responsive (Phase 10). Both are synchronous Core Data work.
            let storesInterval = Self.signposter.beginInterval("OpenStores")
            let controller = try await Task.detached(priority: .userInitiated) {
                try PersistenceController(mode: .onDisk(directory: directory), sync: sync)
            }.value
            Self.signposter.endInterval("OpenStores", storesInterval)
            // Bundled JSON library, validated on load; applied only when newer than the installed version.
            let contentInterval = Self.signposter.beginInterval("InstallContent")
            let contentInfo = try await BundledContentInstaller.installIfNeeded(controller: controller)
            Self.signposter.endInterval("InstallContent", contentInterval)
            let monitor = SyncMonitor(controller: controller)
            self.monitor = monitor

            let vocabulary = CoreDataVocabularyRepository(controller: controller)
            let grammar = CoreDataGrammarRepository(controller: controller)
            let questions = CoreDataQuestionRepository(controller: controller)
            let attempts = CoreDataAttemptRepository(controller: controller)
            let bookmarks = CoreDataBookmarkRepository(controller: controller)
            let sessions = CoreDataStudySessionRepository(controller: controller)
            let notes = CoreDataLearnerNoteRepository(controller: controller)
            let settingsRepository = CoreDataLearnerSettingsRepository(controller: controller)
            let schedules = CoreDataReviewScheduleRepository(controller: controller)

            // Assistant (Phase 8, ADR-008): device-local preference, key in the Keychain,
            // provider resolved on every call. UI tests get an isolated, cleared store.
            let assistantSettings = UserDefaultsAssistantSettingsStore(suiteName: Self.isUITesting ? "ui-testing" : nil)
            let secrets: any SecretStore = Self.isUITesting ? InMemorySecretStore() : KeychainSecretStore()
            if Self.isUITesting { assistantSettings.save(AssistantSettings()) }
            let providers = ConfiguredAssistantProviderSource(settings: assistantSettings, secrets: secrets) { kind, apiKey in
                switch kind {
                case .mock: return MockAssistantProvider()
                case .claude: return ClaudeAssistantProvider(apiKey: apiKey ?? "")
                }
            }
            let generatedQuestions = CoreDataGeneratedQuestionStore(controller: controller)

            let saveSettings = SaveSettings(repository: settingsRepository)
            let dependencies = AppDependencies(
                loadDashboardSummary: LoadDashboardSummary(vocabulary: vocabulary, grammar: grammar, attempts: attempts, sessions: sessions, schedules: schedules, settings: settingsRepository),
                loadProgressReport: LoadProgressReport(attempts: attempts, sessions: sessions, schedules: schedules, settings: settingsRepository, vocabulary: vocabulary, grammar: grammar),
                listReviewQueue: ListReviewQueue(schedules: schedules, settings: settingsRepository, vocabulary: vocabulary, grammar: grammar),
                browseVocabulary: BrowseVocabulary(vocabulary: vocabulary),
                getVocabularyDetail: GetVocabularyDetail(vocabulary: vocabulary, bookmarks: bookmarks, notes: notes),
                browseGrammar: BrowseGrammar(grammar: grammar),
                getGrammarDetail: GetGrammarDetail(grammar: grammar, questions: questions, bookmarks: bookmarks, notes: notes),
                toggleBookmark: ToggleBookmark(bookmarks: bookmarks),
                listBookmarks: ListBookmarks(bookmarks: bookmarks, vocabulary: vocabulary, grammar: grammar),
                saveNote: SaveNote(notes: notes),
                startQuiz: StartQuizSession(questions: questions, sessions: sessions, attempts: attempts, schedules: schedules, settings: settingsRepository, deviceName: Self.deviceName),
                resumeQuiz: ResumeQuizSession(questions: questions, sessions: sessions, attempts: attempts),
                submitAnswer: SubmitAnswer(sessions: sessions, attempts: attempts, schedules: schedules),
                finishQuiz: FinishQuizSession(sessions: sessions, attempts: attempts, questions: questions),
                listMistakes: ListMistakes(attempts: attempts, vocabulary: vocabulary, grammar: grammar),
                listHistory: ListQuizHistory(sessions: sessions, attempts: attempts),
                loadSettings: LoadSettings(repository: settingsRepository),
                saveSettings: saveSettings,
                pronouncer: SpeechPronouncer(),
                learnerChanges: monitor,
                contentInfo: contentInfo,
                explainAnswer: ExplainAnswer(providers: providers, vocabulary: vocabulary, grammar: grammar),
                generatePractice: GeneratePracticeQuestions(providers: providers, vocabulary: vocabulary, grammar: grammar, store: generatedQuestions),
                generatedQuestions: generatedQuestions
            )
            let assistant = AssistantModel(store: assistantSettings, secrets: secrets)
            let settings = try await settingsRepository.load()
            let preferences = LearnerPreferences(settings: settings, save: saveSettings)
            let syncStatus = SyncStatusModel(state: monitor.currentState, isSyncPreferred: Self.isSyncPreferred, isSyncAvailable: Self.isCloudKitAvailable) { [weak self] enabled in
                guard let self else { return }
                let previous = Self.isSyncPreferred
                Self.isSyncPreferred = enabled
                // The container must be rebuilt to add or drop CloudKit mirroring.
                self.state = .starting
                await self.bootstrap()
                if case .failed = self.state {
                    // Keep the stored preference consistent with what last worked.
                    Self.isSyncPreferred = previous
                }
            }
            monitor.start()
            monitorTask = Task { await syncStatus.observe(monitor.states()) }
            state = .ready(dependencies, preferences, syncStatus, assistant)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    /// Device class only ("iPhone", "iPad", "Mac"). The user-assigned device name and the
    /// host name carry personal data and `ProcessInfo.hostName` can block on a DNS lookup,
    /// so neither is stored in synced session history (SECURITY.md §5, data minimisation).
    private static var deviceName: String {
        #if os(macOS)
        return "Mac"
        #else
        return UIDevice.current.model
        #endif
    }

    private static func storeDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        #if DEBUG
        // UI tests start from an empty learner store every run.
        if isUITesting {
            let scratch = base.appendingPathComponent("HanguStep-UITests", isDirectory: true)
            try? FileManager.default.removeItem(at: scratch)
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            return scratch
        }
        #endif
        let directory = base.appendingPathComponent("HanguStep", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
