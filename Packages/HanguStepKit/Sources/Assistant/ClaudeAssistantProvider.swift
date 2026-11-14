import Domain
import Foundation

/// Claude through the Anthropic Messages API (raw HTTP; there is no official
/// Swift SDK). The key is supplied per call from the Keychain and never stored
/// here or in the bundle (PRD FR-A3, NFR-7). Explanations are plain text at low
/// effort; practice questions use structured outputs so the reply always decodes.
public struct ClaudeAssistantProvider: AssistantProvider {
    public static let defaultModel = "claude-opus-5-5"
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2026-10-21"
    /// Server-side refusal fallback: a declined request is re-run on Anthropic's
    /// recommended fallback model inside the same call.
    static let betaHeader = "server-side-fallback-2026-07-01"

    public let name = "Claude"
    private let apiKey: String
    private let model: String
    private let transport: any HTTPTransport

    public init(apiKey: String, model: String = ClaudeAssistantProvider.defaultModel, transport: any HTTPTransport = URLSessionTransport()) {
        self.apiKey = apiKey
        self.model = model
        self.transport = transport
    }

    // MARK: AssistantProvider

    public func explain(_ request: ExplanationRequest) async throws -> AssistantExplanation {
        let body = MessagesRequest(
            model: model,
            maxTokens: 1024,
            system: Prompts.explainSystem,
            messages: [.init(role: "user", content: Prompts.explainUser(request))],
            outputConfig: .init(effort: "low", format: nil),
            fallbacks: "default"
        )
        let reply = try await send(body)
        let text = reply.content.first { $0.type == "text" }?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw AssistantError.invalidResponse("empty reply") }
        return AssistantExplanation(text: text, language: request.language, providerName: name)
    }

    public func generate(_ request: PracticeRequest) async throws -> [DraftQuestion] {
        let body = MessagesRequest(
            model: model,
            maxTokens: 8192,
            system: Prompts.generateSystem,
            messages: [.init(role: "user", content: Prompts.generateUser(request))],
            outputConfig: .init(effort: "medium", format: .init(type: "json_schema", schema: Prompts.draftSchema)),
            fallbacks: "default"
        )
        let reply = try await send(body)
        guard let text = reply.content.first(where: { $0.type == "text" })?.text, let data = text.data(using: .utf8) else {
            throw AssistantError.invalidResponse("no JSON text block")
        }
        do {
            return try JSONDecoder().decode(DraftEnvelope.self, from: data).questions.map(\.draft)
        } catch {
            throw AssistantError.invalidResponse("could not decode questions: \(error)")
        }
    }

    public func reviewWriting(_ request: WritingReviewRequest) async throws -> WritingFeedback {
        let body = MessagesRequest(
            model: model,
            maxTokens: 4096,
            system: Prompts.writingSystem,
            messages: [.init(role: "user", content: Prompts.writingUser(request))],
            outputConfig: .init(effort: "medium", format: .init(type: "json_schema", schema: Prompts.writingSchema)),
            fallbacks: "default"
        )
        let reply = try await send(body)
        guard let text = reply.content.first(where: { $0.type == "text" })?.text, let data = text.data(using: .utf8) else {
            throw AssistantError.invalidResponse("no JSON text block")
        }
        let graded: WritingEnvelope
        do { graded = try JSONDecoder().decode(WritingEnvelope.self, from: data) } catch {
            throw AssistantError.invalidResponse("could not decode feedback: \(error)")
        }
        return graded.feedback(maxScore: request.task.type.maxScore, language: request.language, providerName: name)
    }

    // MARK: Transport

    private func send(_ body: MessagesRequest) async throws -> MessagesResponse {
        var urlRequest = URLRequest(url: Self.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue(Self.betaHeader, forHTTPHeaderField: "anthropic-beta")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, status): (Data, Int)
        do {
            (data, status) = try await transport.send(urlRequest)
        } catch {
            throw AssistantError.unavailable(error.localizedDescription)
        }
        switch status {
        case 200..<300:
            break
        case 401, 403:
            throw AssistantError.unauthorized
        case 429:
            throw AssistantError.rateLimited
        case 500...:
            throw AssistantError.unavailable("server error \(status)")
        default:
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.message ?? "HTTP \(status)"
            throw AssistantError.invalidResponse(message)
        }
        let reply: MessagesResponse
        do { reply = try JSONDecoder().decode(MessagesResponse.self, from: data) } catch {
            throw AssistantError.invalidResponse("unreadable reply")
        }
        if reply.stopReason == "refusal" { throw AssistantError.refused }
        if reply.stopReason == "max_tokens" { throw AssistantError.invalidResponse("reply was cut off") }
        return reply
    }

    // MARK: Wire types

    struct MessagesRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        struct OutputConfig: Encodable {
            struct Format: Encodable { let type: String; let schema: JSONValue }
            let effort: String
            let format: Format?
        }
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [Message]
        let outputConfig: OutputConfig
        let fallbacks: String

        enum CodingKeys: String, CodingKey {
            case model, system, messages, fallbacks
            case maxTokens = "max_tokens"
            case outputConfig = "output_config"
        }
    }

    struct MessagesResponse: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
        let stopReason: String?
        enum CodingKeys: String, CodingKey { case content; case stopReason = "stop_reason" }
    }

    struct ErrorEnvelope: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }

    struct DraftEnvelope: Decodable {
        struct Item: Decodable {
            let kind: String
            let prompt: String
            let passage: String?
            let options: [String]
            let answer: Int
            let explanationEnglish: String
            let explanationKhmer: String
            enum CodingKeys: String, CodingKey {
                case kind, prompt, passage, options, answer
                case explanationEnglish = "explanation_en"
                case explanationKhmer = "explanation_km"
            }
            var draft: DraftQuestion {
                DraftQuestion(
                    kind: QuestionKind(rawValue: kind) ?? .sentenceCompletion,
                    prompt: prompt, passage: passage, options: options, answer: answer,
                    explanation: Gloss(english: explanationEnglish, khmer: explanationKhmer)
                )
            }
        }
        let questions: [Item]
    }

    struct WritingEnvelope: Decodable {
        struct Criterion: Decodable {
            let name: String
            let score: Int
            let maxScore: Int
            let comment: String
            enum CodingKeys: String, CodingKey { case name, score, comment; case maxScore = "max_score" }
        }
        struct Correction: Decodable { let original: String; let suggestion: String; let reason: String }
        let estimatedScore: Int
        let criteria: [Criterion]
        let corrections: [Correction]
        let summary: String
        enum CodingKeys: String, CodingKey { case criteria, corrections, summary; case estimatedScore = "estimated_score" }

        /// Scores are clamped: a model's arithmetic is not trusted past the exam's limits.
        func feedback(maxScore: Int, language: GlossLanguage, providerName: String) -> WritingFeedback {
            WritingFeedback(
                providerName: providerName,
                estimatedScore: min(max(estimatedScore, 0), maxScore),
                maxScore: maxScore,
                criteria: criteria.map { .init(name: $0.name, score: min(max($0.score, 0), max($0.maxScore, 0)), maxScore: max($0.maxScore, 0), comment: $0.comment) },
                corrections: corrections.prefix(12).map { .init(original: $0.original, suggestion: $0.suggestion, reason: $0.reason) },
                summary: summary,
                language: language
            )
        }
    }
}

