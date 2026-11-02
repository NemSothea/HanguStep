import Foundation

/// Languages a meaning or explanation can be displayed in. Korean is the
/// studied language and is never a gloss language.
public enum GlossLanguage: String, Sendable, Codable, CaseIterable {
    case english = "en"
    case khmer = "km"
}

/// A meaning or explanation carried in both English and Khmer.
/// Every content item must provide both; the user picks which is shown first.
public struct Gloss: Hashable, Sendable, Codable {
    public var english: String
    public var khmer: String

    public init(english: String, khmer: String) {
        self.english = english
        self.khmer = khmer
    }

    public func text(in language: GlossLanguage) -> String {
        switch language {
        case .english: return english
        case .khmer: return khmer
        }
    }
}

public struct ExampleSentence: Hashable, Sendable, Codable {
    public var korean: String
    public var translation: Gloss

    public init(korean: String, translation: Gloss) {
        self.korean = korean
        self.translation = translation
    }
}
