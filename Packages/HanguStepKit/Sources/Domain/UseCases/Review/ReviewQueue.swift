import Foundation

/// One due item with its content, for the review queue screen (S11).
public struct ReviewQueueEntry: Hashable, Sendable, Identifiable {
    public var id: LearningTarget { schedule.target }
    public let schedule: ReviewSchedule
    public let title: String
    public let gloss: Gloss
    public let level: TOPIKLevel
    public let overdueDays: Int

    public init(schedule: ReviewSchedule, title: String, gloss: Gloss, level: TOPIKLevel, overdueDays: Int) {
        self.schedule = schedule
        self.title = title
        self.gloss = gloss
        self.level = level
        self.overdueDays = overdueDays
    }
}

public struct ReviewQueue: Hashable, Sendable {
    public let entries: [ReviewQueueEntry]
    /// Due items beyond the daily limit.
    public let remaining: Int
    public let limit: Int

    public init(entries: [ReviewQueueEntry], remaining: Int, limit: Int) {
        self.entries = entries
        self.remaining = remaining
        self.limit = limit
    }
}

public protocol ListReviewQueueUseCase: Sendable {
    func execute() async throws -> ReviewQueue
}

public struct ListReviewQueue: ListReviewQueueUseCase {
    private let schedules: any ReviewScheduleRepository
    private let settings: any LearnerSettingsRepository
    private let vocabulary: any VocabularyRepository
    private let grammar: any GrammarRepository
    private let dates: any DateProvider
    private let calendar: Calendar

    public init(
        schedules: any ReviewScheduleRepository,
        settings: any LearnerSettingsRepository,
        vocabulary: any VocabularyRepository,
        grammar: any GrammarRepository,
        dates: any DateProvider = SystemDateProvider(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.schedules = schedules
        self.settings = settings
        self.vocabulary = vocabulary
        self.grammar = grammar
        self.dates = dates
        self.calendar = calendar
    }

    public func execute() async throws -> ReviewQueue {
        let now = dates.now()
        let limit = try await settings.load().reviewLimit
        let due = try await schedules.due(onOrBefore: now, limit: Int.max)
        // Join content first so retired targets neither take a slot nor count as remaining.
        var entries: [ReviewQueueEntry] = []
        var matched = 0
        for schedule in due {
            let overdue = schedule.overdueDays(on: now, calendar: calendar)
            let entry: ReviewQueueEntry?
            switch schedule.target {
            case let .vocabulary(id):
                entry = try await vocabulary.item(id: id).map { ReviewQueueEntry(schedule: schedule, title: $0.hangul, gloss: $0.meaning, level: $0.level, overdueDays: overdue) }
            case let .grammar(id):
                entry = try await grammar.pattern(id: id).map { ReviewQueueEntry(schedule: schedule, title: $0.pattern, gloss: $0.explanation, level: $0.level, overdueDays: overdue) }
            }
            guard let entry else { continue }
            matched += 1
            if entries.count < limit { entries.append(entry) }
        }
        return ReviewQueue(entries: entries, remaining: max(0, matched - limit), limit: limit)
    }
}
