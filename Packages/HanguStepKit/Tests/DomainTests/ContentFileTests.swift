import Domain
import XCTest

/// Phase 7 JSON content format: decoding, merging of part files and validation (PRD FR-C1, AC-10).
final class ContentFileTests: XCTestCase {
    private let packageJSON = """
    {"formatVersion":1,"version":3,"source":{"origin":"curated","name":"test","license":"CC BY 4.0"},
     "vocabulary":[{"id":"vocab.0001","hangul":"학교","romanization":"hakgyo","pos":"noun","level":1,"category":"school",
       "meaning":{"en":"school","km":"សាលារៀន"},"examples":[{"ko":"학교에 가요.","en":"I go to school.","km":"ខ្ញុំទៅសាលារៀន។"}],"review":"pending"}],
     "grammar":[{"id":"grammar.0001","pattern":"-아/어요","level":1,"category":"ending","explanation":{"en":"Polite ending.","km":"ចុងប្រយោគគួរសម។"}}]}
    """
    private let partJSON = """
    {"questions":[{"id":"q.0001","kind":"vocabularyMeaning","level":1,"prompt":"'학교'?","options":["school","water","friend","book"],"answer":0,
      "explanation":{"en":"학교 is school.","km":"학교 គឺសាលារៀន។"},"vocabulary":"vocab.0001","grammar":"grammar.0001"}]}
    """

    private func data(_ json: String) -> Data { Data(json.utf8) }

    private func load(package: String? = nil, parts: [(String, Data)] = []) throws -> ContentFile.LoadResult {
        try ContentFile.load(package: data(package ?? packageJSON), parts: parts.map { (name: $0.0, data: $0.1) })
    }

    private func issues(_ body: () throws -> ContentFile.LoadResult, file: StaticString = #filePath, line: UInt = #line) -> [ContentPackageIssue] {
        do {
            _ = try body()
            XCTFail("expected validation failure", file: file, line: line)
            return []
        } catch ContentFile.Error.invalid(let issues) {
            return issues
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
            return []
        }
    }

    // MARK: Decoding

    func testPackageAndPartsMergeIntoDomainEntities() throws {
        let result = try load(parts: [("questions/a.json", data(partJSON))])
        let package = result.package
        XCTAssertEqual(package.version, 3)
        XCTAssertEqual(package.vocabulary.map(\.id.rawValue), ["vocab.0001"])
        XCTAssertEqual(package.grammar.map(\.id.rawValue), ["grammar.0001"])
        XCTAssertEqual(package.questions.map(\.id.rawValue), ["q.0001"])
        XCTAssertTrue(package.validate().isEmpty)

        let word = package.vocabulary[0]
        XCTAssertEqual(word.meaning, Gloss(english: "school", khmer: "សាលារៀន"))
        XCTAssertEqual(word.level, .level1)
        XCTAssertEqual(word.contentVersion, 3)
        XCTAssertEqual(word.source.name, "test", "package source applies when an item has none")
        XCTAssertEqual(word.examples.first?.korean, "학교에 가요.")

        let question = package.questions[0]
        XCTAssertEqual(question.options.map(\.id.rawValue), ["o1", "o2", "o3", "o4"])
        XCTAssertEqual(question.correctOptionID.rawValue, "o1")
        XCTAssertEqual(question.relatedVocabularyID?.rawValue, "vocab.0001")
        XCTAssertEqual(question.relatedGrammarID?.rawValue, "grammar.0001")
        XCTAssertEqual(result.pendingReview, 1)
        XCTAssertEqual(result.source.license, "CC BY 4.0")
    }

    func testOptionalListsDefaultToEmpty() throws {
        let minimal = """
        {"formatVersion":1,"version":1,"source":{"origin":"curated","name":"t","license":"l"}}
        """
        let result = try load(package: minimal)
        XCTAssertTrue(result.package.vocabulary.isEmpty)
        XCTAssertTrue(result.package.questions.isEmpty)
    }

    func testItemSourceOverridesPackageSource() throws {
        let part = """
        {"vocabulary":[{"id":"vocab.0002","hangul":"물","romanization":"mul","pos":"noun","level":1,"category":"food",
          "meaning":{"en":"water","km":"ទឹក"},"source":{"origin":"curated","name":"other","license":"MIT"}}]}
        """
        let result = try load(parts: [("vocabulary/b.json", data(part))])
        XCTAssertEqual(result.package.vocabulary.first { $0.id.rawValue == "vocab.0002" }?.source.name, "other")
    }

    func testPartsMergeInNameOrderRegardlessOfInputOrder() throws {
        let a = """
        {"vocabulary":[{"id":"vocab.a","hangul":"가","romanization":"ga","pos":"noun","level":1,"category":"c","meaning":{"en":"a","km":"ក"}}]}
        """
        let b = """
        {"vocabulary":[{"id":"vocab.b","hangul":"나","romanization":"na","pos":"noun","level":1,"category":"c","meaning":{"en":"b","km":"ខ"}}]}
        """
        let result = try load(parts: [("vocabulary/b.json", data(b)), ("vocabulary/a.json", data(a))])
        XCTAssertEqual(result.package.vocabulary.map(\.id.rawValue), ["vocab.0001", "vocab.a", "vocab.b"])
    }