/// Minimal JSON tree for encoding the structured-output schema.
indirect enum JSONValue: Encodable {
    case string(String)
    case bool(Bool)
    case array([JSONValue])
    case object([(String, JSONValue)])

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .string(value):
            var container = encoder.singleValueContainer(); try container.encode(value)
        case let .bool(value):
            var container = encoder.singleValueContainer(); try container.encode(value)
        case let .array(values):
            var container = encoder.unkeyedContainer()
            for value in values { try container.encode(value) }
        case let .object(pairs):
            var container = encoder.container(keyedBy: Key.self)
            for (key, value) in pairs { try container.encode(value, forKey: Key(key)) }
        }
    }

    struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ string: String) { stringValue = string }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}

enum Prompts {
    static let explainSystem = """
    You are a Korean tutor inside a TOPIK study app for a Cambodian learner. Explain multiple-choice answers briefly and concretely: \
    why the correct option is right, why the learner's choice is wrong if it differs, and one memorable tip. \
    Write in the requested language (English or Khmer), keep Korean words in Hangul, and stay under 120 words. \
    Plain text only, no headings or lists.
    """

    static func explainUser(_ request: ExplanationRequest) -> String {
        var lines: [String] = []
        lines.append("Language: \(request.language == .english ? "English" : "Khmer")")
        if let passage = request.question.passage { lines.append("Passage: \(passage)") }
        lines.append("Question: \(request.question.prompt)")
        lines.append("Options: " + request.question.options.map(\.text).joined(separator: " | "))
        lines.append("Correct answer: \(request.correctText)")
        lines.append("Learner chose: \(request.selectedText) (\(request.isCorrect ? "correct" : "incorrect"))")
        lines.append("Curated explanation: \(request.question.explanation.text(in: request.language))")
        if let item = request.vocabulary {
            lines.append("Word: \(item.hangul) (\(item.romanization)), \(item.partOfSpeech.rawValue), means \(item.meaning.english) / \(item.meaning.khmer)")
            for example in item.examples.prefix(2) { lines.append("Example: \(example.korean) = \(example.translation.english)") }
        }
        if let pattern = request.grammar {
            lines.append("Grammar: \(pattern.pattern): \(pattern.explanation.english)")
            if let formation = pattern.formation { lines.append("Formation: \(formation.english)") }
            for example in pattern.examples.prefix(2) { lines.append("Example: \(example.korean) = \(example.translation.english)") }
        }
        return lines.joined(separator: "\n")
    }

