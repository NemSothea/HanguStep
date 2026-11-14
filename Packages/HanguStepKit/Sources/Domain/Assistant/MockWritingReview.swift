import Foundation

/// Offline writing checks for the built-in assistant. It cannot judge content,
/// so it gives no score: only length, both blanks answered, formal style and paragraphs.
extension MockAssistantProvider {
    public func reviewWriting(_ request: WritingReviewRequest) async throws -> WritingFeedback {
        let task = request.task
        let answer = request.answer
        let khmer = request.language == .khmer
        var checks: [WritingFeedback.Criterion] = []
        func check(_ name: String, _ passed: Bool, _ english: String, _ km: String) {
            checks.append(.init(name: name, score: passed ? 1 : 0, maxScore: 1, comment: khmer ? km : english))
        }

        let count = WritingText.characterCount(answer)
        if let range = task.lengthRange {
            check("Length", range.contains(count),
                  "\(count) characters; the task asks for \(range.lowerBound)-\(range.upperBound). Answers outside the range lose points.",
                  "\(count) តួអក្សរ; លំហាត់តម្រូវ \(range.lowerBound)-\(range.upperBound)។ ចម្លើយក្រៅចន្លោះនេះនឹងបាត់ពិន្ទុ។")
        }
        if task.type == .shortAnswer {
            let both = Self.hasLine(answer, starting: "㉠") && Self.hasLine(answer, starting: "㉡")
            check("Both blanks", both,
                  "Write each answer on its own line starting with ㉠ and ㉡.",
                  "សរសេរចម្លើយនីមួយៗលើបន្ទាត់ផ្ទាល់ខ្លួន ចាប់ផ្តើមដោយ ㉠ និង ㉡។")
        } else {
            let polite = Self.politeEndings(answer)
            check("Formal style (한다체)", polite == 0,
                  polite == 0 ? "No -요 or -습니다 endings: good." : "\(polite) sentence(s) end in -요 or -습니다. Questions 53-54 expect 한다체 (-다).",
                  polite == 0 ? "គ្មានចុងប្រយោគ -요 ឬ -습니다: ល្អ។" : "\(polite) ប្រយោគបញ្ចប់ដោយ -요 ឬ -습니다។ សំណួរ 53-54 តម្រូវ 한다체 (-다)។")
        }
        if task.type == .essay {
            let paragraphs = answer.split(whereSeparator: \.isNewline).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
            check("Paragraphs", paragraphs >= 3,
                  "\(paragraphs) paragraph(s). Use at least three: introduction, body, conclusion.",
                  "\(paragraphs) កថាខណ្ឌ។ ប្រើយ៉ាងហោចណាស់បី: សេចក្តីផ្តើម តួ សេចក្តីសន្និដ្ឋាន។")
        }
        let passed = checks.filter { $0.score == 1 }.count
        let summary = khmer
            ? "ការពិនិត្យក្រៅបណ្តាញ: \(passed)/\(checks.count) ត្រឹមត្រូវ។ ប្រៀបធៀបជាមួយចម្លើយគំរូ។ បើកជំនួយការ Claude ដើម្បីទទួលពិន្ទុប៉ាន់ស្មាន។"
            : "Offline checks: \(passed) of \(checks.count) passed. Compare with the model answer. Turn on Claude in Settings for an estimated score."
        return WritingFeedback(providerName: name, estimatedScore: nil, maxScore: task.type.maxScore, criteria: checks, corrections: [], summary: summary, language: request.language)
    }

    static func hasLine(_ text: String, starting marker: String) -> Bool {
        text.split(whereSeparator: \.isNewline).contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix(marker) && trimmed.count > marker.count + 1
        }
    }

    /// Sentences ending in 해요체 or 합쇼체.
    static func politeEndings(_ text: String) -> Int {
        text.split(whereSeparator: { ".?!\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasSuffix("요") || $0.hasSuffix("니다") || $0.hasSuffix("니까") }
            .count
    }
}
