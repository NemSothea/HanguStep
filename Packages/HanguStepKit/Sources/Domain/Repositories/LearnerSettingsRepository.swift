import Foundation

public protocol LearnerSettingsRepository: Sendable {
    /// Returns `LearnerSettings.default` when nothing has been saved yet.
    func load() async throws -> LearnerSettings
    func save(_ settings: LearnerSettings) async throws
}