    static let generateSystem = """
    You write multiple-choice practice questions for a Korean (TOPIK) study app used by a Cambodian learner. \
    Every question has 4 options, exactly one correct, all plausible, no duplicates, natural Korean at the given level. \
    Explanations must be given in both English and Khmer, under 40 words each, and keep Korean words in Hangul. \
    Use kinds: sentenceCompletion (a Korean sentence with ______ for the target word), vocabularyMeaning (prompt in Korean asking the meaning, options as "English / Khmer"), \
    meaningToWord (prompt in English giving the meaning, options are Korean words), grammarFillIn (a sentence with ______ for the grammar form), readingComprehension (short passage plus question). \
    Do not reuse any prompt listed as already existing. Return only the JSON requested.
    """

    static func generateUser(_ request: PracticeRequest) -> String {
        var lines: [String] = ["Write \(request.count) questions."]
        switch request.subject {
        case let .vocabulary(item, distractors):
            lines.append("Target word: \(item.hangul) (\(item.romanization)), \(item.partOfSpeech.rawValue), level \(item.level.rawValue), means \(item.meaning.english) / \(item.meaning.khmer)")
            for example in item.examples { lines.append("Example: \(example.korean) = \(example.translation.english) / \(example.translation.khmer)") }
            lines.append("Words you may use as distractors: " + distractors.map { "\($0.hangul) (\($0.meaning.english) / \($0.meaning.khmer))" }.joined(separator: ", "))
            lines.append("Mix kinds: sentenceCompletion, vocabularyMeaning, meaningToWord.")
        case let .grammar(pattern, others):
            lines.append("Target grammar: \(pattern.pattern), level \(pattern.level.rawValue): \(pattern.explanation.english)")
            if let formation = pattern.formation { lines.append("Formation: \(formation.english)") }
            for example in pattern.examples { lines.append("Example: \(example.korean) = \(example.translation.english) / \(example.translation.khmer)") }
            lines.append("Other patterns at this level for contrast: " + others.map(\.pattern).joined(separator: ", "))
            lines.append("Mix kinds: grammarFillIn, sentenceCompletion, one readingComprehension.")
        }
        if !request.existingPrompts.isEmpty {
            lines.append("Already existing prompts (do not reuse):")
            lines += request.existingPrompts.map { "- \($0)" }
        }
        return lines.joined(separator: "\n")
    }

