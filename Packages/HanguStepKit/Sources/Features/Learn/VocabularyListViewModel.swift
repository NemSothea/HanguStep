import DesignSystem
import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class VocabularyListViewModel {
    public private(set) var state: ViewState<[VocabularyItem]> = .idle
    public var query = "" { didSet { scheduleReload() } }
    public var levels: Set<TOPIKLevel> = [] { didSet { scheduleReload() } }
    public var partOfSpeech: PartOfSpeech? { didSet { scheduleReload() } }

    private let browse: any BrowseVocabularyUseCase
    private var reloadTask: Task<Void, Never>?

    public init(browse: any BrowseVocabularyUseCase) {
        self.browse = browse
    }

    public var filter: VocabularyFilter {
        VocabularyFilter(levels: levels, partsOfSpeech: partOfSpeech.map { [$0] } ?? [])
    }

    public var hasActiveFilters: Bool { !levels.isEmpty || partOfSpeech != nil }

    public func clearFilters() {
        levels = []
        partOfSpeech = nil
    }

    public func toggle(level: TOPIKLevel) {
        if levels.contains(level) { levels.remove(level) } else { levels.insert(level) }
    }

    public func load() async {
        if state.value == nil { state = .loading }
        do {
            let items = try await browse.execute(query: query, filter: filter)
            state = items.isEmpty ? .empty : .loaded(items)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    /// Debounced so typing does not fire a fetch per keystroke.
    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await self?.load()
        }
    }
}
