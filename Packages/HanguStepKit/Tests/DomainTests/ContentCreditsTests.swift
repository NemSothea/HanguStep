import Domain
import XCTest

/// Third-party (CC BY-SA) material must be attributed in the app: one credit line
/// per distinct imported source, curated content never listed.
final class ContentCreditsTests: XCTestCase {
    private func word(_ n: Int, source: ContentSource) -> VocabularyItem {
        VocabularyItem(
            id: VocabularyID("vocab.t.\(n)"), hangul: "단어\(n)", romanization: "daneo\(n)",
            partOfSpeech: .noun, level: .level3, category: "test",
            meaning: Gloss(english: "word \(n)", khmer: "ពាក្យ \(n)"),
            source: source, contentVersion: 1
        )
    }

    func testImportedCreditsListsEachImportedSourceOnceAndSkipsCurated() {
        let curated = ContentSource(origin: .curated, name: "HanguStep", license: "CC BY 4.0")
        let wiki1 = ContentSource(origin: .imported, name: "Wiktionary", license: "CC BY-SA 4.0", url: "https://en.wiktionary.org/wiki/경제")
        let wiki2 = ContentSource(origin: .imported, name: "Wiktionary", license: "CC BY-SA 4.0", url: "https://en.wiktionary.org/wiki/사회")
        let package = ContentPackage(version: 1, vocabulary: [word(1, source: curated), word(2, source: wiki1), word(3, source: wiki2)], grammar: [], questions: [])

        XCTAssertEqual(package.importedCredits, ["Wiktionary · CC BY-SA 4.0"])
    }

    func testNoImportedContentMeansNoCredits() {
        let curated = ContentSource(origin: .curated, name: "HanguStep", license: "CC BY 4.0")
        let package = ContentPackage(version: 1, vocabulary: [word(1, source: curated)], grammar: [], questions: [])

        XCTAssertTrue(package.importedCredits.isEmpty)
    }
}