    // MARK: Rejection

    func testUnsupportedFormatVersionIsRejected() {
        let future = packageJSON.replacingOccurrences(of: "\"formatVersion\":1", with: "\"formatVersion\":2")
        XCTAssertThrowsError(try load(package: future)) { error in
            guard case ContentFile.Error.unsupportedFormat(let found, let supported) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(found, 2)
            XCTAssertEqual(supported, ContentFile.supportedFormatVersion)
        }
    }

    func testMalformedPartNamesTheFile() {
        XCTAssertThrowsError(try load(parts: [("questions/broken.json", data("{not json"))])) { error in
            guard case ContentFile.Error.malformed(let file, _) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(file, "questions/broken.json")
        }
    }

    func testMissingKhmerIsRejected() {
        let part = partJSON.replacingOccurrences(of: "\"km\":\"학교 គឺសាលារៀន។\"", with: "\"km\":\"\"")
        let found = issues { try load(parts: [("questions/a.json", data(part))]) }
        XCTAssertEqual(found, [.invalidQuestion(id: "q.0001", issues: [.emptyExplanation(.khmer)])])
    }

    func testAnswerOutsideOptionsIsRejected() {
        let part = partJSON.replacingOccurrences(of: "\"answer\":0", with: "\"answer\":4")
        let found = issues { try load(parts: [("questions/a.json", data(part))]) }
        XCTAssertTrue(found.contains(.invalidField(kind: "question", id: "q.0001", field: "answer 4 is outside options")))
        XCTAssertTrue(found.contains(.invalidQuestion(id: "q.0001", issues: [.correctOptionMissing])))
    }

    func testDuplicateIDAcrossPartsIsRejected() {
        let duplicate = """
        {"vocabulary":[{"id":"vocab.0001","hangul":"학교","romanization":"hakgyo","pos":"noun","level":1,"category":"school","meaning":{"en":"school","km":"សាលារៀន"}}]}
        """
        let found = issues { try load(parts: [("vocabulary/dup.json", data(duplicate))]) }
        XCTAssertEqual(found, [.duplicateID(kind: "vocabulary", id: "vocab.0001")])
    }

    func testDanglingReferencesAreRejected() {
        let part = partJSON.replacingOccurrences(of: "\"vocabulary\":\"vocab.0001\"", with: "\"vocabulary\":\"vocab.9999\"")
        let found = issues { try load(parts: [("questions/a.json", data(part))]) }
        XCTAssertEqual(found, [.danglingReference(questionID: "q.0001", target: "vocab.9999")])

        let grammar = """
        {"grammar":[{"id":"grammar.0002","pattern":"-고","level":1,"category":"c","explanation":{"en":"and","km":"និង"},"related":["grammar.missing"]}]}
        """
        let grammarIssues = issues { try load(parts: [("grammar/b.json", data(grammar))]) }
        XCTAssertEqual(grammarIssues, [.danglingReference(questionID: "grammar.0002", target: "grammar.missing")])
    }

    func testLevelOutsideTOPIKRangeIsRejected() {
        let bad = packageJSON.replacingOccurrences(of: "\"level\":1,\"category\":\"school\"", with: "\"level\":7,\"category\":\"school\"")
        let found = issues { try load(package: bad) }
        XCTAssertEqual(found, [.invalidField(kind: "vocabulary", id: "vocab.0001", field: "level 7 must be 1...6")])
    }

    func testIncompleteExampleIsRejected() {
        let bad = packageJSON.replacingOccurrences(of: "\"km\":\"ខ្ញុំទៅសាលារៀន។\"", with: "\"km\":\"\"")
        let found = issues { try load(package: bad) }
        XCTAssertEqual(found, [.invalidField(kind: "vocabulary", id: "vocab.0001", field: "example needs ko, en and km")])
    }

    func testNonASCIIIdentifierIsRejected() {
        let bad = packageJSON.replacingOccurrences(of: "\"id\":\"vocab.0001\"", with: "\"id\":\"vocab/학교\"")
        let found = issues { try load(package: bad) }
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first, .invalidField(kind: "vocabulary", id: "vocab/학교", field: "id must be ASCII letters, digits, '.', '-' or '_'"))
    }

    func testEveryIssueIsReportedAtOnce() {
        let part = partJSON
            .replacingOccurrences(of: "\"answer\":0", with: "\"answer\":9")
            .replacingOccurrences(of: "\"vocabulary\":\"vocab.0001\"", with: "\"vocabulary\":\"vocab.9999\"")
        let found = issues { try load(parts: [("questions/a.json", data(part))]) }
        XCTAssertEqual(found.count, 3, "field, question and reference issues all surface in one pass: \(found)")
    }
}
