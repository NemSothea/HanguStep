import DesignSystem
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class WritingListViewModel {
    public private(set) var state: ViewState<[WritingTaskSummary]> = .idle
    private let list: any ListWritingTasksUseCase

    public init(list: any ListWritingTasksUseCase) { self.list = list }

    public func load() async {
        if state.value == nil { state = .loading }
        do {
            let tasks = try await list.execute()
            state = tasks.isEmpty ? .empty : .loaded(tasks)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func tasks(of type: WritingTaskType) -> [WritingTaskSummary] {
        state.value?.filter { $0.task.type == type } ?? []
    }
}

@MainActor
@Observable
public final class WritingTaskViewModel {
    public let task: WritingTask
    /// The answer being written. Kept as a device-local draft until saved.
    public var text: String {
        didSet { drafts.set(text, forKey: draftKey) }
    }
    public private(set) var attempts: [WritingAttempt] = []
    /// The attempt whose feedback is on screen: the one just saved or one picked from history.
    public private(set) var current: WritingAttempt?
    public private(set) var review: ViewState<WritingFeedback> = .idle
    public private(set) var errorMessage: String?
    public private(set) var isSaving = false

    private let save: any SaveWritingAttemptUseCase
    private let reviewer: any ReviewWritingUseCase
    private let repository: any WritingAttemptRepository
    private let drafts: UserDefaults
    private var draftKey: String { "writing.draft.\(task.id.rawValue)" }

    public init(task: WritingTask, dependencies: AppDependencies, drafts: UserDefaults = .standard) {
        self.task = task
        save = dependencies.saveWritingAttempt
        reviewer = dependencies.reviewWriting
        repository = dependencies.writingAttempts
        self.drafts = drafts
        text = drafts.string(forKey: "writing.draft.\(task.id.rawValue)") ?? ""
    }

    public var characterCount: Int { WritingText.characterCount(text) }

    public enum LengthStatus: Equatable { case none, short, ok, long }

    public var lengthStatus: LengthStatus {
        guard let range = task.lengthRange else { return .none }
        if characterCount < range.lowerBound { return .short }
        if characterCount > range.upperBound { return .long }
        return .ok
    }

    public var canSave: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving }

    public func load() async {
        do { attempts = try await repository.attempts(for: task.id) } catch { errorMessage = error.localizedDescription }
    }

    /// Saves the answer as a new attempt and clears the draft.
    public func submit() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await save.execute(taskID: task.id, text: text)
            attempts.insert(saved, at: 0)
            current = saved
            review = .idle
            errorMessage = nil
            text = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Asks the configured assistant to grade the current attempt.
    public func requestFeedback(language: GlossLanguage) async {
        guard let attempt = current, !review.isLoading else { return }
        review = .loading
        do {
            let reviewed = try await reviewer.execute(attempt: attempt, task: task, language: language)
            current = reviewed
            if let index = attempts.firstIndex(where: { $0.id == reviewed.id }) { attempts[index] = reviewed }
            review = reviewed.feedback.map { .loaded($0) } ?? .empty
        } catch {
            review = .failed(message: error.localizedDescription)
        }
    }

    public func show(_ attempt: WritingAttempt) {
        current = attempt
        review = attempt.feedback.map { .loaded($0) } ?? .idle
    }

    /// Copies a past answer back into the editor to revise it.
    public func revise(_ attempt: WritingAttempt) {
        text = attempt.text
    }
}
