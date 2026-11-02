import CoreData
import Domain
import Foundation

/// Imports a `ContentPackage` into the content store. Upserts by id, retires
/// ids missing from the package, skips when the installed version is not older.
public struct CoreDataContentStore: ContentStore {
    private let context: NSManagedObjectContext

    public init(controller: PersistenceController) {
        context = controller.newBackgroundContext()
    }

    public func installedContentVersion() async throws -> Int? {
        try await context.perform {
            try Self.manifest(in: context).map { Int($0.version) }
        }
    }

    public func apply(_ package: ContentPackage) async throws -> ContentImportResult {
        let issues = package.validate()
        guard issues.isEmpty else {
            throw DomainError.invalidPackage(issues: issues.map(\.description))
        }
        return try await context.perform {
            let installed = try Self.manifest(in: context).map { Int($0.version) }
            if let installed, installed >= package.version {
                return ContentImportResult(packageVersion: package.version, skipped: true, inserted: 0, updated: 0, retired: 0)
            }

            var inserted = 0, updated = 0, retired = 0

            // Vocabulary
            let vocabularyRows = try Self.rows(CDVocabulary.self, entity: "CDVocabulary", in: context)
            for item in package.vocabulary {
                let row = vocabularyRows[item.id.rawValue] ?? {
                    inserted += 1
                    let new = CDVocabulary(context: context)
                    new.id = item.id.rawValue
                    return new
                }()
                if vocabularyRows[item.id.rawValue] != nil { updated += 1 }
                Self.fill(row, from: item, context: context)
            }
            retired += Self.retire(vocabularyRows, keeping: package.vocabulary.map(\.id.rawValue)) { $0.isRetired = true }

            // Grammar
            let grammarRows = try Self.rows(CDGrammar.self, entity: "CDGrammar", in: context)
            for pattern in package.grammar {
                let row = grammarRows[pattern.id.rawValue] ?? {
                    inserted += 1
                    let new = CDGrammar(context: context)
                    new.id = pattern.id.rawValue
                    return new
                }()
                if grammarRows[pattern.id.rawValue] != nil { updated += 1 }
                Self.fill(row, from: pattern, context: context)
            }
            retired += Self.retire(grammarRows, keeping: package.grammar.map(\.id.rawValue)) { $0.isRetired = true }

            // Questions
            let questionRows = try Self.rows(CDQuestion.self, entity: "CDQuestion", in: context)
            for question in package.questions {
                let row = questionRows[question.id.rawValue] ?? {
                    inserted += 1
                    let new = CDQuestion(context: context)
                    new.id = question.id.rawValue
                    return new
                }()
                if questionRows[question.id.rawValue] != nil { updated += 1 }
                Self.fill(row, from: question, context: context)
            }
            retired += Self.retire(questionRows, keeping: package.questions.map(\.id.rawValue)) { $0.isRetired = true }

            let manifest = try Self.manifest(in: context) ?? {
                let new = CDContentManifest(context: context)
                new.id = "manifest"
                return new
            }()
            manifest.version = Int32(package.version)
            manifest.importedAt = Date()
            manifest.vocabularyCount = Int32(package.vocabulary.count)
            manifest.grammarCount = Int32(package.grammar.count)
            manifest.questionCount = Int32(package.questions.count)

            try context.save()
            return ContentImportResult(packageVersion: package.version, skipped: false, inserted: inserted, updated: updated, retired: retired)
        }
    }

    // MARK: - Helpers

