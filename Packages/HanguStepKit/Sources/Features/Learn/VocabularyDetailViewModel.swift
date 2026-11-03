import DesignSystem
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class VocabularyDetailViewModel {
    public private(set) var state: ViewState<VocabularyDetail> = .idle
    public var noteDraft = ""
    public private(set) var isSavingNote = false

    private let id: VocabularyID
    private let getDetail: any GetVocabularyDetailUseCase
    private let toggleBookmark: any ToggleBookmarkUseCase
    private let saveNote: any SaveNoteUseCase
    private let pronouncer: any Pronouncer

    public init(id: VocabularyID, dependencies: AppDependencies) {
        self.id = id
        getDetail = dependencies.getVocabularyDetail
        toggleBookmark = dependencies.toggleBookmark
        saveNote = dependencies.saveNote
        pronouncer = dependencies.pronouncer
    }

    public func load() async {
        state = .loading
        do {
            let detail = try await getDetail.execute(id: id)
            noteDraft = detail.note?.text ?? ""
            state = .loaded(detail)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func pronounce() {
        guard let detail = state.value else { return }
        Task { await pronouncer.speak(detail.item.hangul) }
    }

    public func toggleBookmarkTapped() async {
        guard var detail = state.value else { return }
        do {
            detail.isBookmarked = try await toggleBookmark.execute(target: .vocabulary(id))
            state = .loaded(detail)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func commitNote() async {
        guard var detail = state.value else { return }
        isSavingNote = true
        defer { isSavingNote = false }
        do {
            detail.note = try await saveNote.execute(target: .vocabulary(id), text: noteDraft)
            noteDraft = detail.note?.text ?? ""
            state = .loaded(detail)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }
}
