import Foundation

/// Provenance of a content item. Required on every imported or generated item (PRD FR-C3).
public struct ContentSource: Hashable, Sendable, Codable {
    public enum Origin: String, Sendable, Codable {
        case curated
        case imported
        case aiGenerated
    }

    public var origin: Origin
    public var name: String
    public var license: String
    public var url: String?

    public init(origin: Origin, name: String, license: String, url: String? = nil) {
        self.origin = origin
        self.name = name
        self.license = license
        self.url = url
    }
}
