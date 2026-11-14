@testable import Assistant
import Domain
import XCTest

/// Claude writing review (ADR-012): structured request, decoded and clamped feedback.
final class ClaudeWritingReviewTests: XCTestCase {
    private let task = WritingTask(
        id: WritingTaskID("w.53.001"), type: .describeData, level: .level4,
        prompt: "다음을 참고하여 '여가 활동'에 대한 내용을 200~300자의 글로 쓰십시오.", material: "1위 운동 42%",
        lengthRange: 200...300, modelAnswer: "모범 답안", tips: Gloss(english: "tip", khmer: "គន្លឹះ")
    )

    func testReviewSendsSchemaAndClampsScores() async throws {
        let graded = #"{"estimated_score":45,"criteria":[{"name":"Language use","score":20,"max_score":16,"comment":"좋다"}],"corrections":[{"original":"했어요","suggestion":"했다","reason":"Use 한다체."}],"summary":"Good."}"#
        let envelope: [String: Any] = ["content": [["type": "text", "text": graded]], "stop_reason": "end_turn"]
        let reply = String(decoding: try JSONSerialization.data(withJSONObject: envelope), as: UTF8.self)
        let stub = StubTransport(responses: [.ok(reply)])
        let feedback = try await ClaudeAssistantProvider(apiKey: "k", transport: stub)
            .reviewWriting(WritingReviewRequest(task: task, answer: "여가 활동을 조사했어요.", language: .english))

        XCTAssertEqual(feedback.estimatedScore, 30, "clamped to the task's 30 points")
        XCTAssertEqual(feedback.maxScore, 30)
        XCTAssertEqual(feedback.criteria.first?.score, 16, "criterion clamped to its maximum")
        XCTAssertEqual(feedback.corrections.first?.suggestion, "했다")
        XCTAssertEqual(feedback.providerName, "Claude")

        let requests = await stub.requests
        let body = try XCTUnwrap(requests.first?.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let output = try XCTUnwrap(json["output_config"] as? [String: Any])
        XCTAssertEqual((output["format"] as? [String: Any])?["type"] as? String, "json_schema")
        let user = try XCTUnwrap((json["messages"] as? [[String: Any]])?.first?["content"] as? String)
        XCTAssertTrue(user.contains("200-300 characters"))
        XCTAssertTrue(user.contains("여가 활동을 조사했어요."))
    }

    func testUndecodableReviewIsInvalidResponse() async {
        let stub = StubTransport(responses: [.ok(#"{"content":[{"type":"text","text":"not json"}],"stop_reason":"end_turn"}"#)])
        do {
            _ = try await ClaudeAssistantProvider(apiKey: "k", transport: stub)
                .reviewWriting(WritingReviewRequest(task: task, answer: "답", language: .english))
            XCTFail("expected an error")
        } catch let error as AssistantError {
            guard case .invalidResponse = error else { return XCTFail("got \(error)") }
        } catch {
            XCTFail("got \(error)")
        }
    }
}
