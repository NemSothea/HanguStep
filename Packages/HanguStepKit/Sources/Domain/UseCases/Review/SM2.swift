import Foundation

/// SM-2 answer quality, 0 to 5 as in the original algorithm.
public enum ReviewQuality: Int, Sendable, CaseIterable, Codable {
    case blackout = 0
    case incorrectRemembered = 1
    case incorrectEasy = 2
    case correctHard = 3
    case correctHesitant = 4
    case perfect = 5

    /// Multiple choice gives little signal beyond right or wrong, so the mapping is
    /// deliberately coarse: wrong is 1, right is 4, right and fast is 5 (ADR-006).
    public static let fastResponseThreshold: TimeInterval = 4

    public static func forAnswer(isCorrect: Bool, responseTime: TimeInterval) -> ReviewQuality {
        guard isCorrect else { return .incorrectRemembered }
        return responseTime <= fastResponseThreshold ? .perfect : .correctHesitant
    }

    public var isPassing: Bool { rawValue >= 3 }
}

/// SuperMemo SM-2 as published (Wozniak 1990, Wikipedia reference formulation).
/// Pure: the same inputs always produce the same schedule (PRD FR-R6, AC-5).
public enum SM2 {
    public static let initialEaseFactor = 2.5
    public static let minimumEaseFactor = 1.3
    /// An item whose interval has reached this many days counts as mastered (ADR-006).
    public static let masteryIntervalDays = 21

    public struct Outcome: Hashable, Sendable {
        public let easeFactor: Double
        public let intervalDays: Int
        public let repetitions: Int
    }

    /// Next state from the previous one. `nil` previous means the item was never reviewed.
    public static func next(easeFactor: Double, intervalDays: Int, repetitions: Int, quality: ReviewQuality) -> Outcome {
        var interval: Int
        var reps: Int
        if quality.isPassing {
            switch repetitions {
            case 0: interval = 1
            case 1: interval = 6
            default: interval = Int((Double(intervalDays) * easeFactor).rounded())
            }
            reps = repetitions + 1
        } else {
            interval = 1
            reps = 0
        }
        let q = Double(quality.rawValue)
        let ease = max(minimumEaseFactor, easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
        return Outcome(easeFactor: ease, intervalDays: max(1, interval), repetitions: reps)
    }

    /// Applies one review to a schedule. The next review date is the start of the
    /// calendar day `intervalDays` after `date`, so "due today" means
    /// `nextReviewDate <= now` whatever the time of day.
    ///
    /// A target advances at most once per calendar day: a second passing answer on
    /// the same day (two questions on one word in a mixed quiz) keeps the schedule.
    /// A failing answer always resets it.
    public static func review(
        _ previous: ReviewSchedule?,
        target: LearningTarget,
        id: ReviewScheduleID,
        quality: ReviewQuality,
        on date: Date,
        calendar: Calendar
    ) -> ReviewSchedule {
        if let previous, let last = previous.lastReviewedAt, quality.isPassing, calendar.isDate(last, inSameDayAs: date) {
            var unchanged = previous
            unchanged.lastReviewedAt = date
            return unchanged
        }
        let outcome = next(
            easeFactor: previous?.easeFactor ?? initialEaseFactor,
            intervalDays: previous?.intervalDays ?? 0,
            repetitions: previous?.repetitions ?? 0,
            quality: quality
        )
        let startOfDay = calendar.startOfDay(for: date)
        let nextDate = calendar.date(byAdding: .day, value: outcome.intervalDays, to: startOfDay) ?? startOfDay.addingTimeInterval(Double(outcome.intervalDays) * 86_400)
        return ReviewSchedule(
            id: previous?.id ?? id,
            target: target,
            easeFactor: outcome.easeFactor,
            intervalDays: outcome.intervalDays,
            repetitions: outcome.repetitions,
            nextReviewDate: nextDate,
            lastReviewedAt: date
        )
    }
}

public extension ReviewSchedule {
    var isMastered: Bool { intervalDays >= SM2.masteryIntervalDays }

    /// Whole days past the review date, 0 when due today or later.
    func overdueDays(on date: Date, calendar: Calendar) -> Int {
        let due = calendar.startOfDay(for: nextReviewDate)
        let today = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: due, to: today).day ?? 0)
    }
}
