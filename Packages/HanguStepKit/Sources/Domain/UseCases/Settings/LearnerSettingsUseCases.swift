import Foundation

public protocol LoadSettingsUseCase: Sendable {
    func execute() async throws -> LearnerSettings
}

public protocol SaveSettingsUseCase: Sendable {
    func execute(_ settings: LearnerSettings) async throws -> LearnerSettings
}

public struct LoadSettings: LoadSettingsUseCase {
    private let repository: any LearnerSettingsRepository
    public init(repository: any LearnerSettingsRepository) { self.repository = repository }
    public func execute() async throws -> LearnerSettings { try await repository.load() }
}

public struct SaveSettings: SaveSettingsUseCase {
    private let repository: any LearnerSettingsRepository
    private let dates: any DateProvider

    public init(repository: any LearnerSettingsRepository, dates: any DateProvider = SystemDateProvider()) {
        self.repository = repository
        self.dates = dates
    }

    public func execute(_ settings: LearnerSettings) async throws -> LearnerSettings {
        var stamped = settings
        stamped.dailyGoal = max(1, settings.dailyGoal)
        stamped.reviewLimit = max(1, settings.reviewLimit)
        stamped.modifiedAt = dates.now()
        try await repository.save(stamped)
        return stamped
    }
}
