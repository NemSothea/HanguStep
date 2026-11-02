import Domain
import Features
import Foundation
import Observation
import Persistence

/// Composition root. The only place that knows concrete repository types.
@MainActor
@Observable
final class AppContainer {
    enum State {
        case starting
        case ready(AppDependencies)
        case failed(String)
    }

    private(set) var state: State = .starting

    /// Opens the stores, imports bundled content if newer, and builds the dependency graph.
    func bootstrap() async {
        do {
            let controller = try PersistenceController(mode: .onDisk(directory: Self.storeDirectory()))
            let contentStore = CoreDataContentStore(controller: controller)
            _ = try await contentStore.apply(SampleContent.package)

            let questions = CoreDataQuestionRepository(controller: controller)
            let dependencies = AppDependencies(
                loadDashboardSummary: LoadDashboardSummary(
                    vocabulary: CoreDataVocabularyRepository(controller: controller),
                    grammar: CoreDataGrammarRepository(controller: controller),
                    attempts: CoreDataAttemptRepository(controller: controller, questions: questions)
                )
            )
            state = .ready(dependencies)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    private static func storeDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("HanguStep", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
