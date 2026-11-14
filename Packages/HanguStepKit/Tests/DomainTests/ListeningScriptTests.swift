@testable import Domain
import XCTest

final class ListeningScriptTests: XCTestCase {
    func testSplitsSpeakersNarrationAndBlankLines() {
        let script = ListeningScript("남자: 안녕하세요.\n\n여자：네, 반갑습니다.\n  다음 안내 방송입니다.  \n남자:")
        XCTAssertEqual(script.lines, [
            .init(speaker: .man, text: "안녕하세요."),
            .init(speaker: .woman, text: "네, 반갑습니다."),
            .init(speaker: .narrator, text: "다음 안내 방송입니다."),
        ])
    }

    func testListeningQuestionNeedsAScript() {
        func question(passage: String?) -> Question {
            Question(
                id: QuestionID("q.ls.1"), kind: .listening, level: .level3, prompt: "다음을 듣고 고르십시오.", passage: passage,
                options: [QuestionOption(id: OptionID("a"), text: "가"), QuestionOption(id: OptionID("b"), text: "나")],
                correctOptionID: OptionID("a"), explanation: Gloss(english: "e", khmer: "ខ"),
                source: ContentSource(origin: .curated, name: "t", license: "CC BY 4.0"), contentVersion: 1
            )
        }
        XCTAssertEqual(question(passage: nil).validate(), [.missingListeningScript])
        XCTAssertEqual(question(passage: " \n 남자: ").validate(), [.missingListeningScript])
        XCTAssertTrue(question(passage: "여자: 어서 오세요.").isValid)
    }

    func testPoolKinds() {
        XCTAssertEqual(QuizPool.listening.kinds, [.listening])
        XCTAssertFalse(QuizPool.mixed.kinds.contains(.listening))
        XCTAssertTrue(QuizPool.mixed.kinds.contains(.readingComprehension))
    }
}
