import Foundation

/// The abstraction every assistant feature goes through (PRD FR-A1). Providers
/// never touch storage; use cases validate and persist what they return.
public protocol AssistantProvider: Sendable {
    var name: String { get }
    func explain(_ request: ExplanationRequest) async throws -> AssistantExplanation
    func generate(_ request: PracticeRequest) async throws -> [DraftQuestion]
    /// Grades a TOPIK writing answer (ADR-012).
    func reviewWriting(_ request: WritingReviewRequest) async throws -> WritingFeedback
}

public extension AssistantProvider {
    func reviewWriting(_ request: WritingReviewRequest) async throws -> WritingFeedback {
        throw AssistantError.unavailable("\(name) cannot review writing")
    }
}

/// Resolves the provider the learner currently has configured. Checked on every
/// call so switching it off or changing the key takes effect immediately.
/// Throws `AssistantError.disabled` or `.notConfigured`.
public protocol AssistantProviderSource: Sendable {
    func currentProvider() async throws -> any AssistantProvider
}

/// Always-on source for tests, previews and the composition root's fallback.
public struct FixedAssistantProviderSource: AssistantProviderSource {
    private let provider: any AssistantProvider
    public init(_ provider: any AssistantProvider) { self.provider = provider }
    public func currentProvider() async throws -> any AssistantProvider { provider }
}

public struct DisabledAssistantProviderSource: AssistantProviderSource {
    public init() {}
    public func currentProvider() async throws -> any AssistantProvider { throw AssistantError.disabled }
}

/// Write side for learner-specific generated questions. They live beside the
/// bundled library, carry `ContentSource.Origin.aiGenerated` and survive content
/// imports; the read side is the ordinary `QuestionRepository`.
public protocol GeneratedQuestionStore: Sendable {
    func save(_ questions: [Question]) async throws
    func generated(for target: LearningTarget) async throws -> [Question]
    func generatedCount() async throws -> Int
    func deleteAllGenerated() async throws -> Int
}
