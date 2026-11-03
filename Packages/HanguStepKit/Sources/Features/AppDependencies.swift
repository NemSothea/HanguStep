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
        learnerChanges: any LearnerChangeSource = NoLearnerChanges()
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
    }
}
