import Foundation

/// Answers on one calendar day.
public struct DailyActivity: Hashable, Sendable, Identifiable {
    public var id: Date { day }
    public let day: Date
    public let answered: Int
    public let correct: Int

    public init(day: Date, answered: Int, correct: Int) {
        self.day = day
        self.answered = answered
        self.correct = correct
    }

    public var accuracy: Double? { answered == 0 ? nil : Double(correct) / Double(answered) }
}

/// A target answered often enough to judge and answered badly (PRD FR-P4).
public struct WeakItem: Hashable, Sendable, Identifiable {
    public var id: LearningTarget { target }
    public let target: LearningTarget
    public let answered: Int
    public let correct: Int

    public init(target: LearningTarget, answered: Int, correct: Int) {
        self.target = target
        self.answered = answered
        self.correct = correct
    }

    public var accuracy: Double { answered == 0 ? 0 : Double(correct) / Double(answered) }
}

/// Everything derived from attempts and sessions (PRD FR-P2, FR-P3, FR-P6).
public struct ProgressSummary: Hashable, Sendable {
    public let totals: AttemptSummary
    public let answeredToday: Int
    public let correctToday: Int
    public let minutesToday: Int
    public let currentStreak: Int
    public let longestStreak: Int
    /// Oldest first, one entry per day, always 7 entries ending today.
    public let last7Days: [DailyActivity]
    /// Oldest first, one entry per day, always 30 entries ending today.
    public let last30Days: [DailyActivity]
    public let weakItems: [WeakItem]

    public init(
        totals: AttemptSummary,
        answeredToday: Int,
        correctToday: Int,
        minutesToday: Int,
        currentStreak: Int,
        longestStreak: Int,
        last7Days: [DailyActivity],
        last30Days: [DailyActivity],
        weakItems: [WeakItem]
    ) {
        self.totals = totals
        self.answeredToday = answeredToday
        self.correctToday = correctToday
        self.minutesToday = minutesToday
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.last7Days = last7Days
        self.last30Days = last30Days
        self.weakItems = weakItems
    }

    public var answeredLast7Days: Int { last7Days.reduce(0) { $0 + $1.answered } }
    public var accuracyLast7Days: Double {
        let answered = answeredLast7Days
        return answered == 0 ? 0 : Double(last7Days.reduce(0) { $0 + $1.correct }) / Double(answered)
    }
    public var hasActivity: Bool { totals.total > 0 }

    public static let empty = ProgressSummary(
        totals: AttemptSummary(total: 0, correct: 0), answeredToday: 0, correctToday: 0, minutesToday: 0,
        currentStreak: 0, longestStreak: 0, last7Days: [], last30Days: [], weakItems: []
    )
}

/// Pure statistics over attempt and session records. Day boundaries follow the
/// supplied calendar (device local time zone in the app, ADR-006).
public enum ProgressStatistics {
    public static let weakAccuracyThreshold = 0.6
    public static let weakMinimumAttempts = 3

    public static func summary(attempts: [Attempt], sessions: [StudySession], now: Date, calendar: Calendar) -> ProgressSummary {
        let today = calendar.startOfDay(for: now)
        var byDay: [Date: (answered: Int, correct: Int)] = [:]
        for attempt in attempts {
            let day = calendar.startOfDay(for: attempt.answeredAt)
            var entry = byDay[day] ?? (0, 0)
            entry.answered += 1
            if attempt.isCorrect { entry.correct += 1 }
            byDay[day] = entry
        }
        let todayEntry = byDay[today] ?? (0, 0)
        let streaks = streaks(activeDays: Set(byDay.keys), today: today, calendar: calendar)

        return ProgressSummary(
            totals: AttemptSummary(total: attempts.count, correct: attempts.filter(\.isCorrect).count),
            answeredToday: todayEntry.answered,
            correctToday: todayEntry.correct,
            minutesToday: minutes(of: sessions, attempts: attempts, on: today, calendar: calendar),
            currentStreak: streaks.current,
            longestStreak: streaks.longest,
            last7Days: activity(byDay: byDay, days: 7, endingOn: today, calendar: calendar),
            last30Days: activity(byDay: byDay, days: 30, endingOn: today, calendar: calendar),
            weakItems: weakItems(from: attempts)
        )
    }

    /// Current streak counts consecutive active days ending today, or ending
    /// yesterday when today has no activity yet (the streak is not broken until
    /// midnight passes, PRD scenario J1). Longest streak scans all history.
    public static func streaks(activeDays: Set<Date>, today: Date, calendar: Calendar) -> (current: Int, longest: Int) {
        guard !activeDays.isEmpty else { return (0, 0) }
        func previous(_ day: Date) -> Date { calendar.date(byAdding: .day, value: -1, to: day) ?? day.addingTimeInterval(-86_400) }

        var current = 0
        var cursor = activeDays.contains(today) ? today : previous(today)
        while activeDays.contains(cursor) {
            current += 1
            cursor = previous(cursor)
        }

        var longest = 0
        var run = 0
        var last: Date?
        for day in activeDays.sorted() {
            if let last, calendar.dateComponents([.day], from: last, to: day).day == 1 {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            last = day
        }
        return (current, longest)
    }

    public static func weakItems(from attempts: [Attempt]) -> [WeakItem] {
        var byTarget: [LearningTarget: (answered: Int, correct: Int)] = [:]
        for attempt in attempts {
            guard let target = attempt.target else { continue }
            var entry = byTarget[target] ?? (0, 0)
            entry.answered += 1
            if attempt.isCorrect { entry.correct += 1 }
            byTarget[target] = entry
        }
        return byTarget
            .map { WeakItem(target: $0.key, answered: $0.value.answered, correct: $0.value.correct) }
            .filter { $0.answered >= weakMinimumAttempts && $0.accuracy < weakAccuracyThreshold }
            .sorted { ($0.accuracy, -$0.answered, $0.target.contentID) < ($1.accuracy, -$1.answered, $1.target.contentID) }
    }

    private static func activity(byDay: [Date: (answered: Int, correct: Int)], days: Int, endingOn today: Date, calendar: Calendar) -> [DailyActivity] {
        (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let entry = byDay[day] ?? (0, 0)
            return DailyActivity(day: day, answered: entry.answered, correct: entry.correct)
        }
    }

    /// Sessions count on the day they started. An unfinished session counts up to
    /// its last answer, so an abandoned sheet does not keep adding minutes.
    private static func minutes(of sessions: [StudySession], attempts: [Attempt], on today: Date, calendar: Calendar) -> Int {
        var lastAnswer: [StudySessionID: Date] = [:]
        for attempt in attempts {
            lastAnswer[attempt.sessionID] = max(lastAnswer[attempt.sessionID] ?? .distantPast, attempt.answeredAt)
        }
        let seconds = sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: today) }
            .reduce(0.0) { total, session in
                let end = session.endedAt ?? lastAnswer[session.id] ?? session.startedAt
                return total + max(0, end.timeIntervalSince(session.startedAt))
            }
        return Int((seconds / 60).rounded())
    }
}
