import Foundation

public struct QuestionFilter: Hashable, Sendable {
    public var levels: Set<TOPIKLevel>
    public var kinds: Set<QuestionKind>

    public init(levels: Set<TOPIKLevel> = [], kinds: Set<QuestionKind> = []) {
        self.levels = levels
        self.kinds = kinds
    }

    public static let all = QuestionFilter()

    public func matches(_ question: Question) -> Bool {
        if !levels.isEmpty, !levels.contains(question.level) { return false }
        if !kinds.isEmpty, !kinds.contains(question.kind) { return false }
        return true
    }
}

/// Read-only access to bundled questions (PRD FR-Q1, FR-Q2).
public protocol QuestionRepository: Sendable {
    func question(id: QuestionID) async throws -> Question?
    func questions(ids: [QuestionID]) async throws -> [Question]
    func questions(matching filter: QuestionFilter) async throws -> [Question]
    func count() async throws -> Int
}
