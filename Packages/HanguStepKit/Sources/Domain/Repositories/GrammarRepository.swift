import Foundation

/// Read-only access to bundled grammar content (PRD FR-G1, FR-G2).
public protocol GrammarRepository: Sendable {
    func pattern(id: GrammarID) async throws -> GrammarPattern?
    func patterns(level: TOPIKLevel?) async throws -> [GrammarPattern]
    func count() async throws -> Int
}
