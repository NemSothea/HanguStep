import Foundation

/// A weak item joined with its content for display.
public struct WeakEntry: Hashable, Sendable, Identifiable {
    public var id: LearningTarget { item.target }
    public let item: WeakItem
    public let title: String
    public let gloss: Gloss
    public let level: TOPIKLevel

    public init(item: WeakItem, title: String, gloss: Gloss, level: TOPIKLevel) {
        self.item = item
        self.title = title
        self.gloss = gloss
        self.level = level
    }
}

public struct ProgressReport: Hashable, Sendable {
    public let summary: ProgressSummary
    public let dueCount: Int
    public let masteredCount: Int
    public let scheduledCount: Int
    public let dailyGoal: Int
    public let weakWords: [WeakEntry]
    public let weakGrammar: [WeakEntry]

    public init(summary: ProgressSummary, dueCount: Int, masteredCount: Int, scheduledCount: Int, dailyGoal: Int, weakWords: [WeakEntry], weakGrammar: [WeakEntry]) {
        self.summary = summary
        self.dueCount = dueCount
        self.masteredCount = masteredCount
        self.scheduledCount = scheduledCount
        self.dailyGoal = dailyGoal
        self.weakWords = weakWords
        self.weakGrammar = weakGrammar
    }
}

public protocol LoadProgressReportUseCase: Sendable {
    func execute() async throws -> ProgressReport
}

/// Progress screen data (S8). Same statistics as the dashboard plus content joins.
public struct LoadProgressReport: LoadProgressReportUseCase {
    public static let weakListLimit = 10

    private let attempts: any AttemptRepository
    private let sessions: any StudySessionRepository
    private let schedules: any ReviewScheduleRepository
    private let settings: any LearnerSettingsRepository
    private let vocabulary: any VocabularyRepository
    private let grammar: any GrammarRepository
    private let dates: any DateProvider
    private let calendar: Calendar

    public init(
        attempts: any AttemptRepository,
        sessions: any StudySessionRepository,
        schedules: any ReviewScheduleRepository,
        settings: any LearnerSettingsRepository,
        vocabulary: any VocabularyRepository,
        grammar: any GrammarRepository,
        dates: any DateProvider = SystemDateProvider(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.attempts = attempts
        self.sessions = sessions
        self.schedules = schedules
        self.settings = settings
        self.vocabulary = vocabulary
        self.grammar = grammar
        self.dates = dates
        self.calendar = calendar
    }

    public func execute() async throws -> ProgressReport {
        async let allAttempts = attempts.allAttempts()
        async let recentSessions = sessions.sessions(limit: ProgressWindow.sessionLimit)
        async let allSchedules = schedules.all()
        async let learnerSettings = settings.load()

        let now = dates.now()
        let summary = ProgressStatistics.summary(attempts: try await allAttempts, sessions: try await recentSessions, now: now, calendar: calendar)
        let scheduleList = try await allSchedules
        let counts = ScheduleCounts(schedules: scheduleList, now: now)

        var words: [WeakEntry] = []
        var patterns: [WeakEntry] = []
        for item in summary.weakItems {
            switch item.target {
            case let .vocabulary(id):
                guard words.count < Self.weakListLimit, let word = try await vocabulary.item(id: id) else { continue }
                words.append(WeakEntry(item: item, title: word.hangul, gloss: word.meaning, level: word.level))
            case let .grammar(id):
                guard patterns.count < Self.weakListLimit, let pattern = try await grammar.pattern(id: id) else { continue }
                patterns.append(WeakEntry(item: item, title: pattern.pattern, gloss: pattern.explanation, level: pattern.level))
            }
        }
        return ProgressReport(
            summary: summary,
            dueCount: counts.due,
            masteredCount: counts.mastered,
            scheduledCount: scheduleList.count,
            dailyGoal: try await learnerSettings.dailyGoal,
            weakWords: words,
            weakGrammar: patterns
        )
    }
}
