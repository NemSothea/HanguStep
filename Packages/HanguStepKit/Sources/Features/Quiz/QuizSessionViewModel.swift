import DesignSystem
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class QuizSessionViewModel {
    public enum Phase: Equatable {
        case loading
        case answering(index: Int)
        case feedback(index: Int, AnswerFeedback)
        case finished(QuizResult)
        case failed(message: String)
    }

    public private(set) var phase: Phase = .loading
    public private(set) var snapshot: QuizSessionSnapshot?
    public var selectedOptionID: OptionID?
    public private(set) var isSubmitting = false
    public private(set) var shortfallNoticeShown = false

    private let launch: QuizLaunch
    private let start: any StartQuizSessionUseCase
    private let submit: any SubmitAnswerUseCase
    private let finish: any FinishQuizSessionUseCase
    private var questionShownAt = Date()

    init(launch: QuizLaunch, dependencies: AppDependencies) {
        self.launch = launch
        start = dependencies.startQuiz
        submit = dependencies.submitAnswer
        finish = dependencies.finishQuiz
    }

    public var currentQuestion: Question? {
        guard let snapshot else { return nil }
        switch phase {
        case let .answering(index), let .feedback(index, _):
            return index < snapshot.questions.count ? snapshot.questions[index] : nil
        default:
            return nil
        }
    }

    public var progressText: String {
        guard let snapshot else { return "" }
        switch phase {
        case let .answering(index), let .feedback(index, _):
            return "\(index + 1) of \(snapshot.questions.count)"
        default:
            return ""
        }
    }

    public var progress: Double {
        guard let snapshot, !snapshot.questions.isEmpty else { return 0 }
        switch phase {
        case let .answering(index): return Double(index) / Double(snapshot.questions.count)
        case let .feedback(index, _): return Double(index + 1) / Double(snapshot.questions.count)
        case .finished: return 1
        default: return 0
        }
    }

    public var hasUnansweredQuestions: Bool {
        guard let snapshot else { return false }
        if case .finished = phase { return false }
        return snapshot.attempts.count < snapshot.questions.count
    }

    public func load() async {
        do {
            let loaded: QuizSessionSnapshot
            switch launch.source {
            case let .new(configuration):
                loaded = try await start.execute(configuration)
            case let .resume(existing):
                loaded = existing
            }
            snapshot = loaded
            shortfallNoticeShown = loaded.isShortfall
            if loaded.isComplete {
                await finishSession()
            } else {
                show(index: loaded.session.currentIndex)
            }
        } catch {
            phase = .failed(message: error.localizedDescription)
        }
    }

    public func select(_ optionID: OptionID) {
        guard case .answering = phase else { return }
        selectedOptionID = optionID
    }

    public func check() async {
        guard case let .answering(index) = phase, let snapshot, let selected = selectedOptionID, !isSubmitting else { return }
        let question = snapshot.questions[index]
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let feedback = try await submit.execute(
                session: snapshot.session,
                question: question,
                selectedOptionID: selected,
                responseTime: Date().timeIntervalSince(questionShownAt)
            )
            var session = snapshot.session
            session.currentIndex = feedback.nextIndex
            self.snapshot = QuizSessionSnapshot(
                session: session,
                questions: snapshot.questions,
                attempts: snapshot.attempts + [feedback.attempt],
                requestedCount: snapshot.requestedCount
            )
            phase = .feedback(index: index, feedback)
        } catch let error as DomainError {
            if case .duplicateSubmission = error {
                // Already answered (for example after a crash mid-save). Move on.
                show(index: index + 1)
            } else {
                phase = .failed(message: error.localizedDescription)
            }
        } catch {
            phase = .failed(message: error.localizedDescription)
        }
    }

    public func next() async {
        guard case let .feedback(index, _) = phase, let snapshot else { return }
        if index + 1 >= snapshot.questions.count {
            await finishSession()
        } else {
            show(index: index + 1)
        }
    }

    /// Ends the session early. Answered questions are kept (PRD FR-Q4).
    public func close() async {
        await finishSession()
    }

    public func optionState(for option: QuestionOption) -> OptionState {
        switch phase {
        case .answering:
            return option.id == selectedOptionID ? .selected : .idle
        case let .feedback(_, feedback):
            if option.id == feedback.correctOptionID { return .correct }
            if option.id == feedback.attempt.selectedOptionID { return .incorrect }
            return .dimmed
        default:
            return .dimmed
        }
    }

    private func show(index: Int) {
        guard let snapshot else { return }
        if index >= snapshot.questions.count {
            Task { await finishSession() }
            return
        }
        selectedOptionID = nil
        questionShownAt = Date()
        phase = .answering(index: index)
    }

    private func finishSession() async {
        guard let snapshot else { return }
        do {
            phase = .finished(try await finish.execute(sessionID: snapshot.session.id))
        } catch {
            phase = .failed(message: error.localizedDescription)
        }
    }
}