    static func manifest(in context: NSManagedObjectContext) throws -> CDContentManifest? {
        let request = NSFetchRequest<CDContentManifest>(entityName: "CDContentManifest")
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func rows<T: NSManagedObject>(_ type: T.Type, entity: String, in context: NSManagedObjectContext) throws -> [String: T] {
        let request = NSFetchRequest<T>(entityName: entity)
        var result: [String: T] = [:]
        for row in try context.fetch(request) {
            if let id = row.value(forKey: "id") as? String { result[id] = row }
        }
        return result
    }

    private static func retire<T: NSManagedObject>(_ rows: [String: T], keeping ids: [String], mark: (T) -> Void) -> Int {
        let keep = Set(ids)
        var count = 0
        for (id, row) in rows where !keep.contains(id) {
            if (row.value(forKey: "isRetired") as? Bool) != true {
                mark(row)
                count += 1
            }
        }
        return count
    }

    private static func replaceExamples(on set: NSSet?, with examples: [ExampleSentence], context: NSManagedObjectContext, attach: (CDExampleSentence) -> Void) {
        for old in set?.allObjects as? [CDExampleSentence] ?? [] { context.delete(old) }
        for (index, example) in examples.enumerated() {
            let row = CDExampleSentence(context: context)
            row.id = UUID().uuidString.lowercased()
            row.sortOrder = Int16(index)
            row.korean = example.korean
            row.english = example.translation.english
            row.khmer = example.translation.khmer
            attach(row)
        }
    }

    private static func fill(_ row: CDVocabulary, from item: VocabularyItem, context: NSManagedObjectContext) {
        row.hangul = item.hangul
        row.romanization = item.romanization
        row.hanja = item.hanja
        row.partOfSpeech = item.partOfSpeech.rawValue
        row.level = Int16(item.level.rawValue)
        row.category = item.category
        row.meaningEnglish = item.meaning.english
        row.meaningKhmer = item.meaning.khmer
        row.searchText = ContentMapping.searchText(for: item)
        row.sourceOrigin = item.source.origin.rawValue
        row.sourceName = item.source.name
        row.sourceLicense = item.source.license
        row.sourceURL = item.source.url
        row.contentVersion = Int32(item.contentVersion)
        row.isRetired = false
        replaceExamples(on: row.examples, with: item.examples, context: context) { $0.vocabulary = row }
    }

    private static func fill(_ row: CDGrammar, from pattern: GrammarPattern, context: NSManagedObjectContext) {
        row.pattern = pattern.pattern
        row.level = Int16(pattern.level.rawValue)
        row.category = pattern.category
        row.explanationEnglish = pattern.explanation.english
        row.explanationKhmer = pattern.explanation.khmer
        row.formationEnglish = pattern.formation?.english
        row.formationKhmer = pattern.formation?.khmer
        row.relatedPatternIDs = CoreDataSupport.encodeIDs(pattern.relatedPatternIDs.map(\.rawValue))
        row.sourceOrigin = pattern.source.origin.rawValue
        row.sourceName = pattern.source.name
        row.sourceLicense = pattern.source.license
        row.sourceURL = pattern.source.url
        row.contentVersion = Int32(pattern.contentVersion)
        row.isRetired = false
        replaceExamples(on: row.examples, with: pattern.examples, context: context) { $0.grammar = row }
    }

    private static func fill(_ row: CDQuestion, from question: Question, context: NSManagedObjectContext) {
        row.kind = question.kind.rawValue
        row.level = Int16(question.level.rawValue)
        row.prompt = question.prompt
        row.passage = question.passage
        row.correctOptionID = question.correctOptionID.rawValue
        row.explanationEnglish = question.explanation.english
        row.explanationKhmer = question.explanation.khmer
        row.relatedVocabularyID = question.relatedVocabularyID?.rawValue
        row.relatedGrammarID = question.relatedGrammarID?.rawValue
        row.sourceOrigin = question.source.origin.rawValue
        row.sourceName = question.source.name
        row.sourceLicense = question.source.license
        row.sourceURL = question.source.url
        row.contentVersion = Int32(question.contentVersion)
        row.isRetired = false
        for old in row.options?.allObjects as? [CDQuestionOption] ?? [] { context.delete(old) }
        for (index, option) in question.options.enumerated() {
            let optionRow = CDQuestionOption(context: context)
            optionRow.id = option.id.rawValue
            optionRow.sortOrder = Int16(index)
            optionRow.text = option.text
            optionRow.question = row
        }
    }
}
