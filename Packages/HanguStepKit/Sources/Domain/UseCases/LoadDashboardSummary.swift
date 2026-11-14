import Foundation

public struct DashboardSummary: Hashable, Sendable {
    public let vocabularyCount: Int
    public let grammarCount: Int
    public let progress: ProgressSummary
    public let dueCount: Int
    public let masteredCount: Int
    public let dailyGoal: Int

    public init(vocabularyCount: Int, grammarCount: Int, progress: ProgressSummary, dueCount: Int, masteredCount: Int, dailyGoal: Int) {
        self.vocabularyCount = vocabularyCount
        self.grammarCount = grammarCount
        self.progress = progress
        self.dueCount = dueCount
        self.masteredCount = masteredCount
        self.dailyGoal = dailyGoal
    }

    public var attempts: AttemptSummary { progress.totals }
    /// 0...1 progress toward today's question goal (PRD FR-P5).
    public var goalProgress: Double { dailyGoal <= 0 ? 0 : min(1, Double(progress.answeredToday) / Double(dailyGoal)) }
    public var isGoalReached: Bool { dailyGoal > 0 && progress.answeredToday >= dailyGoal }
}

/// Use cases are protocols so view models can be tested with stubs.
public protocol LoadDashboardSummaryUseCase: Sendable {
    func execute() async throws -> DashboardSummary
}

public struct LoadDashboardSummary: LoadDashboardSummaryUseCase {
    private let vocabulary: any VocabularyRepository
    private let grammar: any GrammarRepository
    private let attempts: any AttemptRepository
    private let sessions: any StudySessionRepository
    private let schedules: any ReviewScheduleRepository
    private let settings: any LearnerSettingsRepository
    private let dates: any DateProvider
    private let calendar: Calendar

    public init(
        vocabulary: any VocabularyRepository,
        grammar: any GrammarRepository,
        attempts: any AttemptRepository,
        sessions: any StudySessionRepository,
        schedules: any ReviewScheduleRepository,
        settings: any LearnerSettingsRepository,
        dates: any DateProvider = SystemDateProvider(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.vocabulary = vocabulary
        self.grammar = grammar
        self.attempts = attempts
        self.sessions = sessions
        self.schedules = schedules
        self.settings = settings
        self.dates = dates
        self.calendar = calendar
    }

    public func execute() async throws -> DashboardSummary {
        async let vocabularyCount = vocabulary.count()
        async let grammarCount = grammar.count()
        async let allAttempts = attempts.allAttempts()
        async let recentSessions = sessions.sessions(limit: ProgressWindow.sessionLimit)
        async let allSchedules = schedules.all()
        async let learnerSettings = settings.load()

        let now = dates.now()
        let progress = ProgressStatistics.summary(attempts: try await allAttempts, sessions: try await recentSessions, now: now, calendar: calendar)
        let scheduleCounts = ScheduleCounts(schedules: try await allSchedules, now: now)
        return DashboardSummary(
            vocabularyCount: try await vocabularyCount,
            grammarCount: try await grammarCount,
            progress: progress,
            dueCount: scheduleCounts.due,
            masteredCount: scheduleCounts.mastered,
            dailyGoal: try await learnerSettings.dailyGoal
        )
    }
}

enum ProgressWindow {
    /// Sessions fetched for "minutes today". Far more than one learner starts in a day.
    static let sessionLimit = 200
}

struct ScheduleCounts {
    let due: Int
    let mastered: Int

    init(schedules: [ReviewSchedule], now: Date) {
        due = schedules.filter { $0.nextReviewDate <= now }.count
        mastered = schedules.filter(\.isMastered).count
    }
}
