import Domain
import Foundation

/// Launch step: brings the content store up to the bundled library version and
/// reports what is installed. Runs off the main actor.
public enum BundledContentInstaller {
    public static func installIfNeeded(controller: PersistenceController, bundle: Bundle? = nil) async throws -> ContentInfo {
        let library = try BundledContent.load(from: bundle ?? .module)
        _ = try await CoreDataContentStore(controller: controller).apply(library.package)
        return ContentInfo(
            version: library.package.version,
            vocabularyCount: library.package.vocabulary.count,
            grammarCount: library.package.grammar.count,
            questionCount: library.package.questions.count,
            sourceName: library.source.name,
            license: library.source.license,
            pendingReview: library.pendingReview,
            credits: library.package.importedCredits
        )
    }
}
