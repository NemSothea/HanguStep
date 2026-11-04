import Domain
import Foundation
import Observation

/// Device-local assistant preferences. Not part of `LearnerSettings` because the
/// API key lives in this device's Keychain, so the choice of provider must too.
public struct AssistantSettings: Hashable, Sendable, Codable {
    public var isEnabled: Bool
    public var provider: AssistantProviderKind

    public init(isEnabled: Bool = false, provider: AssistantProviderKind = .mock) {
        self.isEnabled = isEnabled
        self.provider = provider
    }
}

public protocol AssistantSettingsStore: Sendable {
    func load() -> AssistantSettings
    func save(_ settings: AssistantSettings)
}

/// Secrets the learner typed in. Keychain in the app, memory in tests.
/// Never synced, never logged, never written to the bundle (PRD FR-A3).
public protocol SecretStore: Sendable {
    func secret(for key: String) throws -> String?
    func set(_ value: String, for key: String) throws
    func remove(_ key: String) throws
}

public struct UserDefaultsAssistantSettingsStore: AssistantSettingsStore {
    private let suiteName: String?
    private let key: String

    /// `suiteName` nil means `UserDefaults.standard`. Resolved per call: UserDefaults
    /// is thread-safe but not `Sendable`, so the struct keeps only the name.
    public init(suiteName: String? = nil, key: String = "assistant.settings") {
        self.suiteName = suiteName
        self.key = key
    }

    private var defaults: UserDefaults { suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard }

    public func load() -> AssistantSettings {
        guard let data = defaults.data(forKey: key), let settings = try? JSONDecoder().decode(AssistantSettings.self, from: data) else {
            return AssistantSettings()
        }
        return settings
    }

    public func save(_ settings: AssistantSettings) {
        defaults.set(try? JSONEncoder().encode(settings), forKey: key)
    }
}

public final class InMemoryAssistantSettingsStore: AssistantSettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var settings: AssistantSettings

    public init(_ settings: AssistantSettings = AssistantSettings()) { self.settings = settings }

    public func load() -> AssistantSettings { lock.withLock { settings } }
    public func save(_ settings: AssistantSettings) { lock.withLock { self.settings = settings } }
}

public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var secrets: [String: String]

    public init(_ secrets: [String: String] = [:]) { self.secrets = secrets }

    public func secret(for key: String) throws -> String? { lock.withLock { secrets[key] } }
    public func set(_ value: String, for key: String) throws { lock.withLock { secrets[key] = value } }
    public func remove(_ key: String) throws { lock.withLock { secrets[key] = nil } }
}

/// Builds a provider for a kind from its credential. The composition root
/// supplies the real one; Features never imports the network target.
public typealias AssistantProviderFactory = @Sendable (AssistantProviderKind, _ apiKey: String?) throws -> any AssistantProvider

public enum AssistantSecretKey {
    public static let claudeAPIKey = "assistant.claude.apiKey"
}

/// Reads the stores on every call, so a change in Settings applies to the next request.
public struct ConfiguredAssistantProviderSource: AssistantProviderSource {
    private let settings: any AssistantSettingsStore
    private let secrets: any SecretStore
    private let factory: AssistantProviderFactory

    public init(settings: any AssistantSettingsStore, secrets: any SecretStore, factory: @escaping AssistantProviderFactory) {
        self.settings = settings
        self.secrets = secrets
        self.factory = factory
    }

    public func currentProvider() async throws -> any AssistantProvider {
        let current = settings.load()
        guard current.isEnabled else { throw AssistantError.disabled }
        switch current.provider {
        case .mock:
            return try factory(.mock, nil)
        case .claude:
            guard let key = try secrets.secret(for: AssistantSecretKey.claudeAPIKey), !key.isEmpty else {
                throw AssistantError.notConfigured(.claude)
            }
            return try factory(.claude, key)
        }
    }
}

/// Main-actor state for the Settings screen and for views that gate assistant
/// buttons. Writes straight through to the same stores the provider source reads.
@MainActor
@Observable
public final class AssistantModel {
    public private(set) var settings: AssistantSettings
    public private(set) var hasClaudeKey: Bool
    public private(set) var errorMessage: String?

    private let store: any AssistantSettingsStore
    private let secrets: any SecretStore

    public init(store: any AssistantSettingsStore, secrets: any SecretStore) {
        self.store = store
        self.secrets = secrets
        settings = store.load()
        hasClaudeKey = ((try? secrets.secret(for: AssistantSecretKey.claudeAPIKey)) ?? nil).map { !$0.isEmpty } ?? false
    }

    /// Off by default; in tests and previews, an enabled mock.
    public static func disabled() -> AssistantModel {
        AssistantModel(store: InMemoryAssistantSettingsStore(), secrets: InMemorySecretStore())
    }

    public var isEnabled: Bool { settings.isEnabled }

    /// True when a request would get past `currentProvider()`.
    public var isReady: Bool {
        settings.isEnabled && (settings.provider == .mock || hasClaudeKey)
    }

    public func setEnabled(_ enabled: Bool) {
        settings.isEnabled = enabled
        store.save(settings)
    }

    public func setProvider(_ provider: AssistantProviderKind) {
        settings.provider = provider
        store.save(settings)
    }

    public func saveClaudeKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try secrets.remove(AssistantSecretKey.claudeAPIKey)
            } else {
                try secrets.set(trimmed, for: AssistantSecretKey.claudeAPIKey)
            }
            hasClaudeKey = !trimmed.isEmpty
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func removeClaudeKey() { saveClaudeKey("") }
}