    static let writingSystem = """
    You are an experienced TOPIK II writing (쓰기) grader helping a Cambodian learner preparing for level 3-4. \
    Grade the answer the way official raters do and be honest: do not inflate scores. \
    Criteria: questions 51-52 (10 points): content fits the blank and context (5), grammar and register match the text (5). \
    Question 53 (30 points): content and task (7: covers the given data accurately), organisation (7), language use (16: vocabulary, grammar, 한다체, spelling). \
    Question 54 (50 points): content and task (12: answers every guiding question, clear argument), organisation (12: introduction, body, conclusion, connectives), language use (26). \
    Answers outside the required length lose points; a polite -요/-습니다 style in 53-54 loses language points. \
    Corrections quote the learner's exact Korean in "original" and give the fixed Korean in "suggestion"; at most 12, most important first. \
    Write comments, reasons and the summary in the requested language (English or Khmer), keep Korean in Hangul, summary under 80 words. \
    Return only the JSON requested.
    """

    static func writingUser(_ request: WritingReviewRequest) -> String {
        let task = request.task
        var lines = ["Language for comments: \(request.language == .english ? "English" : "Khmer")"]
        lines.append("Task type: \(task.type.title), worth \(task.type.maxScore) points")
        lines.append("Instruction: \(task.prompt)")
        lines.append("Material:\n\(task.material)")
        if let range = task.lengthRange { lines.append("Required length: \(range.lowerBound)-\(range.upperBound) characters including spaces") }
        lines.append("Learner's answer (\(WritingText.characterCount(request.answer)) characters):\n\(request.answer)")
        lines.append("Reference model answer (one good answer, others are possible):\n\(task.modelAnswer)")
        return lines.joined(separator: "\n")
    }

    static let writingSchema: JSONValue = .object([
        ("type", .string("object")),
        ("properties", .object([
            ("estimated_score", .object([("type", .string("integer"))])),
            ("criteria", .object([
                ("type", .string("array")),
                ("items", .object([
                    ("type", .string("object")),
                    ("properties", .object([
                        ("name", .object([("type", .string("string"))])),
                        ("score", .object([("type", .string("integer"))])),
                        ("max_score", .object([("type", .string("integer"))])),
                        ("comment", .object([("type", .string("string"))])),
                    ])),
                    ("required", .array(["name", "score", "max_score", "comment"].map { .string($0) })),
                    ("additionalProperties", .bool(false)),
                ])),
            ])),
            ("corrections", .object([
                ("type", .string("array")),
                ("items", .object([
                    ("type", .string("object")),
                    ("properties", .object([
                        ("original", .object([("type", .string("string"))])),
                        ("suggestion", .object([("type", .string("string"))])),
                        ("reason", .object([("type", .string("string"))])),
                    ])),
                    ("required", .array(["original", "suggestion", "reason"].map { .string($0) })),
                    ("additionalProperties", .bool(false)),
                ])),
            ])),
            ("summary", .object([("type", .string("string"))])),
        ])),
        ("required", .array(["estimated_score", "criteria", "corrections", "summary"].map { .string($0) })),
        ("additionalProperties", .bool(false)),
    ])

    static let draftSchema: JSONValue = .object([
        ("type", .string("object")),
        ("properties", .object([
            ("questions", .object([
                ("type", .string("array")),
                ("items", .object([
                    ("type", .string("object")),
                    ("properties", .object([
                        ("kind", .object([("type", .string("string")), ("enum", .array(QuestionKind.allCases.filter { $0 != .listening }.map { .string($0.rawValue) }))])),
                        ("prompt", .object([("type", .string("string"))])),
                        ("passage", .object([("type", .array([.string("string"), .string("null")]))])),
                        ("options", .object([("type", .string("array")), ("items", .object([("type", .string("string"))]))])),
                        ("answer", .object([("type", .string("integer"))])),
                        ("explanation_en", .object([("type", .string("string"))])),
                        ("explanation_km", .object([("type", .string("string"))])),
                    ])),
                    ("required", .array(["kind", "prompt", "passage", "options", "answer", "explanation_en", "explanation_km"].map { .string($0) })),
                    ("additionalProperties", .bool(false)),
                ])),
            ])),
        ])),
        ("required", .array([.string("questions")])),
        ("additionalProperties", .bool(false)),
    ])
}
