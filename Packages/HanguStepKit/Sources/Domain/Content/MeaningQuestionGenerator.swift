import Foundation

/// Builds vocabulary meaning questions (Korean → meaning, meaning → Korean) from
/// vocabulary entries. Deterministic: the same entries always give the same
/// distractors, so generated ids and option order are stable across runs and
/// learner attempts keep pointing at the right option (ADR-007).
public enum MeaningQuestionGenerator {
    public static let optionCount = 4

    public static func generate(from vocabulary: [ContentFile.Vocabulary], source: ContentFile.Source) -> [ContentFile.Question] {
        let sorted = vocabulary.sorted { $0.id < $1.id }
        guard sorted.count >= optionCount else { return [] }
        var questions: [ContentFile.Question] = []
        for (index, entry) in sorted.enumerated() {
            let distractors = pickDistractors(for: entry, index: index, from: sorted)
            guard distractors.count == optionCount - 1 else { continue }

            // Korean word → meaning (both glosses shown, so one question serves both settings).
            let meaningOptions = ([entry] + distractors).map { "\($0.meaning.en) / \($0.meaning.km)" }
            let meaningOrder = shuffledOrder(seed: hash(entry.id + "#vm"), count: optionCount)
            questions.append(ContentFile.Question(
                id: "q.vm.\(entry.id)", kind: .vocabularyMeaning, level: entry.level,
                prompt: "'\(entry.hangul)'의 의미는 무엇입니까?",
                options: meaningOrder.map { meaningOptions[$0] }, answer: meaningOrder.firstIndex(of: 0) ?? 0,
                explanation: ContentFile.Text(en: "\(entry.hangul) (\(entry.romanization)) means \"\(entry.meaning.en)\".", km: "\(entry.hangul) (\(entry.romanization)) មានន័យថា \"\(entry.meaning.km)\"។"),
                vocabulary: entry.id, source: source, review: entry.review
            ))

            // Meaning → Korean word.
            let wordOptions = ([entry] + distractors).map(\.hangul)
            let wordOrder = shuffledOrder(seed: hash(entry.id + "#mw"), count: optionCount)
            questions.append(ContentFile.Question(
                id: "q.mw.\(entry.id)", kind: .meaningToWord, level: entry.level,
                prompt: "Which word means \"\(entry.meaning.en)\" (\(entry.meaning.km))?",
                options: wordOrder.map { wordOptions[$0] }, answer: wordOrder.firstIndex(of: 0) ?? 0,
                explanation: ContentFile.Text(en: "\"\(entry.meaning.en)\" is \(entry.hangul) (\(entry.romanization)).", km: "\"\(entry.meaning.km)\" គឺ \(entry.hangul) (\(entry.romanization))។"),
                vocabulary: entry.id, source: source, review: entry.review
            ))
        }
        return questions
    }

    /// Prefers same part of speech and same level, then same part of speech, then
    /// anything with a different meaning. Never repeats a hangul or meaning.
    static func pickDistractors(for entry: ContentFile.Vocabulary, index: Int, from all: [ContentFile.Vocabulary]) -> [ContentFile.Vocabulary] {
        let tiers: [(ContentFile.Vocabulary) -> Bool] = [
            { $0.pos == entry.pos && $0.level == entry.level },
            { $0.pos == entry.pos },
            { _ in true },
        ]
        var chosen: [ContentFile.Vocabulary] = []
        var usedHangul: Set<String> = [entry.hangul]
        var usedMeaning: Set<String> = [entry.meaning.en.lowercased()]
        for tier in tiers where chosen.count < optionCount - 1 {
            let candidates = all.enumerated().filter { $0.offset != index && tier($0.element) }.map(\.element)
            let order = shuffledOrder(seed: hash(entry.id + "#d\(chosen.count)"), count: candidates.count)
            for position in order where chosen.count < optionCount - 1 {
                let candidate = candidates[position]
                guard usedHangul.insert(candidate.hangul).inserted, usedMeaning.insert(candidate.meaning.en.lowercased()).inserted else { continue }
                chosen.append(candidate)
            }
        }
        return chosen
    }

    /// FNV-1a over UTF-8. Stable across platforms, unlike `String.hashValue`.
    static func hash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    /// Fisher–Yates with a small xorshift generator seeded from `seed`.
    static func shuffledOrder(seed: UInt64, count: Int) -> [Int] {
        var order = Array(0..<count)
        var state = seed == 0 ? 0x9e3779b97f4a7c15 : seed
        func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
        var i = count - 1
        while i > 0 {
            let j = Int(next() % UInt64(i + 1))
            order.swapAt(i, j)
            i -= 1
        }
        return order
    }
}
