import Foundation

/// Injected source of "now". Lets scheduling, streak and session logic be
/// deterministic in tests. Named `DateProvider` to avoid clashing with `Swift.Clock`.
public protocol DateProvider: Sendable {
    func now() -> Date
}

public struct SystemDateProvider: DateProvider {
    public init() {}
    public func now() -> Date { Date() }
}

/// Fixed-time provider for tests and previews.
public struct FixedDateProvider: DateProvider {
    public let date: Date
    public init(_ date: Date) { self.date = date }
    public func now() -> Date { date }
}
