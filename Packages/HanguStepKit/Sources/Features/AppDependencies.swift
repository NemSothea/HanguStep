import Domain

/// Use cases the feature layer needs. Built once by the app's composition root
/// and passed down. Features never construct repositories themselves.
public struct AppDependencies: Sendable {
    public let loadDashboardSummary: any LoadDashboardSummaryUseCase
    public let loadProgressReport: any LoadProgressReportUseCase
    public let listReviewQueue: any ListReviewQueueUseCase
    public let browseVocabulary: any BrowseVocabularyUseCase
    public let getVocabularyDetail: any GetVocabularyDetailUseCase
    public let browseGrammar: any BrowseGrammarUseCase
    public let getGrammarDetail: any GetGrammarDetailUseCase
    public let toggleBookmark: any ToggleBookmarkUseCase
    public let listBookmarks: any ListBookmarksUseCase
    public let saveNote: any SaveNoteUseCase
    public let startQuiz: any StartQuizSessionUseCase
    public let resumeQuiz: any ResumeQuizSessionUseCase
    public let submitAnswer: any SubmitAnswerUseCase
    public let finishQuiz: any FinishQuizSessionUseCase
    public let listMistakes: any ListMistakesUseCase
    public let listHistory: any ListQuizHistoryUseCase
    public let loadSettings: any LoadSettingsUseCase
    public let saveSettings: any SaveSettingsUseCase
    public let pronouncer: any Pronouncer
    public let learnerChanges: any LearnerChangeSource
    public let contentInfo: ContentInfo
    public let explainAnswer: any ExplainAnswerUseCase
    public let generatePractice: any GeneratePracticeQuestionsUseCase
    public let generatedQuestions: any GeneratedQuestionStore
    public let listWritingTasks: any ListWritingTasksUseCase
    public let saveWritingAttempt: any SaveWritingAttemptUseCase
    public let reviewWriting: any ReviewWritingUseCase
    public let writingAttempts: any WritingAttemptRepository
    public let listeningAudio: any ListeningAudioSource

    public init(
        loadDashboardSummary: any LoadDashboardSummaryUseCase,
        loadProgressReport: any LoadProgressReportUseCase,
        listReviewQueue: any ListReviewQueueUseCase,
        browseVocabulary: any BrowseVocabularyUseCase,
        getVocabularyDetail: any GetVocabularyDetailUseCase,
        browseGrammar: any BrowseGrammarUseCase,
        getGrammarDetail: any GetGrammarDetailUseCase,
        toggleBookmark: any ToggleBookmarkUseCase,
        listBookmarks: any ListBookmarksUseCase,
        saveNote: any SaveNoteUseCase,
        startQuiz: any StartQuizSessionUseCase,
        resumeQuiz: any ResumeQuizSessionUseCase,
        submitAnswer: any SubmitAnswerUseCase,
        finishQuiz: any FinishQuizSessionUseCase,
        listMistakes: any ListMistakesUseCase,
        listHistory: any ListQuizHistoryUseCase,
        loadSettings: any LoadSettingsUseCase,
        saveSettings: any SaveSettingsUseCase,
        pronouncer: any Pronouncer,
        learnerChanges: any LearnerChangeSource = NoLearnerChanges(),
        contentInfo: ContentInfo = .unknown,
        explainAnswer: any ExplainAnswerUseCase = UnavailableAssistant(),
        generatePractice: any GeneratePracticeQuestionsUseCase = UnavailableAssistant(),
        generatedQuestions: any GeneratedQuestionStore = NoGeneratedQuestions(),
        listWritingTasks: any ListWritingTasksUseCase = NoWriting(),
        saveWritingAttempt: any SaveWritingAttemptUseCase = NoWriting(),
        reviewWriting: any ReviewWritingUseCase = UnavailableAssistant(),
        writingAttempts: any WritingAttemptRepository = NoWriting(),
        listeningAudio: any ListeningAudioSource = NoListeningAudio()
    ) {
        self.loadDashboardSummary = loadDashboardSummary
        self.loadProgressReport = loadProgressReport
        self.listReviewQueue = listReviewQueue
        self.browseVocabulary = browseVocabulary
        self.getVocabularyDetail = getVocabularyDetail
        self.browseGrammar = browseGrammar
        self.getGrammarDetail = getGrammarDetail
        self.toggleBookmark = toggleBookmark
        self.listBookmarks = listBookmarks
        self.saveNote = saveNote
        self.startQuiz = startQuiz
        self.resumeQuiz = resumeQuiz
        self.submitAnswer = submitAnswer
        self.finishQuiz = finishQuiz
        self.listMistakes = listMistakes
        self.listHistory = listHistory
        self.loadSettings = loadSettings
        self.saveSettings = saveSettings
        self.pronouncer = pronouncer
        self.learnerChanges = learnerChanges
        self.contentInfo = contentInfo
        self.explainAnswer = explainAnswer
        self.generatePractice = generatePractice
        self.generatedQuestions = generatedQuestions
        self.listWritingTasks = listWritingTasks
        self.saveWritingAttempt = saveWritingAttempt
        self.reviewWriting = reviewWriting
        self.writingAttempts = writingAttempts
        self.listeningAudio = listeningAudio
    }
}

/// Default for tests and previews that do not exercise the assistant.
public struct UnavailableAssistant: ExplainAnswerUseCase, GeneratePracticeQuestionsUseCase, ReviewWritingUseCase {
    public init() {}
    public func execute(question: Question, selectedOptionID: OptionID, language: GlossLanguage) async throws -> AssistantExplanation {
        throw AssistantError.disabled
    }
    public func execute(target: LearningTarget, count: Int) async throws -> [Question] {
        throw AssistantError.disabled
    }
    public func execute(attempt: WritingAttempt, task: WritingTask, language: GlossLanguage) async throws -> WritingAttempt {
        throw AssistantError.disabled
    }
}

/// Writing practice not wired (tests, previews).
public struct NoWriting: ListWritingTasksUseCase, SaveWritingAttemptUseCase, WritingAttemptRepository {
    public init() {}
    public func execute() async throws -> [WritingTaskSummary] { [] }
    public func execute(taskID: WritingTaskID, text: String) async throws -> WritingAttempt {
        throw DomainError.storage(description: "writing practice is not available")
    }
    public func save(_ attempt: WritingAttempt) async throws {}
    public func attempts(for taskID: WritingTaskID) async throws -> [WritingAttempt] { [] }
    public func allAttempts() async throws -> [WritingAttempt] { [] }
}

public struct NoGeneratedQuestions: GeneratedQuestionStore {
    public init() {}
    public func save(_ questions: [Question]) async throws {}
    public func generated(for target: LearningTarget) async throws -> [Question] { [] }
    public func generatedCount() async throws -> Int { 0 }
    public func deleteAllGenerated() async throws -> Int { 0 }
}
