import Domain
import Features
import Foundation
import Observation
import Persistence

/// Composition root. The only place that knows concrete repository types.
@MainActor
@Observable
final class AppContainer {
    enum State {
        case starting
        case ready(AppDependencies, LearnerPreferences, SyncStatusModel)
        case failed(String)
    }

    /// Private CloudKit database container (ADR-003). Must match App/HanguStep.entitlements.
    static let cloudKitContainerIdentifier = "iCloud.com.nemsothea.hangustep"
    private static let syncPreferenceKey = "sync.enabled"

    private(set) var state: State = .starting
    private var monitor: SyncMonitor?
    private var monitorTask: Task<Void, Never>?
    private var bootstrapTask: Task<Void, Never>?

    /// Device-local choice. Defaults to on; a learner without iCloud simply sees "not signed in".
    private static var isSyncPreferred: Bool {
        get { UserDefaults.standard.object(forKey: syncPreferenceKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: syncPreferenceKey) }
    }

    private static var isUITesting: Bool { CommandLine.arguments.contains("--ui-testing") }

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
            // UI tests and the simulator have no iCloud entitlement; keep them local.
            let sync: PersistenceController.SyncOption = (Self.isSyncPreferred && !Self.isUITesting)
                ? .cloudKit(containerIdentifier: Self.cloudKitContainerIdentifier)
                : .off
            let controller = try PersistenceController(mode: .onDisk(directory: Self.storeDirectory()), sync: sync)
            _ = try await CoreDataContentStore(controller: controller).apply(SampleContent.package)
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
                learnerChanges: monitor
            )
            let settings = try await settingsRepository.load()
            let preferences = LearnerPreferences(settings: settings, save: saveSettings)
            let syncStatus = SyncStatusModel(state: monitor.currentState, isSyncPreferred: Self.isSyncPreferred) { [weak self] enabled in
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
            state = .ready(dependencies, preferences, syncStatus)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    private static var deviceName: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return ProcessInfo.processInfo.hostName
        #endif
    }

    private static func storeDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        #if DEBUG
        // UI tests start from an empty learner store every run.
        if CommandLine.arguments.contains("--ui-testing") {
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
