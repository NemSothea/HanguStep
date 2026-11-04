@testable import Assistant
import Domain
import Persistence
import XCTest

/// The Claude provider against a stubbed transport: request shape, response
/// parsing and error mapping. No network, no key in the bundle.
final class ClaudeAssistantProviderTests: XCTestCase {
    private let question = SampleContent.questions[0]

    private func provider(_ stub: StubTransport) -> ClaudeAssistantProvider {
        ClaudeAssistantProvider(apiKey: "sk-test-key", transport: stub)
    }

    private func explanationRequest() -> ExplanationRequest {
        ExplanationRequest(question: question, selectedOptionID: OptionID("o2"), language: .english, vocabulary: SampleContent.vocabulary[0])
    }

    func testExplainSendsMessagesRequestWithKeyHeadersAndLowEffort() async throws {
        let stub = StubTransport(responses: [.ok(#"{"content":[{"type":"text","text":"  학교 means school.  "}],"stop_reason":"end_turn"}"#)])
        let explanation = try await provider(stub).explain(explanationRequest())
        XCTAssertEqual(explanation.text, "학교 means school.")
        XCTAssertEqual(explanation.providerName, "Claude")

        let requests = await stub.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url, ClaudeAssistantProvider.endpoint)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2026-10-21")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "server-side-fallback-2026-07-01")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "claude-opus-5-5")
        XCTAssertEqual(body["fallbacks"] as? String, "default")
        XCTAssertEqual((body["output_config"] as? [String: Any])?["effort"] as? String, "low")
        XCTAssertNil((body["output_config"] as? [String: Any])?["format"])
        XCTAssertNil(body["thinking"], "adaptive thinking is the model default; never send budget_tokens")
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 1)
        let content = try XCTUnwrap(messages[0]["content"] as? String)
        XCTAssertTrue(content.contains("Learner chose: friend / មិត្តភក្តិ (incorrect)"))
        XCTAssertTrue(content.contains("Word: 학교 (hakgyo)"))
        XCTAssertFalse(content.contains("sk-test-key"))
    }

    func testGenerateUsesStructuredOutputAndDecodesDrafts() async throws {
        let reply = """
        {"content":[{"type":"text","text":"{\\"questions\\":[{\\"kind\\":\\"sentenceCompletion\\",\\"prompt\\":\\"저는 ______에 가요.\\",\\"passage\\":null,\\"options\\":[\\"학교\\",\\"물\\",\\"책\\",\\"친구\\"],\\"answer\\":0,\\"explanation_en\\":\\"school\\",\\"explanation_km\\":\\"សាលារៀន\\"}]}"}],"stop_reason":"end_turn"}
        """
        let stub = StubTransport(responses: [.ok(reply)])
        let request = PracticeRequest(subject: .vocabulary(SampleContent.vocabulary[0], distractors: Array(SampleContent.vocabulary.dropFirst())), count: 2, existingPrompts: ["old prompt"])
        let drafts = try await provider(stub).generate(request)
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].kind, .sentenceCompletion)
        XCTAssertEqual(drafts[0].options, ["학교", "물", "책", "친구"])
        XCTAssertEqual(drafts[0].explanation, Gloss(english: "school", khmer: "សាលារៀន"))
        XCTAssertNil(drafts[0].passage)

        let sentRequests = await stub.requests
        let sent = try XCTUnwrap(sentRequests.first)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(sent.httpBody)) as? [String: Any])
        let format = try XCTUnwrap((body["output_config"] as? [String: Any])?["format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        let schema = try XCTUnwrap(format["schema"] as? [String: Any])
        XCTAssertEqual(schema["additionalProperties"] as? Bool, false)
        XCTAssertEqual((body["output_config"] as? [String: Any])?["effort"] as? String, "medium")
        let content = try XCTUnwrap((body["messages"] as? [[String: Any]])?.first?["content"] as? String)
        XCTAssertTrue(content.contains("Write 2 questions."))
        XCTAssertTrue(content.contains("- old prompt"))
    }

    func testErrorMapping() async throws {
        let cases: [(StubTransport.Response, AssistantError)] = [
            (.status(401, #"{"type":"error","error":{"type":"authentication_error","message":"bad key"}}"#), .unauthorized),
            (.status(429, "{}"), .rateLimited),
            (.status(529, "{}"), .unavailable("server error 529")),
            (.status(400, #"{"type":"error","error":{"type":"invalid_request_error","message":"messages: bad"}}"#), .invalidResponse("messages: bad")),
            (.ok(#"{"content":[],"stop_reason":"refusal"}"#), .refused),
            (.ok(#"{"content":[{"type":"text","text":"partial"}],"stop_reason":"max_tokens"}"#), .invalidResponse("reply was cut off")),
            (.ok("not json"), .invalidResponse("unreadable reply")),
            (.ok(#"{"content":[{"type":"text","text":"   "}],"stop_reason":"end_turn"}"#), .invalidResponse("empty reply")),
            (.failure(URLError(.notConnectedToInternet)), .unavailable(URLError(.notConnectedToInternet).localizedDescription)),
        ]
        for (response, expected) in cases {
            do {
                _ = try await provider(StubTransport(responses: [response])).explain(explanationRequest())
                XCTFail("expected \(expected)")
            } catch let error as AssistantError {
                XCTAssertEqual(error, expected)
            }
        }
    }

    func testUndecodableDraftJSONIsReported() async {
        let stub = StubTransport(responses: [.ok(#"{"content":[{"type":"text","text":"{\"questions\":[{\"kind\":1}]}"}],"stop_reason":"end_turn"}"#)])
        do {
            _ = try await provider(stub).generate(PracticeRequest(subject: .grammar(SampleContent.grammar[0], others: []), count: 1))
            XCTFail("expected invalidResponse")
        } catch let error as AssistantError {
            guard case .invalidResponse = error else { return XCTFail("\(error)") }
        } catch {
            XCTFail("\(error)")
        }
    }
}

actor StubTransport: HTTPTransport {
    enum Response {
        case ok(String)
        case status(Int, String)
        case failure(Error)
    }

    private var queue: [Response]
    private(set) var requests: [URLRequest] = []

    init(responses: [Response]) { queue = responses }

    func send(_ request: URLRequest) async throws -> (data: Data, status: Int) {
        requests.append(request)
        guard !queue.isEmpty else { throw URLError(.badServerResponse) }
        switch queue.removeFirst() {
        case let .ok(body): return (Data(body.utf8), 200)
        case let .status(code, body): return (Data(body.utf8), code)
        case let .failure(error): throw error
        }
    }
}
