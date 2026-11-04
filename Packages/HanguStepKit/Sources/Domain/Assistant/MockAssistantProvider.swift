import Foundation

/// Offline provider built from the content itself. Deterministic so tests and
/// UI tests can rely on it, and useful on its own: every explanation and
/// practice question comes from curated examples, never invented text.
public struct MockAssistantProvider: AssistantProvider {
    public let name = "Built-in assistant"

    public init() {}

    public func explain(_ request: ExplanationRequest) async throws -> AssistantExplanation {
        let question = request.question
        var lines: [String] = []
        switch (request.language, request.isCorrect) {
        case (.english, true):
            lines.append("Correct. \(question.explanation.english)")
        case (.english, false):
            lines.append("You chose \"\(request.selectedText)\". The answer is \"\(request.correctText)\".")
            lines.append(question.explanation.english)
        case (.khmer, true):
            lines.append("ត្រឹមត្រូវ។ \(question.explanation.khmer)")
        case (.khmer, false):
            lines.append("អ្នកបានជ្រើស \"\(request.selectedText)\"។ ចម្លើយត្រឹមត្រូវគឺ \"\(request.correctText)\"។")
            lines.append(question.explanation.khmer)
        }
        if let item = request.vocabulary {
            let meaning = item.meaning.text(in: request.language)
            lines.append(request.language == .english
                ? "\(item.hangul) (\(item.romanization)) means \"\(meaning)\"."
                : "\(item.hangul) (\(item.romanization)) មានន័យថា \"\(meaning)\"។")
            if let example = item.examples.first {
                lines.append("\(example.korean) — \(example.translation.text(in: request.language))")
            }
        }
        if let pattern = request.grammar {
            lines.append("\(pattern.pattern): \(pattern.explanation.text(in: request.language))")
            if let formation = pattern.formation {
                lines.append(formation.text(in: request.language))
            }
            if let example = pattern.examples.first {
                lines.append("\(example.korean) — \(example.translation.text(in: request.language))")
            }
        }
        return AssistantExplanation(text: lines.joined(separator: "\n\n"), language: request.language, providerName: name)
    }

    public func generate(_ request: PracticeRequest) async throws -> [DraftQuestion] {
        let drafts: [DraftQuestion]
        switch request.subject {
        case let .vocabulary(item, distractors):
            drafts = vocabularyDrafts(for: item, distractors: distractors)
        case let .grammar(pattern, others):
            drafts = grammarDrafts(for: pattern, others: others)
        }
        let existing = Set(request.existingPrompts)
        return Array(drafts.filter { !existing.contains($0.prompt) }.prefix(request.count))
    }

    // MARK: Vocabulary

    private func vocabularyDrafts(for item: VocabularyItem, distractors: [VocabularyItem]) -> [DraftQuestion] {
        var drafts: [DraftQuestion] = []
        let pool = distractors.filter { $0.id != item.id && $0.hangul != item.hangul && $0.meaning.english != item.meaning.english }
        let wordPool = Array(pool.prefix(3))

        // Cloze from each example sentence that contains the word.
        for example in item.examples where example.korean.contains(item.hangul) && wordPool.count == 3 {
            let prompt = example.korean.replacingOccurrences(of: item.hangul, with: "______")
            let options = order([item.hangul] + wordPool.map(\.hangul), seed: prompt)
            drafts.append(DraftQuestion(
                kind: .sentenceCompletion, prompt: prompt,
                options: options.texts, answer: options.answer,
                explanation: Gloss(
                    english: "\(example.korean) — \(example.translation.english). \(item.hangul) means \"\(item.meaning.english)\".",
                    khmer: "\(example.korean) — \(example.translation.khmer)។ \(item.hangul) មានន័យថា \"\(item.meaning.khmer)\"។"
                )
            ))
        }
        if wordPool.count == 3 {
            let meaningOptions = order(([item] + wordPool).map { "\($0.meaning.english) / \($0.meaning.khmer)" }, seed: item.id.rawValue + "#m")
            drafts.append(DraftQuestion(
                kind: .vocabularyMeaning, prompt: "'\(item.hangul)'의 의미는 무엇입니까?",
                options: meaningOptions.texts, answer: meaningOptions.answer,
                explanation: Gloss(english: "\(item.hangul) (\(item.romanization)) means \"\(item.meaning.english)\".", khmer: "\(item.hangul) (\(item.romanization)) មានន័យថា \"\(item.meaning.khmer)\"។")
            ))
            let wordOptions = order(([item] + wordPool).map(\.hangul), seed: item.id.rawValue + "#w")
            drafts.append(DraftQuestion(
                kind: .meaningToWord, prompt: "Which word means \"\(item.meaning.english)\" (\(item.meaning.khmer))?",
                options: wordOptions.texts, answer: wordOptions.answer,
                explanation: Gloss(english: "\"\(item.meaning.english)\" is \(item.hangul) (\(item.romanization)).", khmer: "\"\(item.meaning.khmer)\" គឺ \(item.hangul) (\(item.romanization))។")
            ))
        }
        return drafts
    }

    // MARK: Grammar

    private func grammarDrafts(for pattern: GrammarPattern, others: [GrammarPattern]) -> [DraftQuestion] {
        let foreign = others.filter { $0.id != pattern.id }.flatMap { other in other.examples.map { ($0, other) } }
        guard foreign.count >= 3 else { return [] }
        var drafts: [DraftQuestion] = []
        for (index, example) in pattern.examples.enumerated() {
            let picks = Array(rotate(foreign, by: index).prefix(3))
            let options = order([example.korean] + picks.map(\.0.korean), seed: pattern.id.rawValue + "#\(index)")
            drafts.append(DraftQuestion(
                kind: .grammarFillIn,
                prompt: "다음 중 '\(pattern.pattern)'을/를 사용한 문장은 무엇입니까?",
                options: options.texts, answer: options.answer,
                explanation: Gloss(
                    english: "\(example.korean) — \(example.translation.english). \(pattern.pattern): \(pattern.explanation.english)",
                    khmer: "\(example.korean) — \(example.translation.khmer)។ \(pattern.pattern): \(pattern.explanation.khmer)"
                )
            ))
        }
        return drafts
    }

    // MARK: Helpers

    private func rotate<T>(_ array: [T], by offset: Int) -> [T] {
        guard !array.isEmpty else { return array }
        let shift = offset % array.count
        return Array(array[shift...] + array[..<shift])
    }

    /// Places the first (correct) text at a position derived from `seed`.
    private func order(_ texts: [String], seed: String) -> (texts: [String], answer: Int) {
        guard let correct = texts.first else { return ([], 0) }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        let position = Int(hash % UInt64(texts.count))
        var rest = Array(texts.dropFirst())
        rest.insert(correct, at: position)
        return (rest, position)
    }
}
