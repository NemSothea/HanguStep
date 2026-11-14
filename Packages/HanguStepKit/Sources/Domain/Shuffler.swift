import Foundation

/// Injected randomness so session building is deterministic in tests.
public protocol Shuffler: Sendable {
    func shuffle<T>(_ elements: [T]) -> [T]
}

public struct SystemShuffler: Shuffler {
    public init() {}
    public func shuffle<T>(_ elements: [T]) -> [T] { elements.shuffled() }
}

/// Keeps order. Tests and previews.
public struct IdentityShuffler: Shuffler {
    public init() {}
    public func shuffle<T>(_ elements: [T]) -> [T] { elements }
}

public protocol IDGenerator: Sendable {
    func next() -> String
}

public struct UUIDGenerator: IDGenerator {
    public init() {}
    public func next() -> String { UUID().uuidString.lowercased() }
}
