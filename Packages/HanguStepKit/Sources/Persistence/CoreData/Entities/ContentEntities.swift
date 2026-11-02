import CoreData

@objc(CDVocabulary)
final class CDVocabulary: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var hangul: String
    @NSManaged var romanization: String
    @NSManaged var hanja: String?
    @NSManaged var partOfSpeech: String
    @NSManaged var level: Int16
    @NSManaged var category: String
    @NSManaged var meaningEnglish: String
    @NSManaged var meaningKhmer: String
    @NSManaged var searchText: String
    @NSManaged var sourceOrigin: String
    @NSManaged var sourceName: String
    @NSManaged var sourceLicense: String
    @NSManaged var sourceURL: String?
    @NSManaged var contentVersion: Int32
    @NSManaged var isRetired: Bool
    @NSManaged var examples: NSSet?
}

@objc(CDGrammar)
final class CDGrammar: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var pattern: String
    @NSManaged var level: Int16
    @NSManaged var category: String
    @NSManaged var explanationEnglish: String
    @NSManaged var explanationKhmer: String
    @NSManaged var formationEnglish: String?
    @NSManaged var formationKhmer: String?
    @NSManaged var relatedPatternIDs: String
    @NSManaged var sourceOrigin: String
    @NSManaged var sourceName: String
    @NSManaged var sourceLicense: String
    @NSManaged var sourceURL: String?
    @NSManaged var contentVersion: Int32
    @NSManaged var isRetired: Bool
    @NSManaged var examples: NSSet?
}

@objc(CDExampleSentence)
final class CDExampleSentence: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var sortOrder: Int16
    @NSManaged var korean: String
    @NSManaged var english: String
    @NSManaged var khmer: String
    @NSManaged var vocabulary: CDVocabulary?
    @NSManaged var grammar: CDGrammar?
}

@objc(CDQuestion)
final class CDQuestion: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var kind: String
    @NSManaged var level: Int16
    @NSManaged var prompt: String
    @NSManaged var passage: String?
    @NSManaged var correctOptionID: String
    @NSManaged var explanationEnglish: String
    @NSManaged var explanationKhmer: String
    @NSManaged var relatedVocabularyID: String?
    @NSManaged var relatedGrammarID: String?
    @NSManaged var sourceOrigin: String
    @NSManaged var sourceName: String
    @NSManaged var sourceLicense: String
    @NSManaged var sourceURL: String?
    @NSManaged var contentVersion: Int32
    @NSManaged var isRetired: Bool
    @NSManaged var options: NSSet?
}

@objc(CDQuestionOption)
final class CDQuestionOption: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var sortOrder: Int16
    @NSManaged var text: String
    @NSManaged var question: CDQuestion?
}

@objc(CDContentManifest)
final class CDContentManifest: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var version: Int32
    @NSManaged var importedAt: Date?
    @NSManaged var vocabularyCount: Int32
    @NSManaged var grammarCount: Int32
    @NSManaged var questionCount: Int32
}
