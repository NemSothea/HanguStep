import Foundation

/// What the Settings screen shows about the installed library (PRD FR-C3).
public struct ContentInfo: Hashable, Sendable, Codable {
    public let version: Int
    public let vocabularyCount: Int
    public let grammarCount: Int
    public let questionCount: Int
    public let sourceName: String
    public let license: String
    public let pendingReview: Int
    /// Third-party attributions to show in Settings (see `ContentPackage.importedCredits`).
    public let credits: [String]

    public init(version: Int, vocabularyCount: Int, grammarCount: Int, questionCount: Int, sourceName: String, license: String, pendingReview: Int = 0, credits: [String] = []) {
        self.version = version
        self.vocabularyCount = vocabularyCount
        self.grammarCount = grammarCount
        self.questionCount = questionCount
        self.sourceName = sourceName
        self.license = license
        self.pendingReview = pendingReview
        self.credits = credits
    }

    public static let unknown = ContentInfo(version: 0, vocabularyCount: 0, grammarCount: 0, questionCount: 0, sourceName: "", license: "")
}
