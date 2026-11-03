import Foundation

public struct MistakeItem: Hashable, Sendable, Identifiable {
    public var id: LearningTarget { target }
    public let target: LearningTarget
    public let timesMissed: Int
    public let timesAnswered: Int
    public let lastMissedAt: Date
    public let consecutiveCorrect: Int

    public init(target: LearningTarget, timesMissed: Int, timesAnswered: Int, lastMissedAt: Date, consecutiveCorrect: Int) {
        self.target = target
        self.timesMissed = timesMissed
        self.timesAnswered = timesAnswered
        self.lastMissedAt = lastMissedAt
        self.consecutiveCorrect = consecutiveCorrect
    }

    public var accuracy: Double { timesAnswered == 0 ? 0 : Double(timesAnswered - timesMissed) / Double(timesAnswered) }
}

/// Mistakes are derived from attempts, never stored (DATABASE_SCHEMA.md §1).
/// A target leaves the list after `clearThreshold` consecutive correct answers (PRD FR-R2).
public enum MistakeDerivation {
    public static let clearThreshold = 2

    public static func mistakes(from attempts: [Attempt], clearThreshold: Int = clearThreshold) -> [MistakeItem] {
        struct Accumulator {
            var missed = 0
            var answered = 0
            var lastMissedAt = Date.distantPast
            var streak = 0
        }
        var byTarget: [LearningTarget: Accumulator] = [:]
        for attempt in attempts.sorted(by: { $0.answeredAt < $1.answeredAt }) {
            guard let target = attempt.target else { continue }
            var accumulator = byTarget[target] ?? Accumulator()
            accumulator.answered += 1
            if attempt.isCorrect {
                accumulator.streak += 1
            } else {
                accumulator.missed += 1
                accumulator.streak = 0
                accumulator.lastMissedAt = max(accumulator.lastMissedAt, attempt.answeredAt)
            }
            byTarget[target] = accumulator
        }
        return byTarget
            .filter { $0.value.missed > 0 && $0.value.streak < clearThreshold }
            .map { MistakeItem(target: $0.key, timesMissed: $0.value.missed, timesAnswered: $0.value.answered, lastMissedAt: $0.value.lastMissedAt, consecutiveCorrect: $0.value.streak) }
            .sorted { $0.lastMissedAt > $1.lastMissedAt }
    }
}

/// A mistake joined with its content for display.
public struct MistakeEntry: Hashable, Sendable, Identifiable {
    public var id: LearningTarget { mistake.target }
    public let mistake: MistakeItem
    public let title: String
    public let gloss: Gloss
    public let level: TOPIKLevel

    public init(mistake: MistakeItem, title: String, gloss: Gloss, level: TOPIKLevel) {
        self.mistake = mistake
        self.title = title
        self.gloss = gloss
        self.level = level
    }
}

public enum MistakeSort: String, Sendable, CaseIterable {
    case recent
    case frequent
}

public protocol ListMistakesUseCase: Sendable {
    func execute(sort: MistakeSort) async throws -> [MistakeEntry]
}

public struct ListMistakes: ListMistakesUseCase {
    private let attempts: any AttemptRepository
    private let vocabulary: any VocabularyRepository
    private let grammar: any GrammarRepository

    public init(attempts: any AttemptRepository, vocabulary: any VocabularyRepository, grammar: any GrammarRepository) {
        self.attempts = attempts
        self.vocabulary = vocabulary
        self.grammar = grammar
    }

    public func execute(sort: MistakeSort) async throws -> [MistakeEntry] {
        let mistakes = MistakeDerivation.mistakes(from: try await attempts.allAttempts())
        var entries: [MistakeEntry] = []
        for mistake in mistakes {
            switch mistake.target {
            case let .vocabulary(id):
                if let item = try await vocabulary.item(id: id) {
                    entries.append(MistakeEntry(mistake: mistake, title: item.hangul, gloss: item.meaning, level: item.level))
                }
            case let .grammar(id):
                if let pattern = try await grammar.pattern(id: id) {
                    entries.append(MistakeEntry(mistake: mistake, title: pattern.pattern, gloss: pattern.explanation, level: pattern.level))
                }
            }
        }
        switch sort {
        case .recent: return entries.sorted { $0.mistake.lastMissedAt > $1.mistake.lastMissedAt }
        case .frequent: return entries.sorted { ($0.mistake.timesMissed, $0.mistake.lastMissedAt) > ($1.mistake.timesMissed, $1.mistake.lastMissedAt) }
        }
    }
}
