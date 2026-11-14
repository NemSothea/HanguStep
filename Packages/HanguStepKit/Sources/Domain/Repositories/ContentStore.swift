import Foundation

public struct ContentImportResult: Hashable, Sendable {
    public let packageVersion: Int
    public let skipped: Bool
    public let inserted: Int
    public let updated: Int
    public let retired: Int

    public init(packageVersion: Int, skipped: Bool, inserted: Int, updated: Int, retired: Int) {
        self.packageVersion = packageVersion
        self.skipped = skipped
        self.inserted = inserted
        self.updated = updated
        self.retired = retired
    }
}

/// Write side of the content library. Only the importer uses it (PRD FR-C1, FR-C2).
public protocol ContentStore: Sendable {
    func installedContentVersion() async throws -> Int?
    /// Applies the package if its version is newer than the installed one.
    /// Validation failures throw `DomainError.invalidContent`-style errors before any write.
    func apply(_ package: ContentPackage) async throws -> ContentImportResult
}
