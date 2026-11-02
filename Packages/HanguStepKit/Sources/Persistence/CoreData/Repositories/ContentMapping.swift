import CoreData
import Domain
import Foundation

/// Managed object → domain struct. Called only inside `context.perform`.
enum ContentMapping {
    static func source(origin: String, name: String, license: String, url: String?) -> ContentSource {
        ContentSource(
            origin: ContentSource.Origin(rawValue: origin) ?? .curated,
            name: name,
            license: license,
            url: url
        )
    }

    static func examples(_ set: NSSet?) -> [ExampleSentence] {
        (set?.allObjects as? [CDExampleSentence] ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { ExampleSentence(korean: $0.korean, translation: Gloss(english: $0.english, khmer: $0.khmer)) }
    }

    static func vocabulary(_ row: CDVocabulary) -> VocabularyItem {
        VocabularyItem(
            id: VocabularyID(row.id),
            hangul: row.hangul,
            romanization: row.romanization,
            hanja: row.hanja,
            partOfSpeech: PartOfSpeech(rawValue: row.partOfSpeech) ?? .other,
            level: TOPIKLevel(rawValue: Int(row.level)) ?? .level1,
            category: row.category,
            meaning: Gloss(english: row.meaningEnglish, khmer: row.meaningKhmer),
            examples: examples(row.examples),
            source: source(origin: row.sourceOrigin, name: row.sourceName, license: row.sourceLicense, url: row.sourceURL),
            contentVersion: Int(row.contentVersion)
        )
    }

    static func grammar(_ row: CDGrammar) -> GrammarPattern {
        let formation: Gloss? = {
            guard let english = row.formationEnglish, let khmer = row.formationKhmer else { return nil }
            return Gloss(english: english, khmer: khmer)
        }()
        return GrammarPattern(
            id: GrammarID(row.id),
            pattern: row.pattern,
            level: TOPIKLevel(rawValue: Int(row.level)) ?? .level1,
            category: row.category,
            explanation: Gloss(english: row.explanationEnglish, khmer: row.explanationKhmer),
            formation: formation,
            examples: examples(row.examples),
            relatedPatternIDs: CoreDataSupport.decodeIDs(row.relatedPatternIDs).map { GrammarID($0) },
            source: source(origin: row.sourceOrigin, name: row.sourceName, license: row.sourceLicense, url: row.sourceURL),
            contentVersion: Int(row.contentVersion)
        )
    }

    static func question(_ row: CDQuestion) -> Question {
        let options = (row.options?.allObjects as? [CDQuestionOption] ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { QuestionOption(id: OptionID($0.id), text: $0.text) }
        return Question(
            id: QuestionID(row.id),
            kind: QuestionKind(rawValue: row.kind) ?? .vocabularyMeaning,
            level: TOPIKLevel(rawValue: Int(row.level)) ?? .level1,
            prompt: row.prompt,
            passage: row.passage,
            options: options,
            correctOptionID: OptionID(row.correctOptionID),
            explanation: Gloss(english: row.explanationEnglish, khmer: row.explanationKhmer),
            relatedVocabularyID: row.relatedVocabularyID.map { VocabularyID($0) },
            relatedGrammarID: row.relatedGrammarID.map { GrammarID($0) },
            source: source(origin: row.sourceOrigin, name: row.sourceName, license: row.sourceLicense, url: row.sourceURL),
            contentVersion: Int(row.contentVersion)
        )
    }

    static func searchText(for item: VocabularyItem) -> String {
        [item.hangul, item.romanization, item.meaning.english, item.meaning.khmer]
            .map(TextNormalizer.normalize)
            .joined(separator: " ")
    }
}
